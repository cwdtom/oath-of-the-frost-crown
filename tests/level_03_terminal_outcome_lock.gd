extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const LEVEL_03_SCENE := preload("res://levels/level_03.tscn")
const MAIN_SCENE := preload("res://main.tscn")
const RESULT_DEAD := "DEAD"
const TERMINAL_OUTCOME_NONE := &"none"
const TERMINAL_OUTCOME_PLAYER_DEFEAT := &"player_defeat"
const TERMINAL_OUTCOME_ELK_KING_DEFEAT := &"elk_king_defeat"

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	await test_elk_king_defeat_first_locks_level_03()
	await test_player_defeat_first_remains_authoritative()
	await test_committed_elk_king_effects_finish_without_player_damage()

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func test_elk_king_defeat_first_locks_level_03() -> void:
	var main := await start_level_03()
	var level := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(level != null, "Main starts the production Level 03 scene")
	if level == null:
		return
	fixture.add_node(level)

	var player := level.get_node("Player")
	var elk_king := level.get_node("Enemies/ElkKing")
	var result_interface := main.get_node("GameResultPopup")
	var campaign_outcomes: Array[StringName] = []
	var elk_king_defeat_notifications := [0]
	level.campaign_outcome_reached.connect(
		func(outcome: StringName) -> void: campaign_outcomes.append(outcome)
	)
	elk_king.connect(
		"died",
		func() -> void: elk_king_defeat_notifications[0] += 1
	)

	fixture.expect(
		get_terminal_outcome(level) == TERMINAL_OUTCOME_NONE,
		"Level 03 starts without a locked terminal outcome"
	)
	var starting_player_health: int = player.call("get_current_health")
	await deplete_elk_king(elk_king)

	fixture.expect(
		elk_king.call("get_current_health") == 0,
		"Elk King health depletion is confirmed through the production actor"
	)
	fixture.expect(
		elk_king_defeat_notifications[0] == 1,
		"Level 03 observes one immediate Elk King died notification"
	)
	fixture.expect(
		get_terminal_outcome(level) == TERMINAL_OUTCOME_ELK_KING_DEFEAT,
		"Elk King Defeat first locks the Level 03 terminal outcome"
	)
	fixture.expect(not level.is_campaign_hud_visible(), "Elk King Defeat hides the HUD")
	fixture.expect(
		not level.is_campaign_control_available(),
		"Elk King Defeat disables Player controls"
	)
	player.call("take_damage", 1, Vector2.ZERO)
	fixture.expect(
		player.call("get_current_health") == starting_player_health,
		"A late hit after Elk King Defeat cannot reduce Player health"
	)
	fixture.expect(
		campaign_outcomes.is_empty(),
		"Elk King Defeat and a late hit emit no campaign outcome"
	)
	fixture.expect(
		not bool(result_interface.call("is_result_visible")),
		"Elk King Defeat and a late hit show no result popup"
	)

	elk_king.emit_signal("died")
	player.emit_signal("died")
	await fixture.process_frames(2)
	fixture.expect(
		get_terminal_outcome(level) == TERMINAL_OUTCOME_ELK_KING_DEFEAT,
		"Repeated terminal notifications cannot replace Elk King Defeat"
	)
	fixture.expect(
		campaign_outcomes.is_empty(),
		"Repeated terminal notifications emit no later campaign outcome"
	)
	fixture.expect(
		not bool(result_interface.call("is_result_visible")),
		"Repeated terminal notifications show no later loss result"
	)
	fixture.expect(
		main.call("get_active_campaign_level") == level and is_instance_valid(level),
		"Elk King Defeat keeps the production Level 03 session alive"
	)
	await retire_main(main)


func test_player_defeat_first_remains_authoritative() -> void:
	var main := await start_level_03()
	var level := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(level != null, "Main starts Level 03 for the Player-first outcome")
	if level == null:
		return
	fixture.add_node(level)

	var player := level.get_node("Player")
	var elk_king := level.get_node("Enemies/ElkKing")
	var result_interface := main.get_node("GameResultPopup")
	var campaign_outcomes: Array[StringName] = []
	var elk_king_defeat_notifications := [0]
	level.campaign_outcome_reached.connect(
		func(outcome: StringName) -> void: campaign_outcomes.append(outcome)
	)
	elk_king.connect(
		"died",
		func() -> void: elk_king_defeat_notifications[0] += 1
	)

	player.call("take_damage", player.call("get_maximum_health"), Vector2.ZERO)
	await deplete_elk_king(elk_king)

	fixture.expect(
		player.call("get_current_health") == 0,
		"Player health depletion is confirmed first through the production actor"
	)
	fixture.expect(
		elk_king.call("get_current_health") == 0
		and elk_king_defeat_notifications[0] == 1,
		"Later Elk King health depletion still publishes one died notification"
	)
	fixture.expect(
		get_terminal_outcome(level) == TERMINAL_OUTCOME_PLAYER_DEFEAT,
		"Player Defeat first remains the locked Level 03 terminal outcome"
	)
	fixture.expect(
		campaign_outcomes == [CampaignLevel.OUTCOME_DEFEAT],
		"Player Defeat first emits exactly one campaign defeat"
	)
	fixture.expect(
		bool(result_interface.call("is_result_visible"))
		and str(result_interface.call("get_result_text")) == RESULT_DEAD,
		"Player Defeat first keeps the existing DEAD result authoritative"
	)
	fixture.expect(
		level.is_campaign_hud_visible(),
		"A later Elk King Defeat does not begin HUD staging"
	)
	elk_king.emit_signal("died")
	player.emit_signal("died")
	await fixture.process_frames(2)
	fixture.expect(
		get_terminal_outcome(level) == TERMINAL_OUTCOME_PLAYER_DEFEAT,
		"Repeated terminal notifications cannot replace Player Defeat"
	)
	fixture.expect(
		campaign_outcomes == [CampaignLevel.OUTCOME_DEFEAT],
		"Repeated terminal notifications cannot duplicate Player Defeat"
	)
	fixture.expect(
		bool(result_interface.call("is_result_visible"))
		and str(result_interface.call("get_result_text")) == RESULT_DEAD,
		"Repeated terminal notifications keep the existing loss result"
	)
	fixture.expect(
		main.call("get_active_campaign_level") == level and is_instance_valid(level),
		"Player Defeat and later Elk King Defeat keep the current Level until retry"
	)
	await retire_main(main)


func test_committed_elk_king_effects_finish_without_player_damage() -> void:
	var main := await start_level_03()
	var level := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(level != null, "Main starts Level 03 for committed Elk King effects")
	if level == null:
		return
	fixture.add_node(level)

	var player := level.get_node("Player")
	var elk_king := level.get_node("Enemies/ElkKing")
	var result_interface := main.get_node("GameResultPopup")
	var detector_shape := elk_king.get_node(
		"SkillDetect/CollisionShape2D"
	) as CollisionShape2D
	var thunder_animation := elk_king.get_node(
		"SkillDetect/ThunderSkill/Thunder/AnimationPlayer"
	) as AnimationPlayer
	var earthquake_animation := elk_king.get_node(
		"SkillDetect/EarthquakeSkill/Earthquake/AnimationPlayer"
	) as AnimationPlayer
	var campaign_outcomes: Array[StringName] = []
	level.campaign_outcome_reached.connect(
		func(outcome: StringName) -> void: campaign_outcomes.append(outcome)
	)

	player.global_position = detector_shape.global_position
	await fixture.physics_frames(3)
	await fixture.process_frames(2)
	fixture.expect(
		thunder_animation.is_playing()
		and thunder_animation.current_animation == &"cast",
		"Level 03 commits the Elk King's thunder presentation before Defeat"
	)
	fixture.expect(
		earthquake_animation.is_playing()
		and earthquake_animation.current_animation == &"cast",
		"Level 03 commits the Elk King's earthquake presentation before Defeat"
	)

	var locked_player_health: int = player.call("get_current_health")
	await deplete_elk_king(elk_king)
	player.call("take_damage", 1, Vector2.ZERO)

	fixture.expect(
		thunder_animation.is_playing() and earthquake_animation.is_playing(),
		"Committed thunder and earthquake remain visible after Elk King Defeat"
	)
	fixture.expect(
		player.call("get_current_health") == locked_player_health,
		"Player health remains unchanged after Elk King Defeat"
	)

	var remaining_presentation_time := maxf(
		thunder_animation.get_animation(&"cast").length
			- thunder_animation.current_animation_position,
		earthquake_animation.get_animation(&"cast").length
			- earthquake_animation.current_animation_position
	)
	await fixture.wait_seconds(remaining_presentation_time + 0.15)
	fixture.expect(
		not thunder_animation.is_playing() and not earthquake_animation.is_playing(),
		"Committed thunder and earthquake presentations finish normally"
	)
	fixture.expect(
		player.call("get_current_health") == locked_player_health,
		"Finishing committed Elk King effects cannot reduce Player health"
	)
	fixture.expect(
		campaign_outcomes.is_empty()
		and not bool(result_interface.call("is_result_visible")),
		"Committed effects after Elk King Defeat produce no campaign result"
	)
	fixture.expect(
		main.call("get_active_campaign_level") == level and is_instance_valid(level),
		"Committed effects finishing do not replace or dispose Level 03"
	)
	await retire_main(main)


func deplete_elk_king(elk_king: CharacterBody2D) -> void:
	var shield_animation_player := elk_king.get_node(
		"ShieldSkill/Shield/AnimationPlayer"
	) as AnimationPlayer
	elk_king.call("take_damage", 1, Vector2.ZERO)
	await fixture.wait_seconds(
		shield_animation_player.get_animation("break").length + 0.1
	)
	elk_king.call("take_damage", elk_king.call("get_maximum_health"), Vector2.ZERO)


func get_terminal_outcome(level: CampaignLevel) -> StringName:
	if not level.has_method("get_terminal_outcome"):
		return &"missing"
	return level.call("get_terminal_outcome") as StringName


func start_level_03() -> Node:
	var main := fixture.instantiate_scene(MAIN_SCENE)
	fixture.set_current_scene(main)
	await fixture.process_frames(1)
	main.call("start_level", LEVEL_03_SCENE, false)
	await fixture.process_frames(2)
	return main


func retire_main(main: Node) -> void:
	fixture.set_current_scene(null)
	main.queue_free()
	fixture.set_paused(false)
	await fixture.process_frames(2)
