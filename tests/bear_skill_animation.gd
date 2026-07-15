extends SceneTree


const BEAR_SCENE := preload("res://enemies/bear.tscn")
const EnemyHarness := preload("res://tests/enemy_scene_harness.gd")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const HURT_ANIMATION := &"hurt"
const SKILL_ANIMATION := &"skill"
const EARTHQUAKE_CAST_ANIMATION := &"cast"

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

	await test_earthquake_activation_and_cooldown()
	await test_earthquake_damage_interruption()
	await test_death_cancels_earthquake()

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


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

	await fixture.physics_frames(3)
	await fixture.wait_seconds(0.05)
	fixture.expect(
		harness.is_playing(bear, SKILL_ANIMATION),
		"Gameplay detection starts Bear earthquake"
	)
	fixture.expect(
		harness.is_playing(bear, EARTHQUAKE_CAST_ANIMATION),
		"Earthquake cast starts with Bear skill"
	)
	fixture.expect(
		absf(
			harness.animation_position(bear, SKILL_ANIMATION)
			- harness.animation_position(bear, EARTHQUAKE_CAST_ANIMATION)
		) < 0.1,
		"Bear and earthquake presentations begin in sync"
	)
	fixture.expect(is_equal_approx(bear.velocity.x, 0.0), "Bear remains stationary during earthquake")
	var skill_start_x := bear.global_position.x

	await fixture.wait_seconds(0.2)
	var skill_position_before_repeat := harness.animation_position(bear, SKILL_ANIMATION)
	var cast_position_before_repeat := harness.animation_position(bear, EARTHQUAKE_CAST_ANIMATION)
	player.position += Vector2(400.0, 0.0)
	await fixture.physics_frames(2)
	player.position -= Vector2(400.0, 0.0)
	await fixture.physics_frames(2)
	await fixture.wait_seconds(0.05)
	fixture.expect(
		harness.animation_position(bear, SKILL_ANIMATION) > skill_position_before_repeat,
		"Repeated detection does not restart Bear skill presentation"
	)
	fixture.expect(
		harness.animation_position(bear, EARTHQUAKE_CAST_ANIMATION) > cast_position_before_repeat,
		"Repeated detection does not restart earthquake presentation"
	)

	await fixture.wait_seconds(0.5)
	await fixture.physics_frames(1)
	fixture.expect(hurt_event_count[0] == 1, "One earthquake activation damages its target once")
	await fixture.wait_seconds(0.25)
	fixture.expect(
		not harness.is_playing(bear, SKILL_ANIMATION),
		"Earthquake completes after one activation"
	)
	fixture.expect(
		is_equal_approx(bear.global_position.x, skill_start_x),
		"Bear does not move during earthquake"
	)

	await harness.reenter_skill_detection(player, bear_position + Vector2(-152.0, 42.5))
	fixture.expect(
		not harness.is_playing(bear, SKILL_ANIMATION),
		"Bear cannot restart earthquake during cooldown"
	)
	await fixture.wait_seconds(3.2)
	await harness.reenter_skill_detection(player, bear_position + Vector2(-152.0, 42.5))
	fixture.expect(
		not harness.is_playing(bear, SKILL_ANIMATION),
		"Bear keeps the full five second skill cooldown"
	)
	await fixture.wait_seconds(0.55)
	await harness.reenter_skill_detection(player, bear_position + Vector2(-152.0, 42.5))
	fixture.expect(
		harness.is_playing(bear, SKILL_ANIMATION),
		"Bear can use earthquake after cooldown expires"
	)
	await fixture.wait_seconds(1.0)


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
	await fixture.physics_frames(3)
	await fixture.wait_seconds(0.05)
	fixture.expect(
		harness.is_playing(bear, SKILL_ANIMATION),
		"Bear starts earthquake for an entering gameplay body"
	)

	var weapon := harness.add_weapon(bear_position)
	await fixture.physics_frames(3)
	await fixture.process_frames(1)
	fixture.expect(
		harness.is_playing(bear, HURT_ANIMATION),
		"Accepted damage visibly interrupts earthquake"
	)
	fixture.expect(
		not harness.is_playing(bear, EARTHQUAKE_CAST_ANIMATION),
		"Hurt stops the earthquake cast"
	)
	weapon.queue_free()
	await fixture.wait_seconds(0.65)
	fixture.expect(
		hurt_event_count[0] == 0,
		"Interrupted earthquake never reaches its damaging impact"
	)
	fixture.expect(
		not harness.is_playing(bear, SKILL_ANIMATION),
		"Interrupted earthquake does not resume after hurt"
	)


func test_death_cancels_earthquake() -> void:
	var bear_position := Vector2(7000.0, 0.0)
	var bear := harness.instantiate_enemy(
		BEAR_SCENE,
		bear_position,
		{"idle_duration": 10.0}
	)
	for accepted_hit in 3:
		await harness.deliver_hit(bear)
		if accepted_hit < 2:
			await fixture.wait_seconds(0.4)

	await fixture.wait_seconds(0.4)
	var hurt_event_count: Array[int] = [0]
	harness.instantiate_passive_player(
		bear.global_position + Vector2(-152.0, 42.5),
		func() -> void: hurt_event_count[0] += 1
	)
	await fixture.physics_frames(3)
	await fixture.wait_seconds(0.05)
	fixture.expect(
		harness.is_playing(bear, SKILL_ANIMATION),
		"Bear starts earthquake before lethal damage"
	)

	await harness.deliver_hit(bear)
	fixture.expect(
		not harness.is_playing(bear, EARTHQUAKE_CAST_ANIMATION),
		"Death stops the earthquake cast"
	)
	await fixture.wait_seconds(0.65)
	fixture.expect(hurt_event_count[0] == 0, "Death prevents the pending earthquake impact")
