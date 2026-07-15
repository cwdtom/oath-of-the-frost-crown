extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const MAIN_SCENE := "res://main.tscn"
const PHASE_TITLE := &"title"
const PHASE_GUIDE := &"guide"
const PHASE_LEVEL := &"level"
const CAMERA_OPENING_STORY := &"opening_story"
const CAMERA_PLAYER := &"player"
const MAX_STORY_ADVANCE_INPUTS := 64

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	var main := instantiate_main()
	if main == null:
		fixture.complete()
		return

	await fixture.process_frames(1)
	fixture.expect(main.call("get_campaign_phase") == PHASE_TITLE, "Campaign starts at the title")
	fixture.expect(main.call("get_active_campaign_level") == null, "Title has no active Level")

	var title := main.get_node_or_null("Title")
	fixture.expect(title != null, "Main presents its title input")
	if title == null:
		fixture.complete()
		return

	title.emit_signal("start_requested")
	await fixture.process_frames(1)
	fixture.expect(main.call("get_campaign_phase") == PHASE_GUIDE, "Title start presents the guide")
	fixture.expect(main.call("get_active_campaign_level") == null, "Guide has no active Level")

	var guide_input := InputEventKey.new()
	guide_input.keycode = KEY_SPACE
	guide_input.pressed = true
	Input.parse_input_event(guide_input)
	await fixture.process_frames(1)

	var level_01 := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(main.call("get_campaign_phase") == PHASE_LEVEL, "Guide input enters a Level")
	fixture.expect(level_01 != null, "Guide input starts a campaign Level")
	if level_01 == null:
		fixture.complete()
		return
	fixture.add_node(level_01)
	fixture.expect(level_01.get_campaign_id() == &"level_01", "Guide input starts Level01")

	fixture.expect(level_01.is_campaign_story_phase_active(), "Level01 opens with its Story")
	fixture.expect(paused, "Level01 opening Story pauses the campaign")
	fixture.expect(
		not level_01.is_campaign_control_available(),
		"Level01 opening Story makes gameplay controls unavailable"
	)
	fixture.expect(not level_01.is_campaign_hud_visible(), "Level01 opening Story hides the HUD")
	fixture.expect(
		level_01.get_campaign_camera_role() == CAMERA_OPENING_STORY,
		"Level01 opening Story uses the Story Camera"
	)
	if DisplayServer.get_name() != "headless":
		fixture.expect(level_01.is_campaign_music_playing(), "Level01 music plays before suspension")

	Input.parse_input_event(guide_input)
	await fixture.process_frames(1)
	fixture.expect(
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
		await fixture.process_frames(1)

	fixture.expect(
		observed["story_phase_finished"],
		"Level01 opening Story completes through the Level seam"
	)
	var prologue := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		prologue != null and prologue.get_campaign_id() == &"level_00",
		"Main handles Level01 Story completion through the Level seam"
	)
	if prologue == null:
		fixture.complete()
		return
	fixture.add_node(prologue)
	fixture.expect(is_instance_valid(level_01), "Level01 remains alive during the prologue")
	fixture.expect(not level_01.is_inside_tree(), "Level01 is outside the active scene tree")
	fixture.expect(not level_01.is_campaign_music_playing(), "Level01 music stops during the prologue")
	var music_position_at_suspension := level_01.get_campaign_music_playback_position()

	level_01.campaign_story_phase_finished.emit()
	await fixture.process_frames(1)
	fixture.expect(
		main.call("get_active_campaign_level") == prologue,
		"Duplicate Level01 Story completion cannot start another prologue"
	)

	prologue.campaign_story_phase_finished.emit()
	fixture.expect(
		main.call("get_active_campaign_level") == level_01,
		"Level00 Story completion restores the retained Level01"
	)
	fixture.expect(level_01.is_inside_tree(), "Restored Level01 returns to the active scene tree")
	fixture.expect(
		not level_01.is_campaign_story_phase_active(),
		"Restored Level01 keeps its opening Story completed"
	)
	fixture.expect(not paused, "Restored Level01 gameplay is unpaused")
	fixture.expect(level_01.is_campaign_control_available(), "Restored Level01 enables controls")
	fixture.expect(level_01.is_campaign_hud_visible(), "Restored Level01 shows the HUD")
	fixture.expect(
		level_01.get_campaign_camera_role() == CAMERA_PLAYER,
		"Restored Level01 uses the Player Camera"
	)
	fixture.expect(
		level_01.get_campaign_music_playback_position() >= music_position_at_suspension,
		"Level01 music resumes from its retained position"
	)
	if DisplayServer.get_name() != "headless":
		fixture.expect(level_01.is_campaign_music_playing(), "Restored Level01 music is playing")

	prologue.campaign_story_phase_finished.emit()
	await fixture.process_frames(1)
	fixture.expect(
		main.call("get_active_campaign_level") == level_01,
		"Duplicate Level00 Story completion cannot restore another Level"
	)

	level_01.campaign_story_phase_finished.emit()
	await fixture.process_frames(1)
	fixture.expect(
		main.call("get_active_campaign_level") == level_01,
		"Late duplicate Level01 Story completion cannot restart the prologue"
	)

	await retire_main(main)
	await verify_pointer_guide_input()
	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func verify_pointer_guide_input() -> void:
	var main := instantiate_main()
	if main == null:
		return

	await fixture.process_frames(1)
	var title := main.get_node_or_null("Title")
	if title == null:
		fixture.expect(false, "Pointer Guide check is missing the title input")
		return

	title.emit_signal("start_requested")
	await fixture.process_frames(1)

	var guide_input := InputEventMouseButton.new()
	guide_input.button_index = MOUSE_BUTTON_LEFT
	guide_input.pressed = true
	Input.parse_input_event(guide_input)
	await fixture.process_frames(1)

	var level_01 := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		level_01 != null and level_01.get_campaign_id() == &"level_01",
		"Pointer guide input starts Level01"
	)
	if level_01 != null:
		fixture.add_node(level_01)
	Input.parse_input_event(guide_input)
	await fixture.process_frames(1)
	fixture.expect(
		main.call("get_active_campaign_level") == level_01,
		"Repeated pointer guide input cannot start another Level01 session"
	)

	await retire_main(main)


func instantiate_main() -> Node:
	var scene := load(MAIN_SCENE) as PackedScene
	fixture.expect(scene != null, "Main scene can be loaded")
	if scene == null:
		return null

	var main := fixture.instantiate_scene(scene)
	fixture.set_current_scene(main)
	return main


func retire_main(main: Node) -> void:
	fixture.set_current_scene(null)
	if is_instance_valid(main) and main.is_inside_tree():
		root.remove_child(main)
	fixture.set_paused(false)
	await fixture.process_frames(1)
