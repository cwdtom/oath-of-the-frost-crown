extends SceneTree


const MAIN_SCENE := "res://main.tscn"
const CAMERA_OPENING_STORY := &"opening_story"
const CAMERA_PLAYER := &"player"
const MAX_STORY_ADVANCE_INPUTS := 64

var failures: Array[String] = []
var level_01_story_completion_count := 0
var level_02_story_completion_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := instantiate_main()
	if main == null:
		finish()
		return

	await process_frame
	main.call("start_level_01", false)
	await process_frame

	var level_01 := main.call("get_active_campaign_level") as CampaignLevel
	expect(level_01 != null, "Campaign progression starts Level01")
	if level_01 == null:
		await cleanup(main)
		finish()
		return

	level_01.campaign_story_phase_finished.connect(_record_level_01_story_completion)
	var result_interface := main.get_node("GameResultPopup")
	level_01.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_DEFEAT)
	expect(
		bool(result_interface.call("is_result_visible")),
		"Level01 defeat presents the result interface"
	)
	expect(
		not level_01.is_campaign_control_available(),
		"Level01 defeat disables controls"
	)

	level_01.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)

	expect(
		main.call("get_active_campaign_level") == level_01,
		"Level01 remains active during its victory Story"
	)
	expect(level_01.is_campaign_story_phase_active(), "Level01 starts its victory Story")
	expect(paused, "Level01 victory Story pauses gameplay")
	expect(
		not level_01.is_campaign_control_available(),
		"Level01 victory Story disables controls"
	)
	expect(
		not bool(result_interface.call("is_result_visible")),
		"Level01 victory Story suppresses the result interface"
	)

	level_01.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_DEFEAT)
	level_01.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)
	expect(
		not bool(result_interface.call("is_result_visible")),
		"Victory takes precedence over competing defeat"
	)
	expect(
		main.call("get_active_campaign_level") == level_01,
		"Competing terminal outcomes do not transition during the victory Story"
	)

	for _input_index in MAX_STORY_ADVANCE_INPUTS:
		if main.call("get_active_campaign_level") != level_01:
			break
		await send_story_input()
	await process_frame

	var level_02 := main.call("get_active_campaign_level") as CampaignLevel
	expect(
		level_01_story_completion_count == 1,
		"Duplicate terminal outcomes produce one Level01 victory Story completion"
	)
	expect(level_02 != null, "Level01 victory Story completion starts a Level")
	if level_02 == null:
		await cleanup(main)
		finish()
		return
	expect(level_02.get_campaign_id() == &"level_02", "Level01 completion starts Level02")
	expect(not is_instance_valid(level_01), "Level01 is permanently disposed after completion")
	expect(
		not bool(result_interface.call("is_result_visible")),
		"Level02 starts without a result interface"
	)
	expect(level_02.is_campaign_story_phase_active(), "Level02 starts its opening Story")
	expect(paused, "Level02 opening Story pauses gameplay")
	expect(
		not level_02.is_campaign_control_available(),
		"Level02 opening Story keeps controls unavailable"
	)
	expect(not level_02.is_campaign_hud_visible(), "Level02 opening Story hides the HUD")
	expect(
		level_02.get_campaign_camera_role() == CAMERA_OPENING_STORY,
		"Level02 opening Story uses the Story Camera"
	)

	level_02.campaign_story_phase_finished.connect(_record_level_02_story_completion)
	for _input_index in MAX_STORY_ADVANCE_INPUTS:
		if level_02_story_completion_count > 0:
			break
		await send_story_input()

	expect(
		level_02_story_completion_count == 1,
		"Level02 opening Story completes exactly once"
	)
	expect(
		main.call("get_active_campaign_level") == level_02,
		"Level02 opening Story completion retains Level02"
	)
	expect(not paused, "Level02 opening Story completion unpauses gameplay")
	expect(level_02.is_campaign_control_available(), "Level02 enables controls after its Story")
	expect(level_02.is_campaign_hud_visible(), "Level02 shows the HUD after its Story")
	expect(
		level_02.get_campaign_camera_role() == CAMERA_PLAYER,
		"Level02 restores the Player Camera after its Story"
	)

	level_02.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)
	expect(
		main.call("get_active_campaign_level") == level_02,
		"Level02 remains active during its final victory Story"
	)
	expect(level_02.is_campaign_story_phase_active(), "Level02 starts its final victory Story")
	expect(paused, "Level02 final victory Story pauses gameplay")
	expect(
		not level_02.is_campaign_control_available(),
		"Level02 final victory Story disables controls"
	)
	expect(
		not bool(result_interface.call("is_result_visible")),
		"Level02 final victory Story suppresses the result interface"
	)

	level_02.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)
	level_02.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_DEFEAT)
	level_02.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)
	expect(
		not bool(result_interface.call("is_result_visible")),
		"Level02 victory takes precedence over competing defeat"
	)
	expect(
		main.call("get_active_campaign_level") == level_02,
		"Duplicate Level02 terminal outcomes retain the final campaign Level"
	)

	for _input_index in MAX_STORY_ADVANCE_INPUTS:
		if level_02_story_completion_count > 1:
			break
		await send_story_input()

	expect(
		level_02_story_completion_count == 2,
		"Duplicate Level02 terminal outcomes produce one final Story completion"
	)
	expect(
		main.call("get_active_campaign_level") == level_02,
		"Final Story completion retains the same Level02 instance"
	)
	expect(
		not level_02.is_campaign_story_phase_active(),
		"Final Story completion removes the Story"
	)
	expect(not paused, "Final Story completion unpauses gameplay")
	expect(level_02.is_campaign_control_available(), "Final Story completion enables controls")
	expect(level_02.is_campaign_hud_visible(), "Final Story completion keeps the HUD visible")
	expect(
		level_02.get_campaign_camera_role() == CAMERA_PLAYER,
		"Final Story completion keeps the Player Camera current"
	)

	level_02.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)
	level_02.campaign_story_phase_finished.emit()
	await process_frame
	expect(
		not level_02.is_campaign_story_phase_active(),
		"Late completion notifications cannot restart the final Story"
	)
	expect(
		main.call("get_active_campaign_level") == level_02,
		"Late completion notifications cannot transition the final campaign Level"
	)

	level_02.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_DEFEAT)
	level_02.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_DEFEAT)
	expect(
		bool(result_interface.call("is_result_visible")),
		"Level02 can present defeat after final Story completion"
	)
	expect(
		not level_02.is_campaign_control_available(),
		"Post-victory Level02 defeat disables controls"
	)

	result_interface.emit_signal("retry_requested")
	await process_frame

	var replacement := main.call("get_active_campaign_level") as CampaignLevel
	expect(replacement != null, "Level02 retry creates a replacement Level")
	expect(not is_instance_valid(level_02), "Level02 retry disposes the completed session")
	if replacement != null:
		expect(replacement.get_campaign_id() == &"level_02", "Level02 retry keeps campaign identity")
		expect(
			not replacement.is_campaign_story_phase_active(),
			"Level02 retry skips its opening Story"
		)
		expect(replacement.is_campaign_control_available(), "Level02 retry enables controls")
		expect(replacement.is_campaign_hud_visible(), "Level02 retry shows the HUD")
		expect(
			replacement.get_campaign_camera_role() == CAMERA_PLAYER,
			"Level02 retry restores the Player Camera"
		)
	expect(
		not bool(result_interface.call("is_result_visible")),
		"Level02 retry hides the result interface"
	)
	expect(not paused, "Level02 retry leaves the scene tree unpaused")

	await cleanup(main)
	finish()


func send_story_input() -> void:
	var input := InputEventKey.new()
	input.keycode = KEY_ENTER
	input.pressed = true
	Input.parse_input_event(input)
	await process_frame


func _record_level_01_story_completion() -> void:
	level_01_story_completion_count += 1


func _record_level_02_story_completion() -> void:
	level_02_story_completion_count += 1


func instantiate_main() -> Node:
	var scene := load(MAIN_SCENE) as PackedScene
	expect(scene != null, "Main scene can be loaded")
	if scene == null:
		return null

	var main := scene.instantiate()
	root.add_child(main)
	current_scene = main
	return main


func cleanup(main: Node) -> void:
	current_scene = null
	if is_instance_valid(main):
		main.free()
	paused = false
	await process_frame


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("Main Level progression test passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
