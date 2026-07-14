extends SceneTree


const BEAR_SCENE := preload("res://enemies/bear.tscn")
const EnemyHarness := preload("res://tests/enemy_scene_harness.gd")
const HURT_ANIMATION := &"hurt"
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

	await test_earthquake_activation_and_cooldown()
	await test_earthquake_damage_interruption()

	ProjectSettings.set_setting("physics/2d/default_gravity", original_gravity)
	harness.cleanup()
	await process_frame
	await process_frame
	finish()


func test_earthquake_activation_and_cooldown() -> void:
	var bear_position := Vector2(3000.0, 0.0)
	var bear := harness.instantiate_enemy(
		BEAR_SCENE,
		bear_position,
		{"idle_duration": 10.0}
	)
	var hurt_event_count: Array[int] = [0]
	var player := harness.instantiate_passive_player(
		bear_position + Vector2(-152.0, 42.5),
		func() -> void: hurt_event_count[0] += 1
	)

	await harness.physics_frames(3)
	await create_timer(0.05).timeout
	expect(harness.is_playing(bear, SKILL_ANIMATION), "Gameplay detection starts Bear earthquake")
	expect(harness.is_playing(bear, EARTHQUAKE_CAST_ANIMATION), "Earthquake cast starts with Bear skill")
	expect(
		absf(
			harness.animation_position(bear, SKILL_ANIMATION)
			- harness.animation_position(bear, EARTHQUAKE_CAST_ANIMATION)
		) < 0.1,
		"Bear and earthquake presentations begin in sync"
	)
	expect(is_equal_approx(bear.velocity.x, 0.0), "Bear remains stationary during earthquake")
	var skill_start_x := bear.global_position.x

	await create_timer(0.2).timeout
	var skill_position_before_repeat := harness.animation_position(bear, SKILL_ANIMATION)
	var cast_position_before_repeat := harness.animation_position(bear, EARTHQUAKE_CAST_ANIMATION)
	player.position += Vector2(400.0, 0.0)
	await physics_frame
	await physics_frame
	player.position -= Vector2(400.0, 0.0)
	await physics_frame
	await physics_frame
	await create_timer(0.05).timeout
	expect(
		harness.animation_position(bear, SKILL_ANIMATION) > skill_position_before_repeat,
		"Repeated detection does not restart Bear skill presentation"
	)
	expect(
		harness.animation_position(bear, EARTHQUAKE_CAST_ANIMATION) > cast_position_before_repeat,
		"Repeated detection does not restart earthquake presentation"
	)

	await create_timer(0.5).timeout
	await physics_frame
	expect(hurt_event_count[0] == 1, "One earthquake activation damages its target once")
	await create_timer(0.25).timeout
	expect(not harness.is_playing(bear, SKILL_ANIMATION), "Earthquake completes after one activation")
	expect(is_equal_approx(bear.global_position.x, skill_start_x), "Bear does not move during earthquake")

	await harness.reenter_skill_detection(player, bear_position + Vector2(-152.0, 42.5))
	expect(not harness.is_playing(bear, SKILL_ANIMATION), "Bear cannot restart earthquake during cooldown")
	await create_timer(3.2).timeout
	await harness.reenter_skill_detection(player, bear_position + Vector2(-152.0, 42.5))
	expect(not harness.is_playing(bear, SKILL_ANIMATION), "Bear keeps the full five second skill cooldown")
	await create_timer(0.55).timeout
	await harness.reenter_skill_detection(player, bear_position + Vector2(-152.0, 42.5))
	expect(harness.is_playing(bear, SKILL_ANIMATION), "Bear can use earthquake after cooldown expires")


func test_earthquake_damage_interruption() -> void:
	var bear_position := Vector2(5000.0, 0.0)
	var bear := harness.instantiate_enemy(
		BEAR_SCENE,
		bear_position,
		{"idle_duration": 10.0}
	)
	var hurt_event_count: Array[int] = [0]
	harness.instantiate_passive_player(
		bear_position + Vector2(-152.0, 42.5),
		func() -> void: hurt_event_count[0] += 1
	)
	await harness.physics_frames(3)
	await create_timer(0.05).timeout
	expect(harness.is_playing(bear, SKILL_ANIMATION), "Bear starts earthquake for an entering gameplay body")

	var weapon := harness.add_weapon(bear_position)
	await harness.physics_frames(3)
	await process_frame
	expect(harness.is_playing(bear, HURT_ANIMATION), "Accepted damage visibly interrupts earthquake")
	expect(not harness.is_playing(bear, EARTHQUAKE_CAST_ANIMATION), "Hurt stops the earthquake cast")
	harness.remove_actor(weapon)
	await create_timer(0.65).timeout
	expect(hurt_event_count[0] == 0, "Interrupted earthquake never reaches its damaging impact")
	expect(not harness.is_playing(bear, SKILL_ANIMATION), "Interrupted earthquake does not resume after hurt")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("Bear earthquake test passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
