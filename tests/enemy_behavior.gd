extends SceneTree


const BEAR_SCENE := preload("res://enemies/bear.tscn")
const WOLF_SCENE := preload("res://enemies/wolf.tscn")
const ELK_SCENE := preload("res://enemies/elk.tscn")
const BEAR_KING_SCENE := preload("res://enemies/bear_king.tscn")
const WOLF_KING_SCENE := preload("res://enemies/wolf_king.tscn")
const LEVEL_01_SCENE := preload("res://levels/level_01.tscn")
const LEVEL_02_SCENE := preload("res://levels/level_02.tscn")
const EnemyHarness := preload("res://tests/enemy_scene_harness.gd")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")

const ENEMY_EXAMPLES := [
	{
		"name": "Bear",
		"scene": BEAR_SCENE,
		"initial_direction": -1.0,
		"patrol_range": 160.0,
		"run_speed": 80.0,
		"scale": Vector2.ONE,
		"health": 4,
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
		"death_duration": 2.0,
		"blocks_skill_damage": true,
		"notifies_death": false,
		"detector_offset": Vector2(100.0, 0.0),
	},
	{
		"name": "Elk",
		"scene": ELK_SCENE,
		"initial_direction": -1.0,
		"patrol_range": 160.0,
		"run_speed": 80.0,
		"scale": Vector2.ONE,
		"health": 3,
		"death_duration": 0.7,
		"blocks_skill_damage": false,
		"starts_with_shield": true,
		"notifies_death": false,
		"detector_offset": Vector2(-172.0, 0.0),
		"skill_animation": &"idle",
	},
	{
		"name": "BearKing",
		"scene": BEAR_KING_SCENE,
		"initial_direction": -1.0,
		"patrol_range": 160.0,
		"run_speed": 80.0,
		"scale": Vector2(1.5, 1.5),
		"health": 15,
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
		"death_duration": 2.0,
		"blocks_skill_damage": true,
		"notifies_death": true,
		"detector_offset": Vector2(-150.0, 0.0),
	},
]

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

	test_levels_keep_their_enemy_encounters()
	await test_initialization_patrol_limits_and_facing()
	await test_scaled_environment_wall_reversal()
	await test_skill_damage_policy()
	await test_death_presentation_and_cleanup()

	await fixture.process_frames(2)
	fixture.complete()


func test_initialization_patrol_limits_and_facing() -> void:
	var start_x := 0.0
	for example in ENEMY_EXAMPLES:
		var configured_enemy := harness.instantiate_enemy(example.scene, Vector2(start_x, 0.0))
		fixture.expect(
			configured_enemy.patrol_range == example.patrol_range,
			"%s keeps its scene-facing patrol range" % example.name
		)
		fixture.expect(
			configured_enemy.run_speed == example.run_speed,
			"%s keeps its scene-facing run speed" % example.name
		)
		fixture.expect(
			configured_enemy.idle_duration == 1.0,
			"%s keeps its scene-facing idle duration" % example.name
		)
		fixture.expect(
			configured_enemy.scale == example.scale,
			"%s keeps its scene-facing scale" % example.name
		)
		configured_enemy.queue_free()
		await fixture.process_frames(1)

		var enemy := harness.instantiate_enemy(
			example.scene,
			Vector2(start_x, 0.0),
			{"idle_duration": 0.15, "patrol_range": 20.0, "run_speed": 80.0}
		)
		var initial_x := enemy.global_position.x
		await fixture.wait_seconds(0.05)
		fixture.expect(
			enemy.is_in_group("enemies"),
			"%s initializes as an active Enemy" % example.name
		)
		fixture.expect(
			harness.enemy_has_body_collision(enemy),
			"%s initializes with body collision" % example.name
		)
		fixture.expect(
			harness.enemy_has_hurt_collision(enemy),
			"%s initializes with hurt collision" % example.name
		)
		fixture.expect(
			is_equal_approx(enemy.global_position.x, initial_x),
			"%s stays still for its configured idle" % example.name
		)
		fixture.expect(
			not harness.enemy_sprite_is_flipped(enemy),
			"%s visibly faces its initial patrol direction" % example.name
		)

		await fixture.wait_seconds(0.2)
		fixture.expect(
			(enemy.global_position.x - initial_x) * example.initial_direction > 0.0,
			"%s begins patrolling after idling" % example.name
		)

		await fixture.wait_seconds(0.45)
		var patrol_limit: float = initial_x + example.initial_direction * 20.0
		fixture.expect(
			absf(enemy.global_position.x - initial_x) <= 20.01,
			"%s stays within its configured patrol limits" % example.name
		)
		fixture.expect(
			(enemy.global_position.x - patrol_limit) * -example.initial_direction > 0.0,
			"%s reverses and continues from its patrol limit" % example.name
		)
		fixture.expect(
			harness.enemy_sprite_is_flipped(enemy),
			"%s visibly faces its reversed patrol direction" % example.name
		)

		enemy.queue_free()
		await fixture.process_frames(1)
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

	fixture.expect(
		enemy_count == expected_enemy_count,
		"%s keeps all existing packed Enemy encounters" % level_name
	)
	fixture.expect(
		boss_count == expected_boss_count,
		"%s keeps its existing boss Enemy encounter" % level_name
	)
	level.free()


func test_skill_damage_policy() -> void:
	var start_x := 10000.0
	for example in ENEMY_EXAMPLES:
		var enemy := harness.instantiate_enemy(
			example.scene,
			Vector2(start_x, 0.0),
			{"idle_duration": 10.0, "patrol_range": 1000.0}
		)
		var detector := harness.add_body(enemy.global_position + example.detector_offset)
		await fixture.physics_frames(3)
		detector.queue_free()
		var skill_x := enemy.global_position.x

		var weapon := harness.add_weapon(
			enemy.global_position + Vector2(-50.0, 0.0),
			Vector2(200.0, 200.0)
		)
		await fixture.physics_frames(2)
		weapon.queue_free()
		await fixture.process_frames(1)

		if example.blocks_skill_damage:
			var movement_x := enemy.global_position.x
			await fixture.physics_frames(6)
			fixture.expect(
				(enemy.global_position.x - movement_x) * example.initial_direction > 0.0,
				"%s keeps using its moving skill through weapon contact" % example.name
			)
			fixture.expect(
				enemy.call("get_current_health") == example.health,
				"%s moving skill rejects weapon damage" % example.name
			)
		else:
			fixture.expect(
				is_equal_approx(enemy.global_position.x, skill_x),
				"%s stationary skill ignores hurt knockback" % example.name
			)
			if example.get("starts_with_shield", false):
				fixture.expect(
					enemy.call("get_current_health") == example.health,
					"%s stationary skill consumes Shield before taking damage" % example.name
				)
			else:
				fixture.expect(
					enemy.call("get_current_health") == example.health - 1,
					"%s stationary skill accepts weapon damage" % example.name
				)
			fixture.expect(
				harness.is_playing(enemy, example.get("skill_animation", &"skill")),
				"%s keeps releasing its stationary skill after damage" % example.name
			)

		enemy.queue_free()
		await fixture.process_frames(1)
		start_x += 1500.0


func test_death_presentation_and_cleanup() -> void:
	var start_x := 17000.0
	for example in ENEMY_EXAMPLES:
		var enemy := harness.instantiate_enemy(
			example.scene,
			Vector2(start_x, 0.0),
			{"idle_duration": 10.0, "patrol_range": 1000.0}
		)
		var death_notification_count := [0]
		if example.notifies_death:
			enemy.connect(
				&"died",
				func() -> void: death_notification_count[0] += 1
			)
		if example.get("starts_with_shield", false):
			enemy.take_damage(1, Vector2.ZERO)
		enemy.take_damage(int(example.health), Vector2.ZERO)
		fixture.expect(
			not enemy.is_in_group("enemies"),
			"%s death immediately removes it from active Enemies" % example.name
		)
		if example.notifies_death:
			fixture.expect(
				death_notification_count[0] == 1,
				"%s publishes one boss death notification" % example.name
			)
		var death_start_texture := harness.enemy_sprite_texture(enemy)
		await fixture.physics_frames(1)
		fixture.expect(
			not harness.enemy_has_body_collision(enemy),
			"%s death disables body collision at the physics boundary" % example.name
		)
		fixture.expect(
			not harness.enemy_has_hurt_collision(enemy),
			"%s death disables hurt collision at the physics boundary" % example.name
		)

		await fixture.wait_seconds(example.death_duration * 0.6)
		fixture.expect(
			is_instance_valid(enemy),
			"%s remains during its death presentation" % example.name
		)
		fixture.expect(
			harness.enemy_sprite_texture(enemy) != death_start_texture,
			"%s visibly advances its death presentation" % example.name
		)
		await fixture.wait_seconds(example.death_duration * 0.55)
		fixture.expect(
			not is_instance_valid(enemy),
			"%s leaves after its death presentation" % example.name
		)
		if example.notifies_death:
			fixture.expect(
				death_notification_count[0] == 1,
				"%s boss death notification remains singular after cleanup" % example.name
			)
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

		await fixture.physics_frames(12)
		fixture.expect(
			(enemy.global_position.x - start_position.x) * initial_direction < 0.0,
			"Scaled %s reverses away from an environment wall" % example.name
		)
		fixture.expect(
			harness.enemy_sprite_is_flipped(enemy),
			"Scaled %s visibly faces away from the wall" % example.name
		)
		var turned_x := enemy.global_position.x
		await fixture.physics_frames(6)
		fixture.expect(
			(enemy.global_position.x - turned_x) * initial_direction < 0.0,
			"%s keeps patrolling after its wall reversal" % example.name
		)

		enemy.queue_free()
		wall.queue_free()
		await fixture.process_frames(1)
		start_x += 1000.0
