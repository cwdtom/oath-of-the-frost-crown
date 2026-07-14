extends SceneTree


const BEAR_SCENE := preload("res://enemies/bear.tscn")
const PLAYER_SCENE := preload("res://player/player.tscn")
const EnemyHarness := preload("res://tests/enemy_scene_harness.gd")
const DEAD_ANIMATION := &"dead"
const HURT_ANIMATION := &"hurt"
const IDLE_ANIMATION := &"idle"
const RUN_ANIMATION := &"run"
const SKILL_ANIMATION := &"skill"
const EARTHQUAKE_CAST_ANIMATION := &"cast"

var failures: Array[String] = []
var harness: EnemySceneHarness


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	ProjectSettings.set_setting("physics/2d/default_gravity", 0.0)
	harness = EnemyHarness.new(self)

	await test_initialization_and_patrol_limits()
	await test_scaled_environment_wall_reversal()
	await test_earthquake_activation_and_cooldown()
	await test_earthquake_damage_interruption()
	await test_hurt_immunity_and_death_cleanup()

	ProjectSettings.set_setting("physics/2d/default_gravity", original_gravity)
	harness.cleanup()
	await process_frame
	await process_frame
	finish()


func test_initialization_and_patrol_limits() -> void:
	var bear := harness.instantiate_enemy(
		BEAR_SCENE,
		Vector2.ZERO,
		{"idle_duration": 0.08, "patrol_range": 20.0, "run_speed": 80.0}
	)
	var start_x := bear.global_position.x
	await create_timer(0.04).timeout
	expect(is_playing(bear, IDLE_ANIMATION), "Bear initializes in its idle presentation")
	expect(is_equal_approx(bear.global_position.x, start_x), "Bear stays still for its idle duration")

	await create_timer(0.12).timeout
	expect(is_playing(bear, RUN_ANIMATION), "Bear enters its run presentation after idling")
	expect(bear.global_position.x < start_x, "Bear begins patrolling after idling")
	expect(not is_facing_right(bear), "Bear faces its initial leftward patrol direction")

	await create_timer(0.25).timeout
	expect(
		bear.global_position.x >= start_x - 20.01,
		"Bear does not move beyond its configured patrol limit"
	)
	var left_limit_x := bear.global_position.x
	await create_timer(0.12).timeout
	expect(bear.global_position.x > left_limit_x, "Bear reverses and continues from its patrol limit")
	expect(is_facing_right(bear), "Bear presentation faces the reversed patrol direction")

	var default_bear := harness.instantiate_enemy(BEAR_SCENE, Vector2(500.0, 0.0))
	expect(default_bear.patrol_range == 160.0, "Bear keeps its 160 pixel patrol range")
	expect(default_bear.run_speed == 80.0, "Bear keeps its 80 pixel run speed")
	expect(default_bear.idle_duration == 1.0, "Bear keeps its one second idle duration")
	expect(
		is_equal_approx(animation_length(default_bear, HURT_ANIMATION), 0.35),
		"Bear keeps its hurt animation timing"
	)
	expect(
		is_equal_approx(animation_length(default_bear, SKILL_ANIMATION), 0.9),
		"Bear keeps its skill animation timing"
	)
	expect(
		is_equal_approx(animation_length(default_bear, DEAD_ANIMATION), 1.0),
		"Bear keeps its death presentation timing"
	)


func test_scaled_environment_wall_reversal() -> void:
	var start_position := Vector2(1500.0, 0.0)
	harness.add_environment_wall(start_position + Vector2(-100.0, 36.0), Vector2(10.0, 8.0))
	var bear := harness.instantiate_enemy(
		BEAR_SCENE,
		start_position,
		{"scale": Vector2(1.5, 1.5), "idle_duration": 0.0, "patrol_range": 1000.0}
	)

	await physics_frames(12)
	expect(bear.global_position.x > start_position.x, "Scaled Bear reverses away from an environment wall")
	expect(is_facing_right(bear), "Scaled Bear faces away from the blocking wall")
	var turned_x := bear.global_position.x
	await physics_frames(6)
	expect(bear.global_position.x > turned_x, "Bear keeps patrolling after its wall reversal")


func test_earthquake_activation_and_cooldown() -> void:
	var bear_position := Vector2(3000.0, 0.0)
	var bear := harness.instantiate_enemy(
		BEAR_SCENE,
		bear_position,
		{"idle_duration": 10.0}
	)
	var hurt_events: Array[int] = [0]
	var player := instantiate_passive_player(
		bear_position + Vector2(-152.0, 42.5),
		hurt_events
	)

	await physics_frames(3)
	await create_timer(0.05).timeout
	expect(is_playing(bear, SKILL_ANIMATION), "Gameplay detection starts Bear earthquake")
	expect(is_playing(bear, EARTHQUAKE_CAST_ANIMATION), "Earthquake cast starts with Bear skill")
	expect(
		absf(
			animation_position(bear, SKILL_ANIMATION)
			- animation_position(bear, EARTHQUAKE_CAST_ANIMATION)
		) < 0.1,
		"Bear and earthquake presentations begin in sync"
	)
	expect(is_equal_approx(bear.velocity.x, 0.0), "Bear remains stationary during earthquake")
	var skill_start_x := bear.global_position.x

	await create_timer(0.2).timeout
	var skill_position_before_repeat := animation_position(bear, SKILL_ANIMATION)
	var cast_position_before_repeat := animation_position(bear, EARTHQUAKE_CAST_ANIMATION)
	player.position += Vector2(400.0, 0.0)
	await physics_frame
	await physics_frame
	player.position -= Vector2(400.0, 0.0)
	await physics_frame
	await physics_frame
	await create_timer(0.05).timeout
	expect(
		animation_position(bear, SKILL_ANIMATION) > skill_position_before_repeat,
		"Repeated detection does not restart Bear skill presentation"
	)
	expect(
		animation_position(bear, EARTHQUAKE_CAST_ANIMATION) > cast_position_before_repeat,
		"Repeated detection does not restart earthquake presentation"
	)

	await create_timer(0.5).timeout
	await physics_frame
	expect(hurt_events[0] == 1, "One earthquake activation damages its target once")
	await create_timer(0.25).timeout
	expect(not is_playing(bear, SKILL_ANIMATION), "Earthquake completes after one activation")
	expect(is_equal_approx(bear.global_position.x, skill_start_x), "Bear does not move during earthquake")

	await reenter_skill_detection(player, bear_position + Vector2(-152.0, 42.5))
	expect(not is_playing(bear, SKILL_ANIMATION), "Bear cannot restart earthquake during cooldown")
	await create_timer(3.2).timeout
	await reenter_skill_detection(player, bear_position + Vector2(-152.0, 42.5))
	expect(not is_playing(bear, SKILL_ANIMATION), "Bear keeps the full five second skill cooldown")
	await create_timer(0.55).timeout
	await reenter_skill_detection(player, bear_position + Vector2(-152.0, 42.5))
	expect(is_playing(bear, SKILL_ANIMATION), "Bear can use earthquake after cooldown expires")


func test_earthquake_damage_interruption() -> void:
	var bear_position := Vector2(5000.0, 0.0)
	var bear := harness.instantiate_enemy(
		BEAR_SCENE,
		bear_position,
		{"idle_duration": 10.0}
	)
	var hurt_events: Array[int] = [0]
	instantiate_passive_player(bear_position + Vector2(-152.0, 42.5), hurt_events)
	await physics_frames(3)
	await create_timer(0.05).timeout
	expect(is_playing(bear, SKILL_ANIMATION), "Bear starts earthquake for an entering gameplay body")

	var weapon := harness.add_weapon(bear_position)
	await physics_frames(3)
	await process_frame
	expect(is_playing(bear, HURT_ANIMATION), "Accepted damage visibly interrupts earthquake")
	expect(not is_playing(bear, EARTHQUAKE_CAST_ANIMATION), "Hurt stops the earthquake cast")
	harness.remove_actor(weapon)
	await create_timer(0.65).timeout
	expect(hurt_events[0] == 0, "Interrupted earthquake never reaches its damaging impact")
	expect(not is_playing(bear, SKILL_ANIMATION), "Interrupted earthquake does not resume after hurt")


func test_hurt_immunity_and_death_cleanup() -> void:
	var bear_position := Vector2(7000.0, 0.0)
	var bear := harness.instantiate_enemy(
		BEAR_SCENE,
		bear_position,
		{"idle_duration": 10.0}
	)
	await physics_frame
	await physics_frame
	expect(harness.enemy_has_body_collision(bear), "Living Bear has an active body collision")
	expect(harness.enemy_has_hurt_collision(bear), "Living Bear has an active hurt collision")

	await deliver_hit(bear, Vector2(-20.0, 0.0))
	expect(is_playing(bear, HURT_ANIMATION), "Accepted damage starts Bear hurt presentation")
	expect(
		is_equal_approx(bear.global_position.x, bear_position.x + 100.0),
		"Accepted damage keeps Bear's knockback distance"
	)
	await deliver_hit(bear)
	await create_timer(0.4).timeout
	await deliver_hit(bear)
	await create_timer(0.4).timeout
	await deliver_hit(bear)
	await create_timer(0.4).timeout
	expect(bear.is_in_group("enemies"), "A hit during hurt immunity does not consume Bear health")

	var death_skill_position := bear.global_position
	var hurt_events: Array[int] = [0]
	instantiate_passive_player(
		death_skill_position + Vector2(-152.0, 42.5),
		hurt_events
	)
	await physics_frames(3)
	await create_timer(0.05).timeout
	expect(is_playing(bear, SKILL_ANIMATION), "Bear can enter earthquake before a lethal hit")

	await deliver_hit(bear)
	await process_frame
	await physics_frame
	expect(not bear.is_in_group("enemies"), "Death immediately removes Bear as an active Enemy")
	expect(is_playing(bear, DEAD_ANIMATION), "Death immediately starts Bear death presentation")
	expect(not is_playing(bear, EARTHQUAKE_CAST_ANIMATION), "Death stops the earthquake cast")
	expect(not harness.enemy_has_body_collision(bear), "Death immediately disables Bear body collision")
	expect(not harness.enemy_has_hurt_collision(bear), "Death immediately disables Bear hurt collision")

	await create_timer(0.75).timeout
	expect(is_instance_valid(bear), "Bear remains in the scene during its death presentation")
	expect(hurt_events[0] == 0, "A dead Bear cannot produce a delayed earthquake impact")
	expect(
		animation_position(bear, DEAD_ANIMATION) >= 0.7,
		"Bear death presentation reaches its final frames"
	)
	await create_timer(0.3).timeout
	expect(not is_instance_valid(bear), "Bear leaves the scene after its death presentation")


func deliver_hit(bear: CharacterBody2D, offset := Vector2.ZERO) -> void:
	var weapon := harness.add_weapon(bear.global_position + offset)
	await physics_frames(3)
	await process_frame
	harness.remove_actor(weapon)
	await physics_frames(2)
	await process_frame


func reenter_skill_detection(actor: CharacterBody2D, detection_position: Vector2) -> void:
	actor.position = detection_position + Vector2(400.0, 0.0)
	await physics_frames(2)
	actor.position = detection_position
	await physics_frames(2)
	await create_timer(0.05).timeout


func physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func instantiate_passive_player(position: Vector2, hurt_events: Array[int]) -> CharacterBody2D:
	var player := harness.instantiate_actor(PLAYER_SCENE, position)
	player.set_physics_process(false)
	player.hurt_taken.connect(func() -> void: hurt_events[0] += 1)
	return player


func is_playing(enemy: CharacterBody2D, animation_name: StringName) -> bool:
	return bool(enemy.call("_is_playing_animation", animation_name))


func animation_position(enemy: CharacterBody2D, animation_name: StringName) -> float:
	return float(enemy.call("_get_animation_position", animation_name))


func animation_length(enemy: CharacterBody2D, animation_name: StringName) -> float:
	return float(enemy.call("_get_animation_length", animation_name))


func is_facing_right(enemy: CharacterBody2D) -> bool:
	return bool(enemy.call("_is_facing_right"))


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("Bear Enemy lifecycle test passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
