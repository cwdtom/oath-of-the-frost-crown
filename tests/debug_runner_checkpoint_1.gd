extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const DEBUG_RUNNER_SCENE := "res://debug/debug_runner.tscn"
const WOLF_SCENE := preload("res://enemies/wolf.tscn")
const MAX_STORY_ADVANCE_INPUTS := 64

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	var runner := instantiate_runner()
	if runner == null:
		fixture.complete()
		return

	await fixture.process_frames(1)
	var level := runner.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(level != null, "Debug Runner automatically enters a Campaign Level")
	if level != null:
		fixture.add_node(level)
		fixture.expect(level.get_campaign_id() == &"level_01", "Checkpoint 1 starts Level01")
		fixture.expect(
			level.is_campaign_story_phase_active(),
			"Checkpoint 1 starts the Level01 opening Story"
		)
		fixture.expect(paused, "Checkpoint 1 opening Story pauses the campaign")
		verify_debug_health_overrides(level)
		await verify_late_enemy_override(level)
		await verify_campaign_progression(runner, level)

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func verify_debug_health_overrides(level: CampaignLevel) -> void:
	var player := level.get_node_or_null("Player")
	fixture.expect(
		player != null and player.call("get_current_health") == 999,
		"Checkpoint 1 gives the Player 999 internal health"
	)
	fixture.expect(
		player != null and player.call("get_maximum_health") == 5,
		"The Player keeps its normal presentation maximum"
	)

	var enemies := get_level_enemies(level)
	fixture.expect(not enemies.is_empty(), "Checkpoint 1 contains compatible Enemies")
	for enemy in enemies:
		fixture.expect(
			enemy.call("get_current_health") == 1,
			"Checkpoint 1 gives %s 1 internal health" % enemy.name
		)

	var hud := level.get_node_or_null("HUD")
	fixture.expect(
		hud != null and hud.call("is_presenting_health", 5, 5),
		"Checkpoint 1 retains the normal five-heart presentation"
	)


func get_level_enemies(level: CampaignLevel) -> Array[Node]:
	var enemies: Array[Node] = []
	for node in get_nodes_in_group("enemies"):
		if (
			node is Node
			and level.is_ancestor_of(node)
			and node.has_method("apply_debug_health_override")
		):
			enemies.append(node)
	return enemies


func verify_late_enemy_override(level: CampaignLevel) -> void:
	var enemy := WOLF_SCENE.instantiate()
	fixture.add_node(enemy, level.get_node("Enemies"))
	await fixture.process_frames(1)
	fixture.expect(enemy.is_node_ready(), "A later Enemy becomes ready in the active Level")
	fixture.expect(
		enemy.call("get_current_health") == 1,
		"A later compatible Enemy receives the 1-health override"
	)


func verify_campaign_progression(runner: Node, level_01: CampaignLevel) -> void:
	await advance_story_phase(level_01, "Level01 opening Story")
	var prologue := runner.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		prologue != null and prologue.get_campaign_id() == &"level_00",
		"Checkpoint 1 retains the Level00 prologue"
	)
	if prologue == null:
		return
	fixture.add_node(prologue)

	await advance_story_phase(prologue, "Level00 prologue Story")
	fixture.expect(
		runner.call("get_active_campaign_level") == level_01,
		"Level00 completion restores the same Level01"
	)
	var restored_player := level_01.get_node_or_null("Player")
	fixture.expect(
		restored_player != null and restored_player.call("get_current_health") == 999,
		"Restored Level01 retains the Player override"
	)

	level_01.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)
	fixture.expect(level_01.is_campaign_story_phase_active(), "Level01 starts its victory Story")
	await advance_story_phase(level_01, "Level01 victory Story")

	var level_02 := runner.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		level_02 != null and level_02.get_campaign_id() == &"level_02",
		"Level01 victory automatically progresses to Level02"
	)
	if level_02 != null:
		fixture.add_node(level_02)
		fixture.expect(level_02.is_campaign_story_phase_active(), "Level02 starts its opening Story")
		verify_debug_health_overrides(level_02)


func advance_story_phase(level: CampaignLevel, description: String) -> void:
	var finished := [false]
	level.campaign_story_phase_finished.connect(func() -> void: finished[0] = true)
	for _input_index in MAX_STORY_ADVANCE_INPUTS:
		if finished[0]:
			break
		var input := InputEventKey.new()
		input.keycode = KEY_ENTER
		input.pressed = true
		Input.parse_input_event(input)
		await fixture.process_frames(1)
	fixture.expect(finished[0], "%s completes through input" % description)


func instantiate_runner() -> Node:
	var scene := load(DEBUG_RUNNER_SCENE) as PackedScene
	fixture.expect(scene != null, "Debug Runner scene can be loaded")
	if scene == null:
		return null

	var runner := fixture.instantiate_scene(scene)
	fixture.set_current_scene(runner)
	return runner
