extends SceneTree


const WOLF_SCENE := preload("res://enemies/wolf.tscn")
const EnemyHarness := preload("res://tests/enemy_scene_harness.gd")
const DASH_DISTANCE := 300.0
const DEAD_ANIMATION := &"dead"
const HURT_ANIMATION := &"hurt"
const SKILL_ANIMATION := &"skill"

var failures: Array[String] = []
var harness: EnemySceneHarness


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	ProjectSettings.set_setting("physics/2d/default_gravity", 0.0)
	harness = EnemyHarness.new(self)

	await test_configuration_and_patrol()
	await test_scaled_environment_wall_reversal()
	await test_dash_distance_reentry_and_cooldown()
	await test_dash_collision_and_weapon_immunity()
	await test_hurt_immunity_and_death_cleanup()

	ProjectSettings.set_setting("physics/2d/default_gravity", original_gravity)
	harness.cleanup()
	await process_frame
	await process_frame
	finish()


func test_configuration_and_patrol() -> void:
	var wolf := harness.instantiate_enemy(WOLF_SCENE, Vector2.ZERO)
	expect(wolf.patrol_range == 160.0, "Wolf keeps its 160 pixel patrol range")
	expect(wolf.run_speed == 80.0, "Wolf keeps its 80 pixel run speed")
	expect(wolf.idle_duration == 1.0, "Wolf keeps its one second idle duration")
	expect(
		is_equal_approx(harness.animation_length(wolf, HURT_ANIMATION), 0.35),
		"Wolf keeps its hurt-immunity presentation timing"
	)
	expect(
		is_equal_approx(harness.animation_length(wolf, DEAD_ANIMATION), 2.0),
		"Wolf keeps its death presentation timing"
	)

	var patrol_start := Vector2(1000.0, 0.0)
	var patrol_wolf := harness.instantiate_enemy(
		WOLF_SCENE,
		patrol_start,
		{"idle_duration": 0.15, "patrol_range": 40.0}
	)
	await create_timer(0.05).timeout
	expect(
		is_equal_approx(patrol_wolf.global_position.x, patrol_start.x),
		"Wolf stays still during its configured idle"
	)
	await create_timer(0.2).timeout
	expect(patrol_wolf.global_position.x > patrol_start.x, "Wolf begins its patrol rightward")
	expect(harness.is_facing_right(patrol_wolf), "Wolf faces its rightward patrol direction")
	await create_timer(0.55).timeout
	expect(
		is_equal_approx(patrol_wolf.global_position.x, patrol_start.x + 40.0),
		"Wolf reverses at its configured right patrol limit"
	)
	await create_timer(0.2).timeout
	expect(
		patrol_wolf.global_position.x < patrol_start.x + 40.0,
		"Wolf continues patrolling left after its limit reversal"
	)
	expect(not harness.is_facing_right(patrol_wolf), "Wolf faces its leftward patrol direction")

	var left_dash_start := patrol_wolf.global_position.x
	var player := harness.instantiate_passive_player(
		patrol_wolf.global_position + Vector2(-120.0, 0.0),
		func() -> void: pass
	)
	await harness.physics_frames(3)
	player.position += Vector2(1000.0, 0.0)
	await create_timer(0.8).timeout
	expect(
		patrol_wolf.global_position.x < left_dash_start - 250.0,
		"Wolf detection and dash stay synchronized with its leftward facing"
	)
	var resumed_x := patrol_wolf.global_position.x
	await create_timer(0.1).timeout
	expect(
		patrol_wolf.global_position.x < resumed_x,
		"Wolf resumes its prior running behavior after the dash"
	)


func test_scaled_environment_wall_reversal() -> void:
	var start_position := Vector2(2000.0, 0.0)
	harness.add_environment_wall(start_position + Vector2(100.0, 48.0), Vector2(10.0, 8.0))
	var wolf := harness.instantiate_enemy(
		WOLF_SCENE,
		start_position,
		{
			"idle_duration": 0.0,
			"patrol_range": 1000.0,
			"scale": Vector2(2.0, 2.0),
		}
	)

	await harness.physics_frames(12)
	expect(
		wolf.global_position.x < start_position.x,
		"Scaled Wolf reverses away from environment geometry"
	)
	var turned_x := wolf.global_position.x
	await harness.physics_frames(6)
	expect(wolf.global_position.x < turned_x, "Wolf keeps patrolling after its wall reversal")


func test_dash_distance_reentry_and_cooldown() -> void:
	var start_position := Vector2(3500.0, 0.0)
	var wolf := harness.instantiate_enemy(
		WOLF_SCENE,
		start_position,
		{"idle_duration": 10.0}
	)
	var player := harness.instantiate_passive_player(
		start_position + Vector2(100.0, 0.0),
		func() -> void: pass
	)

	await harness.physics_frames(3)
	expect(wolf.global_position.x > start_position.x, "Gameplay detection starts Wolf dash")
	expect(harness.is_playing(wolf, SKILL_ANIMATION), "Wolf dash starts its skill presentation")
	player.position = start_position - Vector2(1000.0, 0.0)
	var speed_sample_x := wolf.global_position.x
	await harness.physics_frames(6)
	expect(
		absf(wolf.global_position.x - speed_sample_x - 40.0) <= 1.0,
		"Wolf keeps its 400 pixel per second dash speed"
	)
	player.position = wolf.global_position + Vector2(350.0, 0.0)
	await harness.physics_frames(2)
	player.position = start_position - Vector2(1000.0, 0.0)
	await create_timer(0.65).timeout
	expect(
		is_equal_approx(wolf.global_position.x, start_position.x + DASH_DISTANCE),
		"Repeated detection cannot restart Wolf's configured 300 pixel dash"
	)
	var dash_end_x := wolf.global_position.x
	await create_timer(0.15).timeout
	expect(
		is_equal_approx(wolf.global_position.x, dash_end_x),
		"Wolf returns to its prior idle behavior after the dash"
	)

	await harness.reenter_skill_detection(player, wolf.global_position + Vector2(100.0, 0.0))
	await create_timer(0.15).timeout
	expect(
		is_equal_approx(wolf.global_position.x, dash_end_x),
		"Wolf cannot restart its dash during cooldown"
	)
	await create_timer(3.4).timeout
	await harness.reenter_skill_detection(player, wolf.global_position + Vector2(100.0, 0.0))
	await create_timer(0.1).timeout
	expect(
		is_equal_approx(wolf.global_position.x, dash_end_x),
		"Wolf keeps the full five second dash cooldown"
	)
	await create_timer(0.4).timeout
	await harness.reenter_skill_detection(player, wolf.global_position + Vector2(100.0, 0.0))
	await harness.physics_frames(3)
	expect(wolf.global_position.x > dash_end_x, "Wolf can dash again after cooldown expires")
	player.position -= Vector2(1000.0, 0.0)


func test_dash_collision_and_weapon_immunity() -> void:
	var wolf_position := Vector2(5000.0, 0.0)
	var wolf := harness.instantiate_enemy(
		WOLF_SCENE,
		wolf_position,
		{"idle_duration": 10.0}
	)
	var hurt_event_count: Array[int] = [0]
	var player_start := wolf_position + Vector2(300.0, 0.0)
	var player := harness.instantiate_passive_player(
		player_start,
		func() -> void: hurt_event_count[0] += 1
	)
	await harness.physics_frames(3)

	var early_weapon := harness.add_weapon(wolf.global_position)
	await harness.physics_frames(3)
	harness.remove_actor(early_weapon)
	await create_timer(0.5).timeout
	var late_weapon := harness.add_weapon(wolf.global_position)
	await harness.physics_frames(3)
	harness.remove_actor(late_weapon)
	await create_timer(0.25).timeout

	expect(hurt_event_count[0] == 1, "One Wolf dash collision damages Player once")
	expect(player.global_position.x > player_start.x, "Wolf dash knocks Player away from collision")
	await harness.deliver_hit(wolf, Vector2(-20.0, 0.0))
	expect(wolf.is_in_group("enemies"), "Wolf accepts one hit after dash immunity ends")
	await harness.deliver_hit(wolf)
	await create_timer(0.3).timeout
	expect(wolf.is_in_group("enemies"), "Wolf ignores damage during its hurt-immunity window")


func test_hurt_immunity_and_death_cleanup() -> void:
	var wolf_position := Vector2(7000.0, 0.0)
	var wolf := harness.instantiate_enemy(
		WOLF_SCENE,
		wolf_position,
		{"idle_duration": 10.0}
	)
	await harness.physics_frames(2)
	expect(harness.enemy_has_body_collision(wolf), "Living Wolf has an active body collision")
	expect(harness.enemy_has_hurt_collision(wolf), "Living Wolf has an active hurt collision")

	await harness.deliver_hit(wolf, Vector2(-20.0, 0.0))
	expect(wolf.is_in_group("enemies"), "Wolf keeps its two point health capacity")
	expect(harness.is_playing(wolf, HURT_ANIMATION), "Accepted damage starts Wolf hurt presentation")
	expect(
		is_equal_approx(wolf.global_position.x, wolf_position.x + 100.0),
		"Accepted damage keeps Wolf's 100 pixel knockback"
	)
	await harness.deliver_hit(wolf)
	await create_timer(0.3).timeout
	expect(wolf.is_in_group("enemies"), "A hit during hurt immunity does not consume Wolf health")
	await create_timer(0.1).timeout
	await harness.deliver_hit(wolf)
	await process_frame
	await physics_frame

	expect(not wolf.is_in_group("enemies"), "Death immediately removes Wolf as an active Enemy")
	expect(harness.is_playing(wolf, DEAD_ANIMATION), "Lethal damage starts Wolf death presentation")
	expect(not harness.enemy_has_body_collision(wolf), "Death immediately disables Wolf body collision")
	expect(not harness.enemy_has_hurt_collision(wolf), "Death immediately disables Wolf hurt collision")
	await create_timer(0.75).timeout
	expect(is_instance_valid(wolf), "Wolf remains in the scene during its death presentation")
	expect(
		harness.animation_position(wolf, DEAD_ANIMATION) >= 0.7,
		"Wolf death presentation advances before cleanup"
	)
	await create_timer(1.3).timeout
	expect(not is_instance_valid(wolf), "Wolf leaves after its two second death presentation")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("Wolf Enemy lifecycle test passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
