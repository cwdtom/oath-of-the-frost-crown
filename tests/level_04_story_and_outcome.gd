extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const LEVEL_04_SCENE := preload("res://levels/level_04.tscn")
const MAIN_SCENE := preload("res://main.tscn")
const AWAKENING_DISTANCE := 600.0
const DEAD_DURATION := 0.9
const MAX_STORY_ADVANCE_INPUTS := 64
const TERMINAL_OUTCOME_PLAYER_DEFEAT := &"player_defeat"
const TERMINAL_OUTCOME_VALDEMAR_DEFEAT := &"valdemar_defeat"

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	await test_pre_awakening_story_blocks_transformation()
	await test_retry_skips_pre_awakening_story()
	await test_valdemar_defeat_plays_victory_story_after_death_motion()
	await test_player_defeat_first_remains_authoritative()

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func test_pre_awakening_story_blocks_transformation() -> void:
	var level := LEVEL_04_SCENE.instantiate() as CampaignLevel
	level.prepare_for_campaign(false)
	fixture.add_node(level)
	fixture.set_current_scene(level)
	await fixture.process_frames(2)
	fixture.set_paused(false)

	var player := level.get_node("Player") as DamageableActor
	var valdemar := level.get_node("Enemies/Valdemar") as DamageableActor
	var animation_tree := valdemar.get_node("AnimationTree") as AnimationTree
	var animation_state := animation_tree.get(
		"parameters/playback"
	) as AnimationNodeStateMachinePlayback
	await enter_valdemar_awakening_boundary(player, valdemar)

	fixture.expect(
		level.is_campaign_story_phase_active(),
		"Entering Valdemar's boundary starts the Pre-Awakening Story"
	)
	fixture.expect(paused, "The Pre-Awakening Story pauses Level 04")
	fixture.expect(
		not level.is_campaign_control_available(),
		"The Pre-Awakening Story keeps Player controls unavailable"
	)
	fixture.expect(
		not level.is_campaign_hud_visible(),
		"The Pre-Awakening Story hides the HUD"
	)
	fixture.expect(
		animation_state.get_current_node() != &"transformation",
		"Valdemar does not transform before the Pre-Awakening Story finishes"
	)

	await advance_story_phase(level)
	fixture.expect(
		not level.is_campaign_story_phase_active() and not paused,
		"Finishing the Pre-Awakening Story resumes Level 04"
	)
	fixture.expect(
		level.is_campaign_control_available() and level.is_campaign_hud_visible(),
		"Finishing the Pre-Awakening Story restores gameplay presentation"
	)
	await fixture.physics_frames(1)
	fixture.expect(
		animation_state.get_current_node() == &"transformation",
		"Finishing the Pre-Awakening Story immediately starts Valdemar Awakening"
	)

	fixture.set_current_scene(null)
	level.queue_free()
	fixture.set_paused(false)
	await fixture.process_frames(2)


func test_retry_skips_pre_awakening_story() -> void:
	var main := fixture.instantiate_scene(MAIN_SCENE)
	fixture.set_current_scene(main)
	await fixture.process_frames(1)
	main.call("start_level", LEVEL_04_SCENE, false)
	await fixture.process_frames(2)

	var defeated_level := main.call("get_active_campaign_level") as CampaignLevel
	defeated_level.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_DEFEAT)
	var result_interface := main.get_node("GameResultPopup")
	result_interface.emit_signal("retry_requested")
	await fixture.process_frames(2)

	var retry_level := main.call("get_active_campaign_level") as CampaignLevel
	var player := retry_level.get_node("Player") as DamageableActor
	var valdemar := retry_level.get_node("Enemies/Valdemar") as DamageableActor
	var animation_tree := valdemar.get_node("AnimationTree") as AnimationTree
	var animation_state := animation_tree.get(
		"parameters/playback"
	) as AnimationNodeStateMachinePlayback
	await enter_valdemar_awakening_boundary(player, valdemar)

	fixture.expect(
		not retry_level.is_campaign_story_phase_active() and not paused,
		"Level 04 retry skips the Pre-Awakening Story"
	)
	fixture.expect(
		animation_state.get_current_node() == &"transformation",
		"Entering Valdemar's boundary on retry directly starts Awakening"
	)

	fixture.set_current_scene(null)
	main.queue_free()
	fixture.set_paused(false)
	await fixture.process_frames(2)


func test_valdemar_defeat_plays_victory_story_after_death_motion() -> void:
	var main := fixture.instantiate_scene(MAIN_SCENE)
	fixture.set_current_scene(main)
	await fixture.process_frames(1)
	main.call("start_level", LEVEL_04_SCENE, false, false)
	await fixture.process_frames(2)

	var level := main.call("get_active_campaign_level") as CampaignLevel
	var player := level.get_node("Player") as DamageableActor
	var valdemar := level.get_node("Enemies/Valdemar") as DamageableActor
	await enter_valdemar_awakening_boundary(player, valdemar)
	await fixture.wait_seconds(1.0)
	await fixture.physics_frames(2)

	var campaign_outcomes: Array[StringName] = []
	level.campaign_outcome_reached.connect(
		func(outcome: StringName) -> void: campaign_outcomes.append(outcome)
	)
	valdemar.call("apply_debug_health_override", 1)
	var locked_player_health: int = player.call("get_current_health")
	var player_shield := player.get_node("VisualRoot/ShieldSkill/Shield") as CanvasItem
	valdemar.call("take_damage", 1, Vector2.ZERO)
	player.call("take_damage", 1, Vector2.ZERO)

	fixture.expect(
		level.has_method("get_terminal_outcome")
		and level.call("get_terminal_outcome") == TERMINAL_OUTCOME_VALDEMAR_DEFEAT,
		"Valdemar health depletion first locks the Level 04 victory outcome"
	)
	fixture.expect(
		not level.is_campaign_hud_visible()
		and not level.is_campaign_control_available(),
		"Valdemar Defeat immediately hides the HUD and disables controls"
	)
	fixture.expect(
		player.call("get_current_health") == locked_player_health
		and player_shield.visible,
		"Valdemar Defeat immediately grants terminal Player damage immunity"
	)
	fixture.expect(
		campaign_outcomes.is_empty() and not level.is_campaign_story_phase_active(),
		"Valdemar Defeat waits for the complete death motion before Level Completion"
	)

	await fixture.wait_seconds(DEAD_DURATION + 0.1)
	await fixture.process_frames(2)
	var victory_story := level.get_node_or_null("VictoryStory")
	fixture.expect(
		campaign_outcomes == [CampaignLevel.OUTCOME_COMPLETION],
		"Valdemar's retained Dying presentation completes Level 04 exactly once"
	)
	fixture.expect(
		level.is_campaign_story_phase_active()
		and paused
		and victory_story != null
		and victory_story.get("story_path") == "res://levels/level_04_b_story.json",
		"Level 04 Completion starts lv_4_b as its Victory Story"
	)
	valdemar.emit_signal("died")
	await fixture.process_frames(2)
	fixture.expect(
		campaign_outcomes == [CampaignLevel.OUTCOME_COMPLETION]
		and level.get_node_or_null("VictoryStory") == victory_story,
		"A repeated Valdemar died signal cannot duplicate completion or lv_4_b"
	)

	await advance_story_phase(level)
	fixture.expect(
		main.call("get_active_campaign_level") == level
		and not level.is_campaign_story_phase_active()
		and not paused,
		"Finishing lv_4_b retains the active Level 04 session"
	)
	fixture.expect(
		not level.is_campaign_hud_visible()
		and not level.is_campaign_control_available()
		and not bool(main.call("is_campaign_result_visible")),
		"Finishing lv_4_b holds the Final Tableau without controls or a result popup"
	)
	fixture.expect(
		bool(valdemar.get_node("Dying").visible),
		"The Level 04 Final Tableau retains Valdemar's Dying presentation"
	)

	fixture.set_current_scene(null)
	main.queue_free()
	fixture.set_paused(false)
	await fixture.process_frames(2)


func test_player_defeat_first_remains_authoritative() -> void:
	var main := fixture.instantiate_scene(MAIN_SCENE)
	fixture.set_current_scene(main)
	await fixture.process_frames(1)
	main.call("start_level", LEVEL_04_SCENE, false, false)
	await fixture.process_frames(2)

	var level := main.call("get_active_campaign_level") as CampaignLevel
	var player := level.get_node("Player") as DamageableActor
	var valdemar := level.get_node("Enemies/Valdemar") as DamageableActor
	await enter_valdemar_awakening_boundary(player, valdemar)
	await fixture.wait_seconds(1.0)
	await fixture.physics_frames(2)

	var campaign_outcomes: Array[StringName] = []
	level.campaign_outcome_reached.connect(
		func(outcome: StringName) -> void: campaign_outcomes.append(outcome)
	)
	(player.get_node("VisualRoot/ShieldSkill/Shield") as CanvasItem).hide()
	player.call("take_damage", player.call("get_maximum_health"), Vector2.ZERO)
	valdemar.call("apply_debug_health_override", 1)
	valdemar.call("take_damage", 1, Vector2.ZERO)
	await fixture.wait_seconds(DEAD_DURATION + 0.1)
	await fixture.process_frames(2)

	fixture.expect(
		level.call("get_terminal_outcome") == TERMINAL_OUTCOME_PLAYER_DEFEAT,
		"Player health depletion first remains Level 04's terminal outcome"
	)
	fixture.expect(
		campaign_outcomes == [CampaignLevel.OUTCOME_DEFEAT],
		"Player Defeat first emits one campaign defeat without later completion"
	)
	fixture.expect(
		bool(main.call("is_campaign_result_visible"))
		and not level.is_campaign_story_phase_active(),
		"Later Valdemar Defeat cannot replace the loss or start lv_4_b"
	)

	fixture.set_current_scene(null)
	main.queue_free()
	fixture.set_paused(false)
	await fixture.process_frames(2)


func enter_valdemar_awakening_boundary(
	player: DamageableActor,
	valdemar: DamageableActor
) -> void:
	player.global_position = (
		valdemar.global_position + Vector2(-AWAKENING_DISTANCE - 20.0, -5000.0)
	)
	await fixture.physics_frames(2)
	player.global_position.x = valdemar.global_position.x - AWAKENING_DISTANCE + 1.0
	await fixture.physics_frames(3)


func advance_story_phase(level: CampaignLevel) -> void:
	for _input_index in MAX_STORY_ADVANCE_INPUTS:
		if not level.is_campaign_story_phase_active():
			return
		var input := InputEventKey.new()
		input.keycode = KEY_ENTER
		input.pressed = true
		Input.parse_input_event(input)
		await fixture.process_frames(1)
