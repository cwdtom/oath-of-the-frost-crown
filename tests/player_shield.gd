extends SceneTree


const PLAYER_04_SCENE := preload("res://player/player_04.tscn")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	await test_available_shield_negates_one_damage_event()
	await test_shield_break_window_delays_cooldown_without_hurt()
	await test_shield_break_window_preserves_player_attack()
	await test_cooldown_damage_does_not_delay_shield_recovery()
	await test_existing_damage_rejection_preserves_available_shield()
	fixture.complete(false)
	await fixture.process_frames(3)
	await fixture.physics_frames(3)
	fixture.complete()


func test_available_shield_negates_one_damage_event() -> void:
	var player := fixture.instantiate_scene(PLAYER_04_SCENE) as DamageableActor
	fixture.expect(player != null, "Player 04 loads through its production damage seam")
	if player == null:
		return

	player.set_physics_process(false)
	await fixture.process_frames(1)
	var shield := player.get_node("VisualRoot/ShieldSkill/Shield") as Area2D
	fixture.expect(
		player.call("get_maximum_health") == 8,
		"Player 04 preserves Player 03's eight maximum health"
	)
	fixture.expect(shield.visible, "Player Shield begins the Level instance available")

	player.take_damage(player.call("get_maximum_health"), Vector2.RIGHT)
	fixture.expect(
		player.call("get_current_health") == player.call("get_maximum_health"),
		"Available Player Shield negates one otherwise applicable damage event"
	)
	fixture.expect(
		shield.visible,
		"Spent Player Shield remains visible during the Player Shield Break Window"
	)


func test_shield_break_window_delays_cooldown_without_hurt() -> void:
	var player := fixture.instantiate_scene(PLAYER_04_SCENE) as DamageableActor
	fixture.expect(player != null, "Player 04 loads for its Shield Break Window")
	if player == null:
		return

	player.set_physics_process(false)
	await fixture.process_frames(1)
	var shield := player.get_node("VisualRoot/ShieldSkill/Shield") as Area2D
	var cooldown := player.get_node("VisualRoot/ShieldSkill/Cooldown") as Timer
	var shield_animation_player := shield.get_node("AnimationPlayer") as AnimationPlayer
	var break_duration := shield_animation_player.get_animation("break").length
	var initial_state := int(player.get("state"))
	var hurt_event_count := [0]
	player.connect(&"hurt_taken", func() -> void: hurt_event_count[0] += 1)

	fixture.expect(
		is_equal_approx(cooldown.wait_time, 5.0) and cooldown.one_shot,
		"Player Shield uses its one-shot five second Cooldown"
	)
	player.take_damage(1, Vector2.RIGHT)
	await fixture.wait_seconds(0.15)
	var break_position_before_repeat := shield_animation_player.current_animation_position
	player.take_damage(1, Vector2.LEFT)
	await fixture.wait_seconds(0.05)
	fixture.expect(
		shield_animation_player.current_animation == &"break"
		and shield_animation_player.current_animation_position > break_position_before_repeat,
		"Repeated damage does not restart the Player Shield break presentation"
	)
	fixture.expect(
		player.call("get_current_health") == player.call("get_maximum_health"),
		"Player Shield Break Window rejects repeated damage"
	)
	fixture.expect(
		hurt_event_count[0] == 0 and int(player.get("state")) == initial_state,
		"Player Shield Break Window does not begin a hurt presentation"
	)
	fixture.expect(
		shield.visible and cooldown.is_stopped(),
		"Player Shield remains visible before its Cooldown begins"
	)

	await fixture.wait_seconds(break_duration + 0.1)
	fixture.expect(not shield.visible, "Player Shield hides after its Break Window")
	fixture.expect(
		not cooldown.is_stopped() and cooldown.time_left > 4.0,
		"Player Shield Cooldown begins after the Break Window"
	)


func test_shield_break_window_preserves_player_attack() -> void:
	var player := fixture.instantiate_scene(PLAYER_04_SCENE) as DamageableActor
	fixture.expect(player != null, "Player 04 loads for attack continuity")
	if player == null:
		return

	await fixture.process_frames(1)
	Input.action_press(&"attack")
	await fixture.physics_frames(2)
	Input.action_release(&"attack")
	await fixture.physics_frames(1)
	var animation_state := player.get_node("AnimationTree").get(
		"parameters/playback"
	) as AnimationNodeStateMachinePlayback
	fixture.expect(
		animation_state.get_current_node() == &"attack",
		"Player begins attacking before its Shield breaks"
	)

	player.take_damage(1, Vector2.ZERO)
	await fixture.wait_seconds(0.15)
	var shield_animation_player := player.get_node(
		"VisualRoot/ShieldSkill/Shield/AnimationPlayer"
	) as AnimationPlayer
	fixture.expect(
		animation_state.get_current_node() == &"attack"
		and bool(player.get("controls_enabled"))
		and shield_animation_player.current_animation == &"break",
		"Player Shield Break Window preserves attack and controls"
	)


func test_cooldown_damage_does_not_delay_shield_recovery() -> void:
	var player := fixture.instantiate_scene(PLAYER_04_SCENE) as DamageableActor
	fixture.expect(player != null, "Player 04 loads for its Shield Cooldown")
	if player == null:
		return

	player.set_physics_process(false)
	await fixture.process_frames(1)
	var shield := player.get_node("VisualRoot/ShieldSkill/Shield") as Area2D
	var cooldown := player.get_node("VisualRoot/ShieldSkill/Cooldown") as Timer
	var shield_animation_player := shield.get_node("AnimationPlayer") as AnimationPlayer
	var break_duration := shield_animation_player.get_animation("break").length
	var player_animation_player := player.get_node("AnimationPlayer") as AnimationPlayer
	var hurt_duration := player_animation_player.get_animation("hurt").length
	var maximum_health := int(player.call("get_maximum_health"))
	fixture.expect(
		is_equal_approx(cooldown.wait_time, 5.0),
		"Player Shield keeps its production five second Cooldown"
	)
	cooldown.wait_time = 2.2

	player.take_damage(1, Vector2.ZERO)
	await fixture.wait_seconds(break_duration + 0.1)
	fixture.expect(not shield.visible, "Spent Player Shield is unavailable during Cooldown")

	player.take_damage(1, Vector2.ZERO)
	fixture.expect(
		player.call("get_current_health") == maximum_health - 1,
		"Player takes normal damage during Player Shield Cooldown"
	)
	await fixture.wait_seconds(hurt_duration + 0.1)
	player.take_damage(1, Vector2.ZERO)
	fixture.expect(
		player.call("get_current_health") == maximum_health - 2,
		"Later Cooldown damage is accepted after ordinary hurt immunity"
	)

	await fixture.wait_seconds(cooldown.time_left + 0.1)
	fixture.expect(
		shield.visible and shield_animation_player.current_animation == &"idle",
		"Player Shield becomes available in its idle presentation when Cooldown ends"
	)
	await fixture.wait_seconds(break_duration + 0.1)
	player.take_damage(1, Vector2.ZERO)
	fixture.expect(
		player.call("get_current_health") == maximum_health - 2,
		"Recovered Player Shield negates the next damage event"
	)
	await fixture.wait_seconds(break_duration + 0.1)


func test_existing_damage_rejection_preserves_available_shield() -> void:
	var player := fixture.instantiate_scene(PLAYER_04_SCENE) as DamageableActor
	fixture.expect(player != null, "Player 04 loads for damage rejection priority")
	if player == null:
		return

	player.set_physics_process(false)
	await fixture.process_frames(1)
	var shield := player.get_node("VisualRoot/ShieldSkill/Shield") as Area2D
	var cooldown := player.get_node("VisualRoot/ShieldSkill/Cooldown") as Timer
	var shield_animation_player := shield.get_node("AnimationPlayer") as AnimationPlayer
	var break_duration := shield_animation_player.get_animation("break").length
	var player_animation_player := player.get_node("AnimationPlayer") as AnimationPlayer
	var hurt_duration := player_animation_player.get_animation("hurt").length
	var maximum_health := int(player.call("get_maximum_health"))

	player.call("set_damage_immune", true)
	player.take_damage(1, Vector2.ZERO)
	player.call("set_damage_immune", false)
	player.take_damage(0, Vector2.ZERO)
	fixture.expect(
		shield.visible and cooldown.is_stopped(),
		"Global immunity and invalid damage preserve the available Player Shield"
	)

	cooldown.wait_time = 0.2
	player.take_damage(1, Vector2.ZERO)
	await fixture.wait_seconds(break_duration + 0.1)
	player.take_damage(1, Vector2.ZERO)
	fixture.expect(
		player.call("get_current_health") == maximum_health - 1,
		"Player takes ordinary damage while Player Shield is unavailable"
	)
	await fixture.wait_seconds(0.3)
	fixture.expect(
		shield.visible and bool(player.call("is_hurt_immune")),
		"Player Shield can recover during ordinary hurt immunity"
	)

	player.take_damage(1, Vector2.ZERO)
	await fixture.wait_seconds(hurt_duration + 0.1)
	fixture.expect(
		shield.visible and cooldown.is_stopped(),
		"Ordinary hurt immunity rejects damage before the recovered Shield"
	)
	player.take_damage(1, Vector2.ZERO)
	fixture.expect(
		player.call("get_current_health") == maximum_health - 1,
		"Preserved Player Shield negates damage after ordinary immunity ends"
	)
	await fixture.wait_seconds(break_duration + 0.1)
