extends SceneTree


const WOLF_KING_SCENE := preload("res://enemies/wolf_king.tscn")
const EnemyHarness := preload("res://tests/enemy_scene_harness.gd")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const DEAD_ANIMATION := &"dead"
const RUN_ANIMATION := &"run"
const WARN_ANIMATION := &"warn"
const EXPECTED_HEALTH := 5
const SKILL_DISTANCE := 300.0
const SKILL_WARNING_DURATION := 0.7

var fixture: HeadlessGameplayFixture
var harness: EnemySceneHarness


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	fixture.set_project_setting("physics/2d/default_gravity", 0.0)
	var world := fixture.add_node(Node2D.new()) as Node2D
	fixture.set_current_scene(world)
	harness = EnemyHarness.new(fixture, world)

	await test_moving_skill_has_no_wolf_contact_damage()
	await test_warning_precedes_combined_release()
	await test_warning_commits_locked_release_through_departure_and_weapon_contact()
	await test_thunder_movement_delivery_and_cooldown()
	await test_hurt_does_not_cancel_pending_thunder()
	await test_death_cancels_thunder_during_paused_presentation()

	fixture.complete(false)
	await fixture.process_frames(2)
	fixture.complete()


func test_moving_skill_has_no_wolf_contact_damage() -> void:
	var start_position := Vector2(2500.0, 0.0)
	var hurt_event_count: Array[int] = [0]
	var player := harness.instantiate_passive_player(
		start_position + Vector2(-70.0, 0.0),
		func() -> void: hurt_event_count[0] += 1
	)
	var wolf_king := harness.instantiate_enemy(
		WOLF_KING_SCENE,
		start_position,
		{"idle_duration": 10.0}
	)

	await fixture.physics_frames(4)
	fixture.expect(
		hurt_event_count[0] == 0,
		"WolfKing movement does not inherit Wolf contact damage"
	)

	wolf_king.queue_free()
	player.queue_free()
	await fixture.process_frames(1)


func test_warning_precedes_combined_release() -> void:
	var start_position := Vector2(3000.0, 0.0)
	var player := harness.instantiate_passive_player(
		start_position + Vector2(-150.0, 0.0),
		func() -> void: pass
	)
	var wolf_king := harness.instantiate_enemy(
		WOLF_KING_SCENE,
		start_position,
		{"idle_duration": 10.0}
	)
	var warning := wolf_king.get_node("WarnMark") as Node2D
	var thunder_animation_player := wolf_king.get_node(
		"Thunder/AnimationPlayer"
	) as AnimationPlayer

	await fixture.physics_frames(3)
	fixture.expect(
		warning.visible
		and wolf_king.global_position.is_equal_approx(start_position)
		and harness.is_playing(wolf_king, WARN_ANIMATION)
		and not thunder_animation_player.is_playing(),
		"Ready Wolf King starts a stationary warning before movement or thunder"
	)
	await fixture.wait_seconds(SKILL_WARNING_DURATION - 0.1)
	fixture.expect(
		warning.visible
		and wolf_king.global_position.is_equal_approx(start_position)
		and not thunder_animation_player.is_playing(),
		"Wolf King warning remains visible and harmless for its full duration"
	)
	await fixture.wait_seconds(0.15)
	await fixture.physics_frames(2)
	fixture.expect(
		not warning.visible
		and wolf_king.global_position.x < start_position.x
		and harness.is_playing(wolf_king, RUN_ANIMATION)
		and thunder_animation_player.is_playing(),
		(
			"Wolf King movement and thunder begin together after its warning; "
			+ "visible=%s position=%s run=%s thunder=%s"
			% [
				warning.visible,
				wolf_king.global_position,
				harness.is_playing(wolf_king, RUN_ANIMATION),
				thunder_animation_player.is_playing(),
			]
		)
	)

	wolf_king.queue_free()
	player.queue_free()
	await fixture.process_frames(1)


func test_warning_commits_locked_release_through_departure_and_weapon_contact() -> void:
	var start_position := Vector2(4000.0, 0.0)
	var player := harness.instantiate_passive_player(
		start_position + Vector2(-150.0, 0.0),
		func() -> void: pass
	)
	var wolf_king := harness.instantiate_enemy(
		WOLF_KING_SCENE,
		start_position,
		{"idle_duration": 10.0}
	)
	var warning := wolf_king.get_node("WarnMark") as Node2D
	var thunder_animation_player := wolf_king.get_node(
		"Thunder/AnimationPlayer"
	) as AnimationPlayer

	await fixture.physics_frames(3)
	var health_before_warning: int = wolf_king.call("get_current_health")
	player.global_position = start_position + Vector2(900.0, 0.0)
	var weapon := harness.add_weapon(wolf_king.global_position)
	await fixture.physics_frames(3)
	weapon.queue_free()
	fixture.expect(
		warning.visible
		and wolf_king.global_position.is_equal_approx(start_position)
		and wolf_king.call("get_current_health") == health_before_warning,
		"Wolf King warning continues without damage after Player departure and weapon contact"
	)

	await fixture.wait_seconds(SKILL_WARNING_DURATION)
	await fixture.physics_frames(2)
	var thunder := wolf_king.get_node("Thunder") as Area2D
	fixture.expect(
		wolf_king.global_position.x < start_position.x
		and thunder.global_position.x < start_position.x - 400.0
		and thunder_animation_player.is_playing(),
		"Wolf King movement and thunder keep the release side locked at warning onset"
	)

	wolf_king.queue_free()
	player.queue_free()
	await fixture.process_frames(1)


func test_thunder_movement_delivery_and_cooldown() -> void:
	var start_position := Vector2(3500.0, 0.0)
	var floor_body := harness.add_environment_wall(
		start_position + Vector2(0.0, 300.0),
		Vector2(2000.0, 20.0)
	)
	var hurt_event_count: Array[int] = [0]
	var player := harness.instantiate_passive_player(
		start_position + Vector2(900.0, 0.0),
		func() -> void: hurt_event_count[0] += 1
	)
	var detector_body := harness.add_body(start_position + Vector2(-150.0, 0.0))
	var wolf_king := harness.instantiate_enemy(
		WOLF_KING_SCENE,
		start_position,
		{"idle_duration": 10.0}
	)
	var warning := wolf_king.get_node("WarnMark") as Node2D

	await fixture.wait_seconds(SKILL_WARNING_DURATION + 0.05)
	await fixture.physics_frames(3)
	await fixture.process_frames(1)
	var thunder_area := find_top_level_area(wolf_king)
	fixture.expect(
		thunder_area != null
		and thunder_area.global_position.x < start_position.x - 400.0
		and thunder_area.global_position.x >= start_position.x - 750.0,
		"Wolf King selects thunder on its warning-locked left side"
	)
	fixture.expect(
		thunder_area != null and is_equal_approx(thunder_area.global_position.y, 35.0),
		"WolfKing grounds thunder against environment physics"
	)
	fixture.expect(
		harness.is_playing(wolf_king, RUN_ANIMATION),
		"WolfKing moves with its run presentation"
	)

	detector_body.queue_free()
	var weapon := harness.add_weapon(wolf_king.global_position, Vector2(200.0, 200.0))
	await fixture.physics_frames(2)
	weapon.queue_free()
	fixture.expect(
		wolf_king.get_current_health() == EXPECTED_HEALTH,
		"WolfKing moving skill rejects weapon damage"
	)

	var speed_sample_x := wolf_king.global_position.x
	await fixture.physics_frames(6)
	fixture.expect(
		absf(wolf_king.global_position.x - speed_sample_x + 60.0) <= 1.0,
		"WolfKing keeps its 600 pixel per second skill speed"
	)
	var repeated_detector := harness.add_body(wolf_king.global_position + Vector2(-150.0, 0.0))
	await fixture.physics_frames(2)
	repeated_detector.queue_free()

	if thunder_area != null:
		player.global_position = thunder_area.global_position + Vector2(20.0, 0.0)
	var player_impact_x := player.global_position.x
	await fixture.wait_seconds(0.9)
	await fixture.physics_frames(1)
	fixture.expect(
		hurt_event_count[0] == 1,
		"One WolfKing thunder cast damages Player no more than once"
	)
	fixture.expect(
		player.global_position.x > player_impact_x + 90.0,
		"Thunder keeps its Player knockback"
	)
	fixture.expect(
		is_equal_approx(wolf_king.global_position.x, start_position.x - SKILL_DISTANCE),
		"Repeated detection cannot restart WolfKing's 300 pixel moving skill"
	)
	await fixture.wait_seconds(0.7)
	fixture.expect(hurt_event_count[0] == 1, "Completed thunder does not damage Player again")

	var skill_end_x := wolf_king.global_position.x
	var cooldown_detector := harness.add_body(wolf_king.global_position + Vector2(-150.0, 0.0))
	await fixture.physics_frames(3)
	cooldown_detector.queue_free()
	fixture.expect(
		is_equal_approx(wolf_king.global_position.x, skill_end_x),
		"WolfKing cannot restart its skill during cooldown"
	)
	await fixture.wait_seconds(1.25)
	var ready_detector := harness.add_body(wolf_king.global_position + Vector2(-150.0, 0.0))
	await fixture.physics_frames(3)
	fixture.expect(
		warning.visible and is_equal_approx(wolf_king.global_position.x, skill_end_x),
		"Wolf King starts its next warning after the three-second release cooldown"
	)
	await fixture.wait_seconds(SKILL_WARNING_DURATION + 0.05)
	await fixture.physics_frames(3)
	fixture.expect(
		wolf_king.global_position.x < skill_end_x,
		"Wolf King releases its next skill after the next complete warning"
	)

	wolf_king.queue_free()
	player.queue_free()
	ready_detector.queue_free()
	floor_body.queue_free()
	await fixture.process_frames(1)


func test_hurt_does_not_cancel_pending_thunder() -> void:
	var start_position := Vector2(5500.0, 0.0)
	var floor_body := harness.add_environment_wall(
		start_position + Vector2(0.0, 300.0),
		Vector2(2000.0, 20.0)
	)
	var hurt_event_count: Array[int] = [0]
	var player := harness.instantiate_passive_player(
		start_position + Vector2(900.0, 0.0),
		func() -> void: hurt_event_count[0] += 1
	)
	var detector_body := harness.add_body(start_position + Vector2(-150.0, 0.0))
	var wolf_king := harness.instantiate_enemy(
		WOLF_KING_SCENE,
		start_position,
		{"idle_duration": 10.0}
	)

	await fixture.wait_seconds(SKILL_WARNING_DURATION + 0.05)
	await fixture.physics_frames(3)
	await fixture.process_frames(1)
	var thunder_area := find_top_level_area(wolf_king)
	detector_body.queue_free()
	await fixture.wait_seconds(0.55)
	if thunder_area != null:
		player.global_position = thunder_area.global_position + Vector2(20.0, 0.0)

	await harness.deliver_hit(wolf_king, Vector2(-50.0, 0.0))
	fixture.expect(
		wolf_king.get_current_health() == EXPECTED_HEALTH - 1,
		"Weapon contact damages WolfKing during thunder delivery"
	)
	fixture.expect(
		not harness.enemy_sprite_is_flipped(wolf_king),
		"Hurt Wolf King faces Player on its left"
	)
	await fixture.wait_seconds(0.5)
	fixture.expect(hurt_event_count[0] == 1, "Accepted damage does not cancel pending WolfKing thunder")

	wolf_king.queue_free()
	player.queue_free()
	floor_body.queue_free()
	await fixture.process_frames(1)


func test_death_cancels_thunder_during_paused_presentation() -> void:
	var start_position := Vector2(7500.0, 0.0)
	var floor_body := harness.add_environment_wall(
		start_position + Vector2(0.0, 300.0),
		Vector2(2000.0, 20.0)
	)
	var delayed_hurt_count: Array[int] = [0]
	var player := harness.instantiate_passive_player(
		start_position + Vector2(900.0, 0.0),
		func() -> void: delayed_hurt_count[0] += 1
	)
	var wolf_king := harness.instantiate_enemy(
		WOLF_KING_SCENE,
		start_position,
		{"idle_duration": 10.0, "patrol_range": 1000.0}
	)
	for hit_index in EXPECTED_HEALTH - 1:
		await harness.deliver_hit(wolf_king)
		if hit_index < EXPECTED_HEALTH - 2:
			await fixture.wait_seconds(1.05)

	fixture.expect(wolf_king.get_current_health() == 1, "WolfKing reaches one remaining health")
	await fixture.wait_seconds(1.05)
	var detector_offset := 150.0 if harness.enemy_sprite_is_flipped(wolf_king) else -150.0
	var detector_body := harness.add_body(wolf_king.global_position + Vector2(detector_offset, 0.0))
	await fixture.physics_frames(3)
	await fixture.wait_seconds(SKILL_WARNING_DURATION + 0.05)
	await fixture.physics_frames(2)
	await fixture.process_frames(1)
	var thunder_area := find_top_level_area(wolf_king)
	detector_body.queue_free()
	await fixture.wait_seconds(0.55)
	if thunder_area != null:
		player.global_position = thunder_area.global_position + Vector2(20.0, 0.0)

	wolf_king.connect(
		&"died",
		func() -> void:
			fixture.set_paused(true)
	)
	var first_weapon := harness.add_weapon(wolf_king.global_position + Vector2(-40.0, 0.0))
	var second_weapon := harness.add_weapon(wolf_king.global_position + Vector2(40.0, 0.0))
	await fixture.physics_frames(3)
	await fixture.process_frames(1)
	first_weapon.queue_free()
	second_weapon.queue_free()

	fixture.expect(wolf_king.is_health_depleted(), "Lethal weapon delivery depletes WolfKing")

	await fixture.wait_seconds(0.75)
	fixture.expect(delayed_hurt_count[0] == 0, "Death cancels pending WolfKing thunder")
	fixture.expect(
		harness.animation_position(wolf_king, DEAD_ANIMATION) >= 0.7,
		"WolfKing death presentation advances while Story-style pause is active"
	)

	wolf_king.queue_free()
	player.queue_free()
	floor_body.queue_free()
	await fixture.process_frames(1)


func find_top_level_area(enemy: CharacterBody2D) -> Area2D:
	for node in enemy.find_children("*", "Area2D", true, false):
		var area := node as Area2D
		if area != null and area.top_level:
			return area

	return null
