extends SceneTree


const WOLF_SCENE := preload("res://enemies/wolf.tscn")
const EnemyHarness := preload("res://tests/enemy_scene_harness.gd")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const DASH_DISTANCE := 300.0
const SKILL_ANIMATION := &"skill"

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

	await test_player_contact_damage()
	await test_dash_distance_reentry_and_cooldown()
	await test_dash_collision_and_weapon_immunity()

	fixture.complete(false)
	await fixture.process_frames(2)
	await fixture.wait_seconds(0.1)
	fixture.complete()


func test_player_contact_damage() -> void:
	var wolf_position := Vector2(1500.0, 0.0)
	var wolf := harness.instantiate_enemy(
		WOLF_SCENE,
		wolf_position,
		{"idle_duration": 10.0}
	)
	var player_start := wolf_position + Vector2(-65.0, 0.0)
	var player := harness.instantiate_actor(
		preload("res://player/player.tscn"),
		player_start
	)
	var hurt_event_count: Array[int] = [0]
	player.connect(&"hurt_taken", func() -> void: hurt_event_count[0] += 1)
	player.velocity = Vector2(600.0, 0.0)

	await fixture.physics_frames(2)
	fixture.expect(
		hurt_event_count[0] == 1,
		"Player contact with an Enemy deals one point of damage"
	)
	fixture.expect(player.get_current_health() == 4, "Enemy contact crosses the actor damage seam")
	fixture.expect(
		player.global_position.x < player_start.x - 90.0,
		"Enemy contact keeps Player knockback"
	)

	wolf.queue_free()
	player.queue_free()
	await fixture.process_frames(1)


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

	await fixture.physics_frames(3)
	fixture.expect(wolf.global_position.x > start_position.x, "Gameplay detection starts Wolf dash")
	fixture.expect(
		harness.is_playing(wolf, SKILL_ANIMATION),
		"Wolf dash starts its skill presentation"
	)
	player.position = start_position - Vector2(1000.0, 0.0)
	var speed_sample_x := wolf.global_position.x
	await fixture.physics_frames(6)
	fixture.expect(
		absf(wolf.global_position.x - speed_sample_x - 40.0) <= 1.0,
		"Wolf keeps its 400 pixel per second dash speed"
	)
	player.position = wolf.global_position + Vector2(350.0, 0.0)
	await fixture.physics_frames(2)
	player.position = start_position - Vector2(1000.0, 0.0)
	await fixture.wait_seconds(0.65)
	fixture.expect(
		is_equal_approx(wolf.global_position.x, start_position.x + DASH_DISTANCE),
		"Repeated detection cannot restart Wolf's configured 300 pixel dash"
	)
	var dash_end_x := wolf.global_position.x
	await fixture.wait_seconds(0.15)
	fixture.expect(
		is_equal_approx(wolf.global_position.x, dash_end_x),
		"Wolf returns to its prior idle behavior after the dash"
	)

	await harness.reenter_skill_detection(player, wolf.global_position + Vector2(100.0, 0.0))
	await fixture.wait_seconds(0.15)
	fixture.expect(
		is_equal_approx(wolf.global_position.x, dash_end_x),
		"Wolf cannot restart its dash during cooldown"
	)
	await fixture.wait_seconds(3.4)
	await harness.reenter_skill_detection(player, wolf.global_position + Vector2(100.0, 0.0))
	await fixture.wait_seconds(0.1)
	fixture.expect(
		is_equal_approx(wolf.global_position.x, dash_end_x),
		"Wolf keeps the full five second dash cooldown"
	)
	await fixture.wait_seconds(0.4)
	await harness.reenter_skill_detection(player, wolf.global_position + Vector2(100.0, 0.0))
	await fixture.physics_frames(3)
	fixture.expect(wolf.global_position.x > dash_end_x, "Wolf can dash again after cooldown expires")
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
	await fixture.physics_frames(3)

	var early_weapon := harness.add_weapon(wolf.global_position)
	await fixture.physics_frames(3)
	early_weapon.queue_free()
	await fixture.wait_seconds(0.5)
	var late_weapon := harness.add_weapon(wolf.global_position)
	await fixture.physics_frames(3)
	late_weapon.queue_free()
	await fixture.wait_seconds(0.25)

	fixture.expect(hurt_event_count[0] == 1, "One Wolf dash collision damages Player once")
	fixture.expect(
		player.global_position.x > player_start.x,
		"Wolf dash knocks Player away from collision"
	)
	await harness.deliver_hit(wolf, Vector2(-20.0, 0.0))
	fixture.expect(
		wolf.is_in_group("enemies"),
		"Wolf dash weapon immunity preserves both hits until damage is accepted afterward"
	)
