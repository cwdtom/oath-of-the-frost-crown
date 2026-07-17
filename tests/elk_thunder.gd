extends SceneTree


const ELK_SCENE := preload("res://enemies/elk.tscn")
const ELK_KING_SCENE := preload("res://enemies/elk_king.tscn")
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
	await test_shielded_damage_does_not_interrupt_elk_thunder()
	await test_elk_death_cancels_pending_thunder()
	await test_elk_resumes_patrol_and_keeps_its_cast_cooldown()
	await test_elk_shield_recovers_without_extending_its_cooldown()
	await test_elk_king_health_bar_follows_authoritative_health()
	await test_elk_king_defeat_publishes_one_notification_and_remains_level_owned()
	await test_elk_king_scene_reuses_elk_thunder()
	await test_elk_king_scene_reuses_elk_shield()

	fixture.complete()


func test_elk_king_health_bar_follows_authoritative_health() -> void:
	var elk_king := harness.instantiate_enemy(
		ELK_KING_SCENE,
		Vector2(16000.0, 0.0),
		{"idle_duration": 10.0, "patrol_range": 1000.0}
	)
	var health_bar := harness.enemy_health_bar(elk_king)

	await fixture.physics_frames(1)
	fixture.expect(elk_king.is_in_group("enemies"), "Elk King initializes as an active Enemy")
	fixture.expect(harness.enemy_has_body_collision(elk_king), "Elk King has body collision")
	fixture.expect(harness.enemy_has_hurt_collision(elk_king), "Elk King has hurt collision")
	fixture.expect(elk_king.get_maximum_health() == 10, "Elk King has ten maximum health")
	fixture.expect(elk_king.get_current_health() == 10, "Elk King starts at ten health")
	fixture.expect(health_bar != null, "Elk King presents Boss health")
	if health_bar != null:
		fixture.expect(health_bar.max_value == 10.0, "Elk King health bar has a ten-health maximum")
		fixture.expect(health_bar.value == 10.0, "Elk King health bar starts full")

	# Consume the Shield, then deliver an authoritative health change.
	elk_king.take_damage(1, Vector2.ZERO)
	elk_king.take_damage(1, Vector2.ZERO)
	fixture.expect(elk_king.get_current_health() == 9, "Elk King accepts damage after its Shield")
	if health_bar != null:
		fixture.expect(health_bar.value == 9.0, "Elk King health bar follows accepted damage")

	elk_king.queue_free()
	await fixture.process_frames(1)


func test_elk_king_defeat_publishes_one_notification_and_remains_level_owned() -> void:
	var elk_king := harness.instantiate_enemy(
		ELK_KING_SCENE,
		Vector2(16500.0, 0.0),
		{"idle_duration": 10.0, "patrol_range": 1000.0}
	)
	fixture.expect(elk_king.has_signal(&"died"), "Elk King exposes the Boss defeat contract")
	if not elk_king.has_signal(&"died"):
		elk_king.queue_free()
		await fixture.process_frames(1)
		return

	var death_notification_count := [0]
	elk_king.connect(&"died", func() -> void: death_notification_count[0] += 1)
	elk_king.take_damage(1, Vector2.ZERO)
	elk_king.take_damage(10, Vector2.ZERO)
	fixture.expect(elk_king.is_health_depleted(), "Elk King defeat follows authoritative health")
	fixture.expect(death_notification_count[0] == 1, "Elk King defeat publishes one notification")

	await fixture.wait_seconds(0.9)
	fixture.expect(
		is_instance_valid(elk_king) and not harness.is_playing(elk_king, &"dead"),
		"Elk King remains Level-owned without starting its death presentation"
	)
	fixture.expect(
		death_notification_count[0] == 1,
		"Elk King defeat notification remains singular while it is retained"
	)
	elk_king.queue_free()
	await fixture.process_frames(1)


func test_elk_king_scene_reuses_elk_thunder() -> void:
	var start_position := Vector2(17000.0, 0.0)
	var floor_body := harness.add_environment_wall(
		start_position + Vector2(0.0, 300.0),
		Vector2(2000.0, 20.0)
	)
	var detector_body := harness.add_body(start_position + Vector2(-170.0, 0.0))
	var elk_king := harness.instantiate_enemy(
		ELK_KING_SCENE,
		start_position,
		{"idle_duration": 10.0, "patrol_range": 1000.0}
	)
	var earthquake_cooldown := elk_king.get_node(
		"SkillDetect/EarthquakeSkill/Cooldown"
	) as Timer
	earthquake_cooldown.start()

	await fixture.physics_frames(4)
	await fixture.process_frames(1)
	var thunder := elk_king.get_node(
		"SkillDetect/ThunderSkill/Thunder"
	) as Area2D
	var thunder_animation_player := thunder.get_node("AnimationPlayer") as AnimationPlayer
	var strike_offset_x := thunder.global_position.x - start_position.x
	fixture.expect(thunder.top_level, "Elk King reuses Elk thunder world positioning")
	fixture.expect(
		strike_offset_x >= -312.0 and strike_offset_x <= -28.0,
		"Elk King reuses grounded random thunder inside its Skill Detection Area"
	)
	fixture.expect(
		absf(thunder.global_position.y - 86.0) <= 0.1,
		"Elk King grounds thunder against environment physics"
	)
	fixture.expect(
		is_equal_approx(elk_king.global_position.x, start_position.x),
		"Elk King reuses stationary Elk thunder casting"
	)
	fixture.expect(
		harness.is_playing(elk_king, &"idle"),
		"Elk King keeps its idle presentation during thunder"
	)

	await fixture.wait_seconds(3.1)
	fixture.expect(
		thunder_animation_player.is_playing(),
		"Elk King thunder uses its independently located three-second cooldown"
	)

	elk_king.queue_free()
	detector_body.queue_free()
	floor_body.queue_free()
	await fixture.process_frames(1)


func test_elk_king_scene_reuses_elk_shield() -> void:
	var elk_king := harness.instantiate_enemy(
		ELK_KING_SCENE,
		Vector2(20000.0, 0.0),
		{"idle_duration": 10.0, "patrol_range": 1000.0}
	)
	var shield := elk_king.get_node("ShieldSkill/Shield") as Area2D
	var starting_health: int = elk_king.get_current_health()
	var health_change_count := [0]
	elk_king.health_changed.connect(
		func(_current: int, _maximum: int) -> void: health_change_count[0] += 1
	)
	await fixture.process_frames(1)
	var position_before_hit := elk_king.global_position

	elk_king.take_damage(1, Vector2.RIGHT)
	fixture.expect(not shield.visible, "Elk King reuses the initially available Elk Shield")
	fixture.expect(
		elk_king.get_current_health() == starting_health,
		"Reused Elk Shield negates one positive damage event"
	)
	fixture.expect(elk_king.global_position == position_before_hit, "Elk King Shield prevents knockback")
	fixture.expect(health_change_count[0] == 0, "Elk King Shield publishes no health change")
	fixture.expect(
		harness.is_playing(elk_king, &"idle"),
		"Elk King Shield prevents a hurt presentation"
	)

	await fixture.wait_seconds(2.0)
	elk_king.take_damage(1, Vector2.ZERO)
	fixture.expect(elk_king.get_current_health() == 9, "Elk King takes damage during Shield cooldown")

	await fixture.wait_seconds(2.8)
	fixture.expect(not shield.visible, "Elk King Shield remains unavailable before five seconds")
	await fixture.wait_seconds(0.3)
	fixture.expect(shield.visible, "Elk King Shield recovers after five seconds")

	elk_king.queue_free()
	await fixture.process_frames(1)


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
	var thunder := elk.get_node("SkillDetect/Thunder") as Area2D
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


func test_shielded_damage_does_not_interrupt_elk_thunder() -> void:
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
	var thunder := elk.get_node("SkillDetect/Thunder") as Area2D
	var shield := elk.get_node("ShieldSkill/Shield") as Area2D
	player.global_position = thunder.global_position + Vector2(20.0, 0.0)
	detector_body.queue_free()
	await harness.deliver_hit(elk)
	fixture.expect(elk.get_current_health() == 3, "Elk Shield negates damage during thunder")
	fixture.expect(not shield.visible, "Negated damage consumes the Elk Shield")

	await fixture.wait_seconds(0.95)
	fixture.expect(hurt_event_count[0] == 1, "Shielded damage does not cancel Elk thunder")

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
	var thunder_animation_player := elk.get_node(
		"SkillDetect/Thunder/AnimationPlayer"
	) as AnimationPlayer
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
	var thunder := elk.get_node("SkillDetect/Thunder") as Area2D
	player.global_position = thunder.global_position + Vector2(20.0, 0.0)
	detector_body.queue_free()
	elk.take_damage(1, Vector2.ZERO)
	elk.take_damage(3, Vector2.ZERO)
	fixture.expect(
		elk.is_health_depleted(),
		"Damage after consuming Elk Shield depletes Elk during its cast"
	)

	await fixture.wait_seconds(1.1)
	fixture.expect(delayed_hurt_count[0] == 0, "Elk death cancels pending thunder")

	player.queue_free()
	floor_body.queue_free()
	await fixture.process_frames(1)


func test_elk_shield_recovers_without_extending_its_cooldown() -> void:
	var elk := harness.instantiate_enemy(
		ELK_SCENE,
		Vector2(14000.0, 0.0),
		{"idle_duration": 10.0, "patrol_range": 1000.0}
	)
	var shield := elk.get_node("ShieldSkill/Shield") as Area2D
	var health_change_count := [0]
	elk.health_changed.connect(
		func(_current: int, _maximum: int) -> void:
			health_change_count[0] += 1
	)
	var position_before_hit := elk.global_position

	elk.take_damage(1, Vector2.RIGHT)
	fixture.expect(not shield.visible, "Damage consumes the available Elk Shield")
	fixture.expect(elk.get_current_health() == 3, "Elk Shield negates the consumed hit")
	fixture.expect(elk.global_position == position_before_hit, "Elk Shield prevents hit knockback")
	fixture.expect(health_change_count[0] == 0, "Elk Shield publishes no health change")

	await fixture.wait_seconds(2.0)
	elk.take_damage(1, Vector2.ZERO)
	fixture.expect(elk.get_current_health() == 2, "Elk takes damage during Shield cooldown")

	await fixture.wait_seconds(2.8)
	fixture.expect(not shield.visible, "Elk Shield remains unavailable before five seconds")
	await fixture.wait_seconds(0.3)
	fixture.expect(shield.visible, "Elk Shield recovers after five seconds")

	elk.take_damage(1, Vector2.ZERO)
	fixture.expect(elk.get_current_health() == 2, "Recovered Elk Shield negates damage again")

	elk.queue_free()
	await fixture.process_frames(1)
