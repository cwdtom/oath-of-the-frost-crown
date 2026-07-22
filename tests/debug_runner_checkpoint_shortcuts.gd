extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const DEBUG_RUNNER_SCENE := preload("res://debug/debug_runner.tscn")
const MAIN_SCENE := preload("res://main.tscn")
const LEVEL_01_SCENE := preload("res://levels/level_01.tscn")
const VALDEMAR_AWAKENING_DISTANCE := 600.0
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

	runner = fixture.instantiate_scene(DEBUG_RUNNER_SCENE)
	fixture.set_current_scene(runner)
	await fixture.process_frames(1)
	await verify_victory_story_interruption(runner)
	await retire_runner(runner)

	runner = fixture.instantiate_scene(DEBUG_RUNNER_SCENE)
	fixture.set_current_scene(runner)
	await fixture.process_frames(1)
	await verify_defeat_result_replacement(runner)
	await retire_runner(runner)

	runner = fixture.instantiate_scene(DEBUG_RUNNER_SCENE)
	fixture.set_current_scene(runner)
	await fixture.process_frames(1)
	await verify_level_04_shortcuts(runner)
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

	var level_03_story := await switch_checkpoint(
		runner, repeated_level_02_combat, KEY_5, &"level_03", true, "Ctrl+5"
	)
	if level_03_story == null:
		return
	var level_03_combat := await switch_checkpoint(
		runner, level_03_story, KEY_6, &"level_03", false, "Ctrl+6"
	)
	if level_03_combat == null:
		return

	var level_01_story := await switch_checkpoint(
		runner, level_03_combat, KEY_1, &"level_01", true, "Ctrl+1"
	)
	if level_01_story == null:
		return

	await advance_story_phase(level_01_story, "Ctrl+1 Level01 opening Story")
	var prologue := runner.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		prologue != null and prologue.get_campaign_id() == &"level_00",
		"Ctrl+1 retains the normal Level00 prologue flow"
	)
	if prologue == null:
		return
	fixture.add_node(prologue)

	var level_02_combat_after_prologue := await switch_checkpoint(
		runner, prologue, KEY_4, &"level_02", false, "Ctrl+4 during Level00"
	)
	fixture.expect(
		not is_instance_valid(level_01_story),
		"Checkpoint switching during Level00 disposes the suspended Level01"
	)
	if level_02_combat_after_prologue == null:
		return

	var replacement_level_01 := await switch_checkpoint(
		runner, level_02_combat_after_prologue, KEY_1, &"level_01", true,
		"Ctrl+1 after abandoning Level00"
	)
	if replacement_level_01 == null:
		return

	await advance_story_phase(replacement_level_01, "Replacement Level01 opening Story")
	var replacement_prologue := runner.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		replacement_prologue != null
		and replacement_prologue.get_campaign_id() == &"level_00",
		"Re-entered checkpoint 1 starts a fresh Level00 prologue"
	)
	if replacement_prologue == null:
		return
	fixture.add_node(replacement_prologue)

	await advance_story_phase(replacement_prologue, "Replacement Level00 prologue")
	fixture.expect(
		runner.call("get_active_campaign_level") == replacement_level_01,
		"Fresh Level00 completion restores the replacement Level01"
	)
	fixture.expect(
		replacement_level_01.is_campaign_control_available(),
		"Restored replacement Level01 is usable"
	)
	fixture.expect(not paused, "Restored replacement Level01 leaves the SceneTree unpaused")


func verify_victory_story_interruption(runner: Node) -> void:
	var opening_level := runner.call("get_active_campaign_level") as CampaignLevel
	var abandoned_level := await switch_checkpoint(
		runner, opening_level, KEY_2, &"level_01", false, "Victory test Ctrl+2"
	)
	if abandoned_level == null:
		return

	abandoned_level.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)
	fixture.expect(
		abandoned_level.is_campaign_story_phase_active(),
		"Level01 completion starts its victory Story"
	)
	fixture.expect(paused, "Level01 victory Story pauses the SceneTree")

	var replacement := await switch_checkpoint(
		runner, abandoned_level, KEY_2, &"level_01", false,
		"Ctrl+2 during a victory Story"
	)
	if replacement == null:
		return
	fixture.expect(
		replacement.is_campaign_control_available(),
		"Victory Story replacement starts usable Level01 combat"
	)
	fixture.expect(not paused, "Victory Story replacement unpauses the SceneTree")

	replacement.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)
	fixture.expect(
		replacement.is_campaign_story_phase_active(),
		"Replacement Level can start its own victory Story"
	)

	runner.call("replace_campaign_session", LEVEL_01_SCENE, false)
	var final_replacement := runner.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		final_replacement != null and final_replacement != replacement,
		"Victory replacement starts a fresh session for stale-source verification"
	)
	if final_replacement == null or final_replacement == replacement:
		return
	fixture.add_node(final_replacement)

	replacement.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)
	replacement.campaign_story_phase_finished.emit()
	fixture.expect(
		runner.call("get_active_campaign_level") == final_replacement,
		"Delayed abandoned victory signals cannot transition the replacement session"
	)
	fixture.expect(
		not bool(runner.call("is_campaign_result_visible")),
		"Delayed abandoned victory signals cannot expose result UI"
	)

	final_replacement.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)
	fixture.expect(
		final_replacement.is_campaign_story_phase_active(),
		"Final replacement Level can start its own victory Story"
	)
	await advance_story_phase(final_replacement, "Replacement Level01 victory Story")
	var level_02 := runner.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		level_02 != null and level_02.get_campaign_id() == &"level_02",
		"Replacement Level victory completes through normal campaign progression"
	)
	if level_02 != null:
		fixture.add_node(level_02)


func verify_defeat_result_replacement(runner: Node) -> void:
	var opening_level := runner.call("get_active_campaign_level") as CampaignLevel
	var defeated_level := await switch_checkpoint(
		runner, opening_level, KEY_2, &"level_01", false, "Defeat test Ctrl+2"
	)
	if defeated_level == null:
		return

	defeated_level.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_DEFEAT)
	fixture.expect(
		bool(runner.call("is_campaign_result_visible")),
		"Level defeat presents its result before checkpoint replacement"
	)

	var replacement := await switch_checkpoint(
		runner, defeated_level, KEY_4, &"level_02", false, "Ctrl+4 from defeat result"
	)
	fixture.expect(
		not bool(runner.call("is_campaign_result_visible")),
		"Checkpoint replacement dismisses the stale defeat result"
	)
	if replacement == null:
		return
	fixture.expect(
		replacement.is_campaign_control_available(),
		"Defeat-result replacement starts usable Level02 combat"
	)

	replacement.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_DEFEAT)
	fixture.expect(
		bool(runner.call("is_campaign_result_visible")),
		"Replacement Level can still reach its own defeat result"
	)


func verify_level_04_shortcuts(runner: Node) -> void:
	var opening_level := runner.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(opening_level != null, "Level04 shortcut test starts checkpoint 1")
	if opening_level == null:
		return
	fixture.add_node(opening_level)

	var level_04_story := await switch_checkpoint(
		runner, opening_level, KEY_7, &"level_04", true, "Ctrl+7"
	)
	if level_04_story == null:
		return
	await advance_story_phase(level_04_story, "Ctrl+7 Level04 opening Story")
	await verify_level_04_pre_awakening_story(level_04_story, "Ctrl+7")

	var level_04_playable := await switch_checkpoint(
		runner, level_04_story, KEY_8, &"level_04", false, "Ctrl+8"
	)
	if level_04_playable == null:
		return
	fixture.expect(
		level_04_playable.is_campaign_hud_visible(),
		"Ctrl+8 starts Level04 with its HUD visible"
	)
	fixture.expect(
		level_04_playable.get_campaign_camera_role() == CampaignLevel.CAMERA_PLAYER,
		"Ctrl+8 starts Level04 with the Player Camera"
	)
	await verify_level_04_pre_awakening_story(level_04_playable, "Ctrl+8")


func verify_level_04_pre_awakening_story(
	level: CampaignLevel,
	shortcut: String
) -> void:
	var player := level.get_node("Player") as DamageableActor
	var valdemar := level.get_node("Enemies/Valdemar") as DamageableActor
	player.global_position = (
		valdemar.global_position
		+ Vector2(-VALDEMAR_AWAKENING_DISTANCE - 20.0, -5000.0)
	)
	await fixture.physics_frames(2)
	player.global_position.x = (
		valdemar.global_position.x - VALDEMAR_AWAKENING_DISTANCE + 1.0
	)
	await fixture.physics_frames(3)

	var pre_awakening_story := level.get_node_or_null("PreAwakeningStory")
	fixture.expect(
		level.is_campaign_story_phase_active()
		and pre_awakening_story != null
		and pre_awakening_story.get("story_path")
		== "res://levels/level_04_a_story.json",
		"%s plays lv_4_a when the Player enters Valdemar's boundary" % shortcut
	)
	fixture.expect(paused, "%s pauses for the Pre-Awakening Story" % shortcut)


func switch_checkpoint(
	runner: Node,
	previous_level: CampaignLevel,
	keycode: Key,
	expected_campaign_id: StringName,
	play_opening_story: bool,
	shortcut: String,
	expect_enemies := true
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
	verify_debug_health_overrides(level, shortcut, expect_enemies)
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


func advance_story_phase(level: CampaignLevel, description: String) -> void:
	var finished := [false]
	level.campaign_story_phase_finished.connect(func() -> void: finished[0] = true)
	for _input_index in MAX_STORY_ADVANCE_INPUTS:
		if finished[0]:
			break
		send_key(KEY_ENTER, false)
		await fixture.process_frames(1)
	fixture.expect(finished[0], "%s completes through input" % description)


func verify_debug_health_overrides(
	level: CampaignLevel,
	checkpoint: String,
	expect_enemies := true
) -> void:
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
	fixture.expect(
		found_enemy == expect_enemies,
		"%s has the expected compatible-Enemy presence" % checkpoint
	)


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

	for keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8]:
		send_key(keycode, true)
		await fixture.process_frames(1)

	fixture.expect(
		main.call("get_campaign_phase") == campaign_phase,
		"Ctrl+1 through Ctrl+8 leave the production Campaign phase unchanged"
	)
	fixture.expect(
		main.call("get_active_campaign_level") == active_level,
		"Ctrl+1 through Ctrl+8 leave the production active Level unchanged"
	)
