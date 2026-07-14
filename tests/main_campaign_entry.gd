extends SceneTree


const MAIN_SCENE := "res://main.tscn"
const PHASE_TITLE := &"title"
const PHASE_GUIDE := &"guide"
const PHASE_LEVEL := &"level"
const CAMERA_OPENING_STORY := &"opening_story"
const MAX_STORY_ADVANCE_INPUTS := 64

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := instantiate_main()
	if main == null:
		finish()
		return

	await process_frame
	expect(main.call("get_campaign_phase") == PHASE_TITLE, "Campaign starts at the title")
	expect(main.call("get_active_campaign_level") == null, "Title has no active Level")

	var title := main.get_node_or_null("Title")
	expect(title != null, "Main presents its title input")
	if title == null:
		await cleanup(main)
		finish()
		return

	title.emit_signal("start_requested")
	await process_frame
	expect(main.call("get_campaign_phase") == PHASE_GUIDE, "Title start presents the guide")
	expect(main.call("get_active_campaign_level") == null, "Guide has no active Level")

	var guide_input := InputEventKey.new()
	guide_input.keycode = KEY_SPACE
	guide_input.pressed = true
	Input.parse_input_event(guide_input)
	await process_frame

	var level_01 := main.call("get_active_campaign_level") as CampaignLevel
	expect(main.call("get_campaign_phase") == PHASE_LEVEL, "Guide input enters a Level")
	expect(level_01 != null, "Guide input starts a campaign Level")
	if level_01 == null:
		await cleanup(main)
		finish()
		return
	expect(level_01.get_campaign_id() == &"level_01", "Guide input starts Level01")

	expect(level_01.is_campaign_story_phase_active(), "Level01 opens with its Story")
	expect(paused, "Level01 opening Story pauses the campaign")
	expect(
		not level_01.is_campaign_control_available(),
		"Level01 opening Story makes gameplay controls unavailable"
	)
	expect(not level_01.is_campaign_hud_visible(), "Level01 opening Story hides the HUD")
	expect(
		level_01.get_campaign_camera_role() == CAMERA_OPENING_STORY,
		"Level01 opening Story uses the Story Camera"
	)

	Input.parse_input_event(guide_input)
	await process_frame
	expect(
		main.call("get_active_campaign_level") == level_01,
		"Repeated guide input cannot start another Level01 session"
	)

	var observed := {"story_phase_finished": false}
	level_01.campaign_story_phase_finished.connect(
		func() -> void: observed["story_phase_finished"] = true
	)
	for _input_index in MAX_STORY_ADVANCE_INPUTS:
		if observed["story_phase_finished"]:
			break
		var story_input := InputEventKey.new()
		story_input.keycode = KEY_ENTER
		story_input.pressed = true
		Input.parse_input_event(story_input)
		await process_frame

	expect(
		observed["story_phase_finished"],
		"Level01 opening Story completes through the Level seam"
	)
	var prologue := main.call("get_active_campaign_level") as CampaignLevel
	expect(
		prologue != null and prologue.get_campaign_id() == &"level_00",
		"Main handles Level01 Story completion through the Level seam"
	)

	await cleanup(main, level_01)
	await verify_pointer_guide_input()
	finish()


func verify_pointer_guide_input() -> void:
	var main := instantiate_main()
	if main == null:
		return

	await process_frame
	var title := main.get_node_or_null("Title")
	if title == null:
		failures.append("Pointer Guide check is missing the title input")
		await cleanup(main)
		return

	title.emit_signal("start_requested")
	await process_frame

	var guide_input := InputEventMouseButton.new()
	guide_input.button_index = MOUSE_BUTTON_LEFT
	guide_input.pressed = true
	Input.parse_input_event(guide_input)
	await process_frame

	var level_01 := main.call("get_active_campaign_level") as CampaignLevel
	expect(
		level_01 != null and level_01.get_campaign_id() == &"level_01",
		"Pointer guide input starts Level01"
	)
	Input.parse_input_event(guide_input)
	await process_frame
	expect(
		main.call("get_active_campaign_level") == level_01,
		"Repeated pointer guide input cannot start another Level01 session"
	)

	await cleanup(main, level_01)


func instantiate_main() -> Node:
	var scene := load(MAIN_SCENE) as PackedScene
	expect(scene != null, "Main scene can be loaded")
	if scene == null:
		return null

	var main := scene.instantiate()
	root.add_child(main)
	current_scene = main
	return main


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func cleanup(main: Node, retained_level: CampaignLevel = null) -> void:
	current_scene = null
	if is_instance_valid(main):
		main.free()
	if is_instance_valid(retained_level) and not retained_level.is_inside_tree():
		retained_level.free()
	paused = false
	await process_frame


func finish() -> void:
	if failures.is_empty():
		print("Main campaign entry test passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
