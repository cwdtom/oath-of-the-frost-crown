extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const MAIN_SCENE := "res://main.tscn"
const CAMERA_OPENING_STORY := &"opening_story"
const CAMERA_PLAYER := &"player"
const MAX_STORY_ADVANCE_INPUTS := 64

var fixture: HeadlessGameplayFixture
var level_01_story_completion_count := 0
var level_02_story_completion_count := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	var main := instantiate_main()
	if main == null:
		fixture.complete()
		return

	await fixture.process_frames(1)
	main.call("start_level_01", false)
	await fixture.process_frames(1)

	var level_01 := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(level_01 != null, "Campaign progression starts Level01")
	if level_01 == null:
		fixture.complete()
		return
	fixture.add_node(level_01)
	fixture.expect(level_01.is_campaign_health_full(), "Level01 starts with full campaign health")

	level_01.campaign_story_phase_finished.connect(_record_level_01_story_completion)
	var result_interface := main.get_node("GameResultPopup")
	level_01.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_DEFEAT)
	fixture.expect(
		bool(result_interface.call("is_result_visible")),
		"Level01 defeat presents the result interface"
	)
	fixture.expect(
		not level_01.is_campaign_control_available(),
		"Level01 defeat disables controls"
	)

	level_01.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)

	fixture.expect(
		main.call("get_active_campaign_level") == level_01,
		"Level01 remains active during its victory Story"
	)
	fixture.expect(level_01.is_campaign_story_phase_active(), "Level01 starts its victory Story")
	fixture.expect(paused, "Level01 victory Story pauses gameplay")
	fixture.expect(
		not level_01.is_campaign_control_available(),
		"Level01 victory Story disables controls"
	)
	fixture.expect(
		not bool(result_interface.call("is_result_visible")),
		"Level01 victory Story suppresses the result interface"
	)

	level_01.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_DEFEAT)
	level_01.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)
	fixture.expect(
		not bool(result_interface.call("is_result_visible")),
		"Victory takes precedence over competing defeat"
	)
	fixture.expect(
		main.call("get_active_campaign_level") == level_01,
		"Competing terminal outcomes do not transition during the victory Story"
	)

	for _input_index in MAX_STORY_ADVANCE_INPUTS:
		if main.call("get_active_campaign_level") != level_01:
			break
		await send_story_input()
	await fixture.process_frames(1)

	var level_02 := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		level_01_story_completion_count == 1,
		"Duplicate terminal outcomes produce one Level01 victory Story completion"
	)
	fixture.expect(level_02 != null, "Level01 victory Story completion starts a Level")
	if level_02 == null:
		fixture.complete()
		return
	fixture.add_node(level_02)
	fixture.expect(level_02.get_campaign_id() == &"level_02", "Level01 completion starts Level02")
	fixture.expect(not is_instance_valid(level_01), "Level01 is permanently disposed after completion")
	fixture.expect(
		not bool(result_interface.call("is_result_visible")),
		"Level02 starts without a result interface"
	)
	fixture.expect(level_02.is_campaign_story_phase_active(), "Level02 starts its opening Story")
	fixture.expect(paused, "Level02 opening Story pauses gameplay")
	fixture.expect(
		not level_02.is_campaign_control_available(),
		"Level02 opening Story keeps controls unavailable"
	)
	fixture.expect(level_02.is_campaign_health_full(), "Level02 starts with full campaign health")
	fixture.expect(not level_02.is_campaign_hud_visible(), "Level02 opening Story hides the HUD")
	fixture.expect(
		level_02.get_campaign_camera_role() == CAMERA_OPENING_STORY,
		"Level02 opening Story uses the Story Camera"
	)

	level_02.campaign_story_phase_finished.connect(_record_level_02_story_completion)
	for _input_index in MAX_STORY_ADVANCE_INPUTS:
		if level_02_story_completion_count > 0:
			break
		await send_story_input()

	fixture.expect(
		level_02_story_completion_count == 1,
		"Level02 opening Story completes exactly once"
	)
	fixture.expect(
		main.call("get_active_campaign_level") == level_02,
		"Level02 opening Story completion retains Level02"
	)
	fixture.expect(not paused, "Level02 opening Story completion unpauses gameplay")
	fixture.expect(level_02.is_campaign_control_available(), "Level02 enables controls after its Story")
	fixture.expect(level_02.is_campaign_hud_visible(), "Level02 shows the HUD after its Story")
	fixture.expect(
		level_02.get_campaign_camera_role() == CAMERA_PLAYER,
		"Level02 restores the Player Camera after its Story"
	)

	level_02.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)
	fixture.expect(
		main.call("get_active_campaign_level") == level_02,
		"Level02 remains active during its final victory Story"
	)
	fixture.expect(level_02.is_campaign_story_phase_active(), "Level02 starts its final victory Story")
	fixture.expect(paused, "Level02 final victory Story pauses gameplay")
	fixture.expect(
		not level_02.is_campaign_control_available(),
		"Level02 final victory Story disables controls"
	)
	fixture.expect(
		not bool(result_interface.call("is_result_visible")),
		"Level02 final victory Story suppresses the result interface"
	)

	level_02.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)
	level_02.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_DEFEAT)
	level_02.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)
	fixture.expect(
		not bool(result_interface.call("is_result_visible")),
		"Level02 victory takes precedence over competing defeat"
	)
	fixture.expect(
		main.call("get_active_campaign_level") == level_02,
		"Duplicate Level02 terminal outcomes retain the final campaign Level"
	)

	for _input_index in MAX_STORY_ADVANCE_INPUTS:
		if level_02_story_completion_count > 1:
			break
		await send_story_input()

	fixture.expect(
		level_02_story_completion_count == 2,
		"Duplicate Level02 terminal outcomes produce one final Story completion"
	)
	fixture.expect(
		main.call("get_active_campaign_level") == level_02,
		"Final Story completion retains the same Level02 instance"
	)
	fixture.expect(
		not level_02.is_campaign_story_phase_active(),
		"Final Story completion removes the Story"
	)
	fixture.expect(not paused, "Final Story completion unpauses gameplay")
	fixture.expect(level_02.is_campaign_control_available(), "Final Story completion enables controls")
	fixture.expect(level_02.is_campaign_health_full(), "Final Story completion keeps full campaign health")
	fixture.expect(level_02.is_campaign_hud_visible(), "Final Story completion keeps the HUD visible")
	fixture.expect(
		level_02.get_campaign_camera_role() == CAMERA_PLAYER,
		"Final Story completion keeps the Player Camera current"
	)

	level_02.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)
	level_02.campaign_story_phase_finished.emit()
	await fixture.process_frames(1)
	fixture.expect(
		not level_02.is_campaign_story_phase_active(),
		"Late completion notifications cannot restart the final Story"
	)
	fixture.expect(
		main.call("get_active_campaign_level") == level_02,
		"Late completion notifications cannot transition the final campaign Level"
	)

	level_02.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_DEFEAT)
	level_02.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_DEFEAT)
	fixture.expect(
		bool(result_interface.call("is_result_visible")),
		"Level02 can present defeat after final Story completion"
	)
	fixture.expect(
		not level_02.is_campaign_control_available(),
		"Post-victory Level02 defeat disables controls"
	)

	result_interface.emit_signal("retry_requested")
	await fixture.process_frames(1)

	var replacement := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(replacement != null, "Level02 retry creates a replacement Level")
	fixture.expect(not is_instance_valid(level_02), "Level02 retry disposes the completed session")
	if replacement != null:
		fixture.add_node(replacement)
		fixture.expect(replacement.get_campaign_id() == &"level_02", "Level02 retry keeps campaign identity")
		fixture.expect(
			not replacement.is_campaign_story_phase_active(),
			"Level02 retry skips its opening Story"
		)
		fixture.expect(replacement.is_campaign_control_available(), "Level02 retry enables controls")
		fixture.expect(replacement.is_campaign_health_full(), "Level02 retry restores full campaign health")
		fixture.expect(replacement.is_campaign_hud_visible(), "Level02 retry shows the HUD")
		fixture.expect(
			replacement.get_campaign_camera_role() == CAMERA_PLAYER,
			"Level02 retry restores the Player Camera"
		)
	fixture.expect(
		not bool(result_interface.call("is_result_visible")),
		"Level02 retry hides the result interface"
	)
	fixture.expect(not paused, "Level02 retry leaves the scene tree unpaused")

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func send_story_input() -> void:
	var input := InputEventKey.new()
	input.keycode = KEY_ENTER
	input.pressed = true
	Input.parse_input_event(input)
	await fixture.process_frames(1)


func _record_level_01_story_completion() -> void:
	level_01_story_completion_count += 1


func _record_level_02_story_completion() -> void:
	level_02_story_completion_count += 1


func instantiate_main() -> Node:
	var scene := load(MAIN_SCENE) as PackedScene
	fixture.expect(scene != null, "Main scene can be loaded")
	if scene == null:
		return null

	var main := fixture.instantiate_scene(scene)
	fixture.set_current_scene(main)
	return main
