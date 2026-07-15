extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const DEBUG_RUNNER_SCENE := preload("res://debug/debug_runner.tscn")
const MAIN_SCENE := preload("res://main.tscn")
const MAX_STORY_ADVANCE_INPUTS := 64

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	var runner := fixture.instantiate_scene(DEBUG_RUNNER_SCENE)
	fixture.set_current_scene(runner)
	await fixture.process_frames(1)

	await verify_runner_shortcuts(runner)
	await retire_runner(runner)
	await verify_production_main_is_inert()

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func verify_runner_shortcuts(runner: Node) -> void:
	var opening_level := runner.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(opening_level != null, "Debug Runner starts a Campaign Level")
	if opening_level == null:
		return
	fixture.add_node(opening_level)
	fixture.expect(paused, "Checkpoint 1 opening Story pauses the SceneTree")

	var abandoned_story_finished := [false]
	opening_level.campaign_story_phase_finished.connect(
		func() -> void: abandoned_story_finished[0] = true
	)
	var level_01_combat := await switch_checkpoint(
		runner, opening_level, KEY_2, &"level_01", false, "Ctrl+2"
	)
	fixture.expect(
		not abandoned_story_finished[0],
		"Ctrl+2 does not finish the abandoned opening Story"
	)
	if level_01_combat == null:
		return

	var level_02_story := await switch_checkpoint(
		runner, level_01_combat, KEY_3, &"level_02", true, "Ctrl+3"
	)
	if level_02_story == null:
		return

	var level_02_combat := await switch_checkpoint(
		runner, level_02_story, KEY_4, &"level_02", false, "Ctrl+4"
	)
	if level_02_combat == null:
		return

	await verify_inert_shortcut_events(runner, level_02_combat)

	var added_levels := [0]
	var count_added_levels := func(node: Node) -> void:
		if node is CampaignLevel:
			added_levels[0] += 1
	runner.child_entered_tree.connect(count_added_levels)
	var repeated_level_02_combat := await switch_checkpoint(
		runner, level_02_combat, KEY_4, &"level_02", false, "Repeated Ctrl+4"
	)
	runner.child_entered_tree.disconnect(count_added_levels)
	fixture.expect(
		added_levels[0] == 1,
		"One non-echo shortcut creates exactly one replacement session"
	)
	if repeated_level_02_combat == null:
		return

	var level_01_story := await switch_checkpoint(
		runner, repeated_level_02_combat, KEY_1, &"level_01", true, "Ctrl+1"
	)
	if level_01_story == null:
		return

	await advance_story_phase(level_01_story)
	var prologue := runner.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		prologue != null and prologue.get_campaign_id() == &"level_00",
		"Ctrl+1 retains the normal Level00 prologue flow"
	)
	if prologue != null:
		fixture.add_node(prologue)


func switch_checkpoint(
	runner: Node,
	previous_level: CampaignLevel,
	keycode: Key,
	expected_campaign_id: StringName,
	play_opening_story: bool,
	shortcut: String
) -> CampaignLevel:
	send_key(keycode, true)
	await fixture.process_frames(2)

	var level := runner.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(level != null, "%s starts a Campaign Level" % shortcut)
	fixture.expect(level != previous_level, "%s creates a fresh Level instance" % shortcut)
	fixture.expect(
		not is_instance_valid(previous_level),
		"%s disposes the replaced Level" % shortcut
	)
	if level == null:
		return null

	fixture.add_node(level)
	fixture.expect(
		level.get_campaign_id() == expected_campaign_id,
		"%s starts %s" % [shortcut, expected_campaign_id]
	)
	fixture.expect(
		level.is_campaign_story_phase_active() == play_opening_story,
		"%s uses the requested opening-Story choice" % shortcut
	)
	fixture.expect(
		level.is_campaign_control_available() != play_opening_story,
		"%s uses the requested gameplay state" % shortcut
	)
	fixture.expect(paused == play_opening_story, "%s uses the requested pause state" % shortcut)
	verify_debug_health_overrides(level, shortcut)
	return level


func verify_inert_shortcut_events(runner: Node, active_level: CampaignLevel) -> void:
	await expect_inert_key(
		runner, active_level, KEY_4, false, true, false,
		"A plain number key does not replace the active checkpoint"
	)
	await expect_inert_key(
		runner, active_level, KEY_CTRL, true, true, false,
		"Ctrl without an assigned number does not replace the active checkpoint"
	)
	await expect_inert_key(
		runner, active_level, KEY_4, true, false, false,
		"A released shortcut does not replace the active checkpoint"
	)
	await expect_inert_key(
		runner, active_level, KEY_4, true, true, true,
		"An echo shortcut does not replace the active checkpoint"
	)


func expect_inert_key(
	runner: Node,
	active_level: CampaignLevel,
	keycode: Key,
	control_pressed: bool,
	pressed: bool,
	echo: bool,
	description: String
) -> void:
	send_key(keycode, control_pressed, pressed, echo)
	await fixture.process_frames(1)
	fixture.expect(runner.call("get_active_campaign_level") == active_level, description)


func send_key(
	keycode: Key,
	control_pressed: bool,
	pressed := true,
	echo := false
) -> void:
	var input := InputEventKey.new()
	input.keycode = keycode
	input.ctrl_pressed = control_pressed
	input.pressed = pressed
	input.echo = echo
	Input.parse_input_event(input)


func advance_story_phase(level: CampaignLevel) -> void:
	var finished := [false]
	level.campaign_story_phase_finished.connect(func() -> void: finished[0] = true)
	for _input_index in MAX_STORY_ADVANCE_INPUTS:
		if finished[0]:
			break
		send_key(KEY_ENTER, false)
		await fixture.process_frames(1)
	fixture.expect(finished[0], "Ctrl+1 Level01 opening Story completes through input")


func verify_debug_health_overrides(level: CampaignLevel, checkpoint: String) -> void:
	var player := level.get_node_or_null("Player")
	fixture.expect(
		player != null and player.call("get_current_health") == 999,
		"%s gives the Player 999 internal health" % checkpoint
	)

	var found_enemy := false
	for node in get_nodes_in_group("enemies"):
		if node is Node and level.is_ancestor_of(node) and node.has_method("get_current_health"):
			found_enemy = true
			fixture.expect(
				node.call("get_current_health") == 1,
				"%s gives %s 1 internal health" % [checkpoint, node.name]
			)
	fixture.expect(found_enemy, "%s contains compatible Enemies" % checkpoint)


func retire_runner(runner: Node) -> void:
	fixture.set_current_scene(null)
	if is_instance_valid(runner) and runner.is_inside_tree():
		root.remove_child(runner)
		runner.free()
	fixture.set_paused(false)
	await fixture.process_frames(1)


func verify_production_main_is_inert() -> void:
	var main := fixture.instantiate_scene(MAIN_SCENE)
	fixture.set_current_scene(main)
	await fixture.process_frames(1)
	var campaign_phase: StringName = main.call("get_campaign_phase")
	var active_level := main.call("get_active_campaign_level") as CampaignLevel

	for keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
		send_key(keycode, true)
		await fixture.process_frames(1)

	fixture.expect(
		main.call("get_campaign_phase") == campaign_phase,
		"Ctrl+1 through Ctrl+4 leave the production Campaign phase unchanged"
	)
	fixture.expect(
		main.call("get_active_campaign_level") == active_level,
		"Ctrl+1 through Ctrl+4 leave the production active Level unchanged"
	)
