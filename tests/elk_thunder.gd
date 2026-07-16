extends SceneTree


const ELK_SCENE := preload("res://enemies/elk.tscn")
const EnemyHarness := preload("res://tests/enemy_scene_harness.gd")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")

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

	await test_elk_casts_grounded_thunder_within_its_detection_area()
	await test_nonlethal_damage_does_not_interrupt_elk_thunder()
	await test_elk_death_cancels_pending_thunder()
	await test_elk_resumes_patrol_and_keeps_its_cast_cooldown()

	fixture.complete()


func test_elk_casts_grounded_thunder_within_its_detection_area() -> void:
	var start_position := Vector2(2000.0, 0.0)
	var floor_body := harness.add_environment_wall(
		start_position + Vector2(0.0, 300.0),
		Vector2(2000.0, 20.0)
	)
	var detector_body := harness.add_body(start_position + Vector2(-172.0, 0.0))
	var elk := harness.instantiate_enemy(
		ELK_SCENE,
		start_position,
		{"idle_duration": 0.0, "patrol_range": 1000.0}
	)

	await fixture.physics_frames(4)
	await fixture.process_frames(1)
	var thunder := elk.get_node("Thunder") as Area2D
	var strike_offset_x := thunder.global_position.x - start_position.x
	fixture.expect(thunder.top_level, "Elk thunder keeps its selected world position")
	fixture.expect(
		strike_offset_x >= -314.0 and strike_offset_x <= -30.0,
		"Elk selects its thunder strike point inside its forward Skill Detection Area"
	)
	fixture.expect(
		absf(thunder.global_position.y - 86.0) <= 0.1,
		"Elk grounds thunder against environment physics"
	)
	fixture.expect(
		is_equal_approx(elk.global_position.x, start_position.x),
		"Elk remains stationary while casting thunder"
	)

	elk.queue_free()
	detector_body.queue_free()
	floor_body.queue_free()
	await fixture.process_frames(1)


func test_nonlethal_damage_does_not_interrupt_elk_thunder() -> void:
	var start_position := Vector2(5000.0, 0.0)
	var floor_body := harness.add_environment_wall(
		start_position + Vector2(0.0, 300.0),
		Vector2(2000.0, 20.0)
	)
	var hurt_event_count: Array[int] = [0]
	var player := harness.instantiate_passive_player(
		start_position + Vector2(900.0, 0.0),
		func() -> void: hurt_event_count[0] += 1
	)
	var detector_body := harness.add_body(start_position + Vector2(-172.0, 0.0))
	var elk := harness.instantiate_enemy(
		ELK_SCENE,
		start_position,
		{"idle_duration": 10.0, "patrol_range": 1000.0}
	)

	await fixture.physics_frames(3)
	await fixture.process_frames(1)
	var thunder := elk.get_node("Thunder") as Area2D
	player.global_position = thunder.global_position + Vector2(20.0, 0.0)
	detector_body.queue_free()
	await harness.deliver_hit(elk)
	fixture.expect(elk.get_current_health() == 2, "Elk accepts damage while casting thunder")

	await fixture.wait_seconds(0.95)
	fixture.expect(hurt_event_count[0] == 1, "Accepted damage does not cancel Elk thunder")

	elk.queue_free()
	player.queue_free()
	floor_body.queue_free()
	await fixture.process_frames(1)


func test_elk_resumes_patrol_and_keeps_its_cast_cooldown() -> void:
	var start_position := Vector2(11000.0, 0.0)
	var first_detector := harness.add_body(start_position + Vector2(-172.0, 0.0))
	var elk := harness.instantiate_enemy(
		ELK_SCENE,
		start_position,
		{"idle_duration": 0.0, "patrol_range": 1000.0}
	)

	await fixture.physics_frames(3)
	first_detector.queue_free()
	await fixture.wait_seconds(1.75)
	var resumed_x := elk.global_position.x
	await fixture.physics_frames(6)
	fixture.expect(elk.global_position.x < resumed_x, "Elk resumes its prior patrol after thunder")

	var cooldown_x := elk.global_position.x
	var cooldown_detector := harness.add_body(
		Vector2(cooldown_x - 172.0, elk.global_position.y)
	)
	await fixture.physics_frames(3)
	cooldown_detector.queue_free()
	await fixture.physics_frames(3)
	fixture.expect(elk.global_position.x < cooldown_x, "Elk cannot cast again during cooldown")

	await fixture.wait_seconds(3.1)
	var ready_detector := harness.add_body(elk.global_position + Vector2(-172.0, 0.0))
	await fixture.physics_frames(3)
	await fixture.process_frames(1)
	var thunder_animation_player := elk.get_node("Thunder/AnimationPlayer") as AnimationPlayer
	fixture.expect(
		thunder_animation_player.is_playing(),
		"Elk can cast again after its five-second cooldown"
	)

	elk.queue_free()
	ready_detector.queue_free()
	await fixture.process_frames(1)


func test_elk_death_cancels_pending_thunder() -> void:
	var start_position := Vector2(8000.0, 0.0)
	var floor_body := harness.add_environment_wall(
		start_position + Vector2(0.0, 300.0),
		Vector2(2000.0, 20.0)
	)
	var delayed_hurt_count: Array[int] = [0]
	var player := harness.instantiate_passive_player(
		start_position + Vector2(900.0, 0.0),
		func() -> void: delayed_hurt_count[0] += 1
	)
	var detector_body := harness.add_body(start_position + Vector2(-172.0, 0.0))
	var elk := harness.instantiate_enemy(
		ELK_SCENE,
		start_position,
		{"idle_duration": 10.0, "patrol_range": 1000.0}
	)

	await fixture.physics_frames(3)
	await fixture.process_frames(1)
	var thunder := elk.get_node("Thunder") as Area2D
	player.global_position = thunder.global_position + Vector2(20.0, 0.0)
	detector_body.queue_free()
	elk.take_damage(3, Vector2.ZERO)
	fixture.expect(elk.is_health_depleted(), "Lethal damage depletes Elk during its cast")

	await fixture.wait_seconds(1.1)
	fixture.expect(delayed_hurt_count[0] == 0, "Elk death cancels pending thunder")

	player.queue_free()
	floor_body.queue_free()
	await fixture.process_frames(1)
