extends SceneTree


const BEAR_SCENE := preload("res://enemies/bear.tscn")
const WOLF_SCENE := preload("res://enemies/wolf.tscn")
const BEAR_KING_SCENE := preload("res://enemies/bear_king.tscn")
const WOLF_KING_SCENE := preload("res://enemies/wolf_king.tscn")
const LEVEL_01_SCENE := preload("res://levels/level_01.tscn")
const LEVEL_02_SCENE := preload("res://levels/level_02.tscn")
const EnemyHarness := preload("res://tests/enemy_scene_harness.gd")

const ENEMY_EXAMPLES := [
	{
		"name": "Bear",
		"scene": BEAR_SCENE,
		"initial_direction": -1.0,
		"patrol_range": 160.0,
		"run_speed": 80.0,
		"scale": Vector2.ONE,
		"health": 4,
		"hurt_recovery": 0.4,
		"death_duration": 1.0,
		"blocks_skill_damage": false,
		"notifies_death": false,
		"detector_offset": Vector2(-152.0, 42.5),
	},
	{
		"name": "Wolf",
		"scene": WOLF_SCENE,
		"initial_direction": 1.0,
		"patrol_range": 160.0,
		"run_speed": 80.0,
		"scale": Vector2.ONE,
		"health": 2,
		"hurt_recovery": 0.4,
		"death_duration": 2.0,
		"blocks_skill_damage": true,
		"notifies_death": false,
		"detector_offset": Vector2(100.0, 0.0),
	},
	{
		"name": "BearKing",
		"scene": BEAR_KING_SCENE,
		"initial_direction": -1.0,
		"patrol_range": 160.0,
		"run_speed": 80.0,
		"scale": Vector2(1.5, 1.5),
		"health": 15,
		"hurt_recovery": 0.45,
		"death_duration": 1.0,
		"blocks_skill_damage": false,
		"notifies_death": true,
		"detector_offset": Vector2(-228.0, 72.0),
	},
	{
		"name": "WolfKing",
		"scene": WOLF_KING_SCENE,
		"initial_direction": -1.0,
		"patrol_range": 300.0,
		"run_speed": 150.0,
		"scale": Vector2.ONE,
		"health": 5,
		"hurt_recovery": 1.05,
		"death_duration": 2.0,
		"blocks_skill_damage": true,
		"notifies_death": true,
		"detector_offset": Vector2(-150.0, 0.0),
	},
]

var failures: Array[String] = []
var harness: EnemySceneHarness


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	ProjectSettings.set_setting("physics/2d/default_gravity", 0.0)
	harness = EnemyHarness.new(self)

	test_levels_keep_their_enemy_encounters()
	await test_initialization_patrol_limits_and_facing()
	await test_scaled_environment_wall_reversal()
	await test_skill_interruption_policy()
	await test_hurt_immunity_death_notification_and_cleanup()

	ProjectSettings.set_setting("physics/2d/default_gravity", original_gravity)
	harness.cleanup()
	await process_frame
	await process_frame
	finish()


func test_initialization_patrol_limits_and_facing() -> void:
	var start_x := 0.0
	for example in ENEMY_EXAMPLES:
		var configured_enemy := harness.instantiate_enemy(example.scene, Vector2(start_x, 0.0))
		expect(
			configured_enemy.patrol_range == example.patrol_range,
			"%s keeps its scene-facing patrol range" % example.name
		)
		expect(
			configured_enemy.run_speed == example.run_speed,
			"%s keeps its scene-facing run speed" % example.name
		)
		expect(
			configured_enemy.idle_duration == 1.0,
			"%s keeps its scene-facing idle duration" % example.name
		)
		expect(
			configured_enemy.scale == example.scale,
			"%s keeps its scene-facing scale" % example.name
		)
		harness.remove_actor(configured_enemy)
		await process_frame

		var enemy := harness.instantiate_enemy(
			example.scene,
			Vector2(start_x, 0.0),
			{"idle_duration": 0.15, "patrol_range": 20.0, "run_speed": 80.0}
		)
		var initial_x := enemy.global_position.x
		await create_timer(0.05).timeout
		expect(enemy.is_in_group("enemies"), "%s initializes as an active Enemy" % example.name)
		expect(harness.enemy_has_body_collision(enemy), "%s initializes with body collision" % example.name)
		expect(harness.enemy_has_hurt_collision(enemy), "%s initializes with hurt collision" % example.name)
		expect(
			is_equal_approx(enemy.global_position.x, initial_x),
			"%s stays still for its configured idle" % example.name
		)
		expect(
			not harness.enemy_sprite_is_flipped(enemy),
			"%s visibly faces its initial patrol direction" % example.name
		)

		await create_timer(0.2).timeout
		expect(
			(enemy.global_position.x - initial_x) * example.initial_direction > 0.0,
			"%s begins patrolling after idling" % example.name
		)

		await create_timer(0.45).timeout
		var patrol_limit: float = initial_x + example.initial_direction * 20.0
		expect(
			absf(enemy.global_position.x - initial_x) <= 20.01,
			"%s stays within its configured patrol limits" % example.name
		)
		expect(
			(enemy.global_position.x - patrol_limit) * -example.initial_direction > 0.0,
			"%s reverses and continues from its patrol limit" % example.name
		)
		expect(
			harness.enemy_sprite_is_flipped(enemy),
			"%s visibly faces its reversed patrol direction" % example.name
		)

		harness.remove_actor(enemy)
		await process_frame
		start_x += 1000.0


func test_levels_keep_their_enemy_encounters() -> void:
	verify_level_enemy_encounters(LEVEL_01_SCENE, "Level 01", 5, 1)
	verify_level_enemy_encounters(LEVEL_02_SCENE, "Level 02", 5, 1)


func verify_level_enemy_encounters(
	level_scene: PackedScene,
	level_name: String,
	expected_enemy_count: int,
	expected_boss_count: int
) -> void:
	var level := level_scene.instantiate()
	var enemy_count := 0
	var boss_count := 0
	for node in level.find_children("*", "CharacterBody2D", true, false):
		var enemy := node as CharacterBody2D
		if enemy == null or not enemy.is_in_group("enemies"):
			continue

		enemy_count += 1
		if enemy.has_signal(&"died") and harness.enemy_health_bar(enemy) != null:
			boss_count += 1

	expect(
		enemy_count == expected_enemy_count,
		"%s keeps all existing packed Enemy encounters" % level_name
	)
	expect(
		boss_count == expected_boss_count,
		"%s keeps its existing boss Enemy encounter" % level_name
	)
	level.free()


func test_skill_interruption_policy() -> void:
	var start_x := 10000.0
	for example in ENEMY_EXAMPLES:
		var enemy := harness.instantiate_enemy(
			example.scene,
			Vector2(start_x, 0.0),
			{"idle_duration": 10.0, "patrol_range": 1000.0}
		)
		var health_bar := harness.enemy_health_bar(enemy)
		var detector := harness.add_body(enemy.global_position + example.detector_offset)
		await harness.physics_frames(3)
		harness.remove_actor(detector)
		var skill_x := enemy.global_position.x

		var weapon := harness.add_weapon(
			enemy.global_position + Vector2(-50.0, 0.0),
			Vector2(200.0, 200.0)
		)
		await harness.physics_frames(2)
		harness.remove_actor(weapon)
		await process_frame

		if example.blocks_skill_damage:
			var movement_x := enemy.global_position.x
			await harness.physics_frames(6)
			expect(
				(enemy.global_position.x - movement_x) * example.initial_direction > 0.0,
				"%s keeps using its moving skill through weapon contact" % example.name
			)
			if health_bar != null:
				expect(
					health_bar.value == example.health,
					"%s skill immunity preserves its boss health presentation" % example.name
				)
		else:
			expect(
				enemy.global_position.x > skill_x + 50.0,
				"%s accepts weapon interruption during its stationary skill" % example.name
			)
			if health_bar != null:
				expect(
					health_bar.value == example.health - 1,
					"%s interruption updates its boss health presentation" % example.name
				)

		harness.remove_actor(enemy)
		await process_frame
		start_x += 1500.0


func test_hurt_immunity_death_notification_and_cleanup() -> void:
	var start_x := 17000.0
	for example in ENEMY_EXAMPLES:
		var enemy := harness.instantiate_enemy(
			example.scene,
			Vector2(start_x, 0.0),
			{"idle_duration": 10.0, "patrol_range": 1000.0}
		)
		var health_bar := harness.enemy_health_bar(enemy)
		var death_outcome_count: Array[int] = [0]
		if example.notifies_death:
			enemy.connect(
				&"died",
				func() -> void:
					death_outcome_count[0] += 1
					paused = true
			)

		await harness.deliver_hit(enemy, Vector2(-20.0, 0.0))
		var first_hit_x := enemy.global_position.x
		expect(enemy.is_in_group("enemies"), "%s survives its first accepted hit" % example.name)
		await harness.deliver_hit(enemy, Vector2(20.0, 0.0))
		expect(
			is_equal_approx(enemy.global_position.x, first_hit_x),
			"%s ignores knockback during its hurt-immunity window" % example.name
		)
		expect(
			enemy.is_in_group("enemies"),
			"%s ignores damage during its hurt-immunity window" % example.name
		)
		if health_bar != null:
			expect(
				health_bar.value == example.health - 1,
				"%s hurt immunity preserves its boss health presentation" % example.name
			)

		for accepted_hit_index in range(1, example.health):
			await create_timer(example.hurt_recovery).timeout
			await harness.deliver_hit(enemy)
			if accepted_hit_index < example.health - 1:
				expect(
					enemy.is_in_group("enemies"),
					"%s remains active before its lethal hit" % example.name
				)

		expect(
			not enemy.is_in_group("enemies"),
			"%s death immediately removes it from active Enemies" % example.name
		)
		expect(
			not harness.enemy_has_body_collision(enemy),
			"%s death immediately disables body collision" % example.name
		)
		expect(
			not harness.enemy_has_hurt_collision(enemy),
			"%s death immediately disables hurt collision" % example.name
		)
		var death_start_texture := harness.enemy_sprite_texture(enemy)
		if example.notifies_death:
			expect(
				death_outcome_count[0] == 1,
				"%s emits one boss death outcome" % example.name
			)

		await create_timer(example.death_duration * 0.6).timeout
		expect(
			is_instance_valid(enemy),
			"%s remains during its death presentation" % example.name
		)
		expect(
			harness.enemy_sprite_texture(enemy) != death_start_texture,
			"%s visibly advances its death presentation" % example.name
		)
		await create_timer(example.death_duration * 0.55).timeout
		expect(
			not is_instance_valid(enemy),
			"%s leaves after its death presentation" % example.name
		)
		if example.notifies_death:
			expect(
				death_outcome_count[0] == 1,
				"%s death outcome remains singular after cleanup" % example.name
			)
			paused = false

		start_x += 1500.0


func test_scaled_environment_wall_reversal() -> void:
	var start_x := 5000.0
	for example in ENEMY_EXAMPLES:
		var initial_direction: float = example.initial_direction
		var start_position := Vector2(start_x, 0.0)
		var wall := harness.add_environment_wall(
			start_position + Vector2(initial_direction * 80.0, 36.0),
			Vector2(10.0, 8.0)
		)
		var enemy := harness.instantiate_enemy(
			example.scene,
			start_position,
			{
				"idle_duration": 0.0,
				"patrol_range": 1000.0,
				"scale": Vector2(1.5, 1.5),
			}
		)

		await harness.physics_frames(12)
		expect(
			(enemy.global_position.x - start_position.x) * initial_direction < 0.0,
			"Scaled %s reverses away from an environment wall" % example.name
		)
		expect(
			harness.enemy_sprite_is_flipped(enemy),
			"Scaled %s visibly faces away from the wall" % example.name
		)
		var turned_x := enemy.global_position.x
		await harness.physics_frames(6)
		expect(
			(enemy.global_position.x - turned_x) * initial_direction < 0.0,
			"%s keeps patrolling after its wall reversal" % example.name
		)

		harness.remove_actor(enemy)
		harness.remove_actor(wall)
		await process_frame
		start_x += 1000.0


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("Shared Enemy behavior test passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
