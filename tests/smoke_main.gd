extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const MAIN_SCENE := "res://main.tscn"
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
	var result_interface := main.get_node_or_null("GameResultPopup")
	var title := main.get_node_or_null("Title")
	fixture.expect(title != null, "Main presents the production title interface")
	fixture.expect(
		result_interface != null
		and result_interface.has_signal("retry_requested")
		and result_interface.has_method("is_result_visible"),
		"Main presents the production result interface"
	)
	if title == null or result_interface == null:
		fixture.complete()
		return

	title.emit_signal("start_requested")
	await fixture.process_frames(1)
	var guide_input := InputEventKey.new()
	guide_input.keycode = KEY_SPACE
	guide_input.pressed = true
	Input.parse_input_event(guide_input)
	await fixture.process_frames(1)

	var level_01 := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		level_01 != null and level_01.get_campaign_id() == &"level_01",
		"Production title and guide input start Level01"
	)
	if level_01 == null:
		fixture.complete()
		return
	fixture.add_node(level_01)
	fixture.expect(
		find_player_event_source(level_01) != null,
		"Level01 wires its production Player"
	)
	fixture.expect(
		find_completion_event_source(level_01) != null,
		"Level01 wires its production completion encounter"
	)
	fixture.expect(level_01.has_campaign_music(), "Level01 wires its production Background")

	await advance_story_phase(level_01, "Level01 opening Story")
	var prologue := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		prologue != null and prologue.get_campaign_id() == &"level_00",
		"Level01 opening Story starts the production Level00 prologue"
	)
	if prologue == null:
		fixture.complete()
		return

	await advance_story_phase(prologue, "Level00 Story")
	fixture.expect(
		main.call("get_active_campaign_level") == level_01,
		"Level00 Story restores the same production Level01"
	)
	fixture.expect(
		level_01.is_campaign_control_available(),
		"Restored Level01 enables Player control"
	)
	fixture.expect(level_01.is_campaign_hud_visible(), "Restored Level01 presents its HUD")
	fixture.expect(
		level_01.get_campaign_camera_role() == CAMERA_PLAYER,
		"Restored Level01 uses its Player Camera"
	)

	var player := find_player_event_source(level_01)
	if player != null:
		player.emit_signal("died")
	fixture.expect(
		bool(result_interface.call("is_result_visible")),
		"Production Player defeat reaches the result interface"
	)
	result_interface.emit_signal("retry_requested")
	await fixture.process_frames(1)

	var retried_level_01 := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		retried_level_01 != null and retried_level_01 != level_01,
		"Production retry replaces Level01"
	)
	fixture.expect(
		retried_level_01 != null and retried_level_01.is_campaign_health_full(),
		"Production retry restores full Player and HUD health"
	)
	if retried_level_01 == null:
		fixture.complete()
		return

	var level_01_completion := find_completion_event_source(retried_level_01)
	if level_01_completion != null:
		level_01_completion.emit_signal("died")
	fixture.expect(
		retried_level_01.is_campaign_story_phase_active(),
		"Level01 production completion starts its victory Story"
	)
	await advance_story_phase(retried_level_01, "Level01 victory Story")

	var level_02 := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		level_02 != null and level_02.get_campaign_id() == &"level_02",
		"Level01 production completion starts Level02"
	)
	if level_02 == null:
		fixture.complete()
		return
	fixture.expect(
		find_player_event_source(level_02) != null,
		"Level02 wires its production Player"
	)
	fixture.expect(
		find_completion_event_source(level_02) != null,
		"Level02 wires its production completion encounter"
	)
	fixture.expect(level_02.has_campaign_music(), "Level02 wires its production Background")

	await advance_story_phase(level_02, "Level02 opening Story")
	var level_02_completion := find_completion_event_source(level_02)
	if level_02_completion != null:
		level_02_completion.emit_signal("died")
	fixture.expect(
		level_02.is_campaign_story_phase_active(),
		"Level02 production completion starts its final Story"
	)
	await advance_story_phase(level_02, "Level02 final Story")

	var level_03 := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		level_03 != null and level_03.get_campaign_id() == &"level_03",
		"Level02 final Story completion starts Level03"
	)
	fixture.expect(not is_instance_valid(level_02), "Level03 initialization disposes Level02")
	if level_03 == null:
		fixture.complete()
		return
	fixture.add_node(level_03)
	fixture.expect(
		find_player_event_source(level_03) != null,
		"Level03 wires its production Player"
	)
	fixture.expect(not level_03.is_campaign_story_phase_active(), "Level03 has no Opening Story")
	fixture.expect(not paused, "Level03 initialization leaves the campaign unpaused")
	fixture.expect(
		level_03.is_campaign_control_available(),
		"Level03 initialization enables Player control"
	)
	fixture.expect(level_03.is_campaign_health_full(), "Level03 initializes at full health")
	fixture.expect(level_03.is_campaign_hud_visible(), "Level03 initialization presents its HUD")
	fixture.expect(
		level_03.get_campaign_camera_role() == CAMERA_PLAYER,
		"Level03 initialization uses its Player Camera"
	)

	var exit_code := fixture.complete(false)
	await fixture.process_frames(3)
	if exit_code == 0:
		print("Production campaign smoke test passed")
	fixture.complete()


func advance_story_phase(level: CampaignLevel, description: String) -> void:
	var phase_finished := [false]
	level.campaign_story_phase_finished.connect(
		func() -> void: phase_finished[0] = true,
		CONNECT_ONE_SHOT
	)
	for _input_index in MAX_STORY_ADVANCE_INPUTS:
		if phase_finished[0]:
			break
		var story_input := InputEventKey.new()
		story_input.keycode = KEY_ENTER
		story_input.pressed = true
		Input.parse_input_event(story_input)
		await fixture.process_frames(1)

	fixture.expect(phase_finished[0], "%s completes through production input" % description)


func find_player_event_source(level: CampaignLevel) -> Node:
	for node in level.find_children("*", "", true, false):
		if node.has_signal("hurt_taken") and node.has_signal("died"):
			return node
	return null


func find_completion_event_source(level: CampaignLevel) -> Node:
	for node in level.find_children("*", "", true, false):
		if node.is_in_group("enemies") and node.has_signal("died"):
			return node
	return null


func instantiate_main() -> Node:
	var scene := load(MAIN_SCENE) as PackedScene
	fixture.expect(scene != null, "Main scene can be loaded")
	if scene == null:
		return null

	var main := fixture.instantiate_scene(scene)
	fixture.set_current_scene(main)
	return main
