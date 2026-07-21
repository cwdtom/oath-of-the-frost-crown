extends SceneTree


const ELK_KING_SCENE := preload("res://enemies/elk_king.tscn")
const EnemyHarness := preload("res://tests/enemy_scene_harness.gd")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")


class DamageRecorder:
	extends DamageableActor

	var damage_event_count := 0
	var damage_total := 0

	func take_damage(amount: int, _knockback_direction: Vector2) -> void:
		damage_event_count += 1
		damage_total += amount


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

	await test_reentry_restarts_completed_earthquake_safely()
	await test_concurrent_casts_share_one_stationary_presentation_window()
	await test_range_exit_and_damage_keep_concurrent_casts_stable()
	await test_cooldowns_retrigger_independently_during_persistent_presence()
	await test_packed_thunder_cast_delivers_one_damage()
	await test_packed_earthquake_cast_delivers_one_damage()
	await test_concurrent_casts_deliver_two_independent_damage_events()
	await test_defeat_preserves_pending_thunder_until_explicit_presentation()
	await test_defeat_preserves_thunder_committed_before_deferred_start()
	await test_defeat_preserves_earthquake_without_starting_another_cast()

	fixture.complete()


func test_reentry_restarts_completed_earthquake_safely() -> void:
	var elk_king := harness.instantiate_enemy(
		ELK_KING_SCENE,
		Vector2(1000.0, 0.0),
		{"idle_duration": 10.0, "patrol_range": 1000.0}
	)
	var thunder_cooldown := elk_king.get_node(
		"SkillDetect/ThunderSkill/Cooldown"
	) as Timer
	thunder_cooldown.start()
	var detector_shape := elk_king.get_node(
		"SkillDetect/CollisionShape2D"
	) as CollisionShape2D
	var earthquake_animation := elk_king.get_node(
		"SkillDetect/EarthquakeSkill/Earthquake/AnimationPlayer"
	) as AnimationPlayer
	var detector_body := harness.add_body(detector_shape.global_position)
	await fixture.physics_frames(3)
	fixture.expect(
		earthquake_animation.is_playing(),
		"Elk King begins an earthquake before the Player exits"
	)
	detector_body.position += Vector2(400.0, 0.0)
	await fixture.physics_frames(2)
	await fixture.wait_seconds(1.05)
	fixture.expect(
		not earthquake_animation.is_playing(),
		"The first earthquake finishes before the Player re-enters"
	)

	var earthquake_cooldown := elk_king.get_node(
		"SkillDetect/EarthquakeSkill/Cooldown"
	) as Timer
	earthquake_cooldown.stop()
	detector_body.position = detector_shape.global_position
	await fixture.physics_frames(2)
	await fixture.wait_seconds(0.05)
	fixture.expect(
		earthquake_animation.is_playing()
		and earthquake_animation.current_animation == &"cast",
		"Elk King safely restarts a completed earthquake when the Player re-enters"
	)
	await fixture.wait_seconds(1.05)

	elk_king.queue_free()
	detector_body.queue_free()
	await fixture.process_frames(1)


func add_damage_recorder(position: Vector2, size := Vector2(20.0, 20.0)) -> DamageRecorder:
	var target := DamageRecorder.new()
	target.collision_layer = EnemyHarness.PLAYER_COLLISION_LAYER
	target.collision_mask = 0
	var target_collision := CollisionShape2D.new()
	var target_shape := RectangleShape2D.new()
	target_shape.size = size
	target_collision.shape = target_shape
	target.add_child(target_collision)
	target.global_position = position
	fixture.add_node(target, harness.world)
	return target


func test_concurrent_casts_share_one_stationary_presentation_window() -> void:
	var start_position := Vector2(2000.0, 0.0)
	var elk_king := harness.instantiate_enemy(
		ELK_KING_SCENE,
		start_position,
		{"idle_duration": 0.0, "patrol_range": 1000.0}
	)
	await fixture.physics_frames(4)
	var patrol_direction := signf(elk_king.velocity.x)
	fixture.expect(patrol_direction != 0.0, "Elk King patrols before its Casting Window")

	var detector_shape := elk_king.get_node(
		"SkillDetect/CollisionShape2D"
	) as CollisionShape2D
	var detector_body := harness.add_body(detector_shape.global_position)
	await fixture.physics_frames(3)
	await fixture.process_frames(2)

	var earthquake := elk_king.get_node(
		"SkillDetect/EarthquakeSkill/Earthquake"
	) as Area2D
	var earthquake_animation := earthquake.get_node("AnimationPlayer") as AnimationPlayer
	var thunder_animation := elk_king.get_node(
		"SkillDetect/ThunderSkill/Thunder/AnimationPlayer"
	) as AnimationPlayer
	var cast_position := elk_king.global_position

	fixture.expect(
		thunder_animation.is_playing() and thunder_animation.current_animation == &"cast",
		"Elk King starts thunder when it is ready"
	)
	fixture.expect(
		earthquake_animation.is_playing()
		and earthquake_animation.current_animation == &"cast",
		"Elk King starts earthquake independently when it is ready"
	)
	fixture.expect(
		harness.is_playing(elk_king, &"skill"),
		"Earthquake gives the Elk King body skill presentation priority"
	)
	fixture.expect(
		earthquake_animation.is_playing()
		and harness.animation_position(elk_king, &"skill") >= 0.0
		and absf(
			harness.animation_position(elk_king, &"skill")
			- earthquake_animation.current_animation_position
		) <= 0.1,
		"Elk King body skill and earthquake effect presentations begin together"
	)
	fixture.expect(
		(earthquake.global_position.x - elk_king.global_position.x) * patrol_direction > 0.0,
		"Elk King releases earthquake on its facing side"
	)

	await fixture.wait_seconds(0.75)
	await fixture.process_frames(2)
	fixture.expect(
		is_equal_approx(elk_king.global_position.x, cast_position.x),
		"Elk King remains stationary while concurrent casts are active"
	)
	fixture.expect(
		thunder_animation.is_playing() and earthquake_animation.is_playing(),
		"Thunder and earthquake remain active concurrently"
	)
	fixture.expect(
		harness.is_playing(elk_king, &"idle"),
		"Continuing thunder uses stationary idle after earthquake body presentation"
	)

	await fixture.wait_seconds(1.1)
	fixture.expect(
		(elk_king.global_position.x - cast_position.x) * patrol_direction > 0.0,
		"Elk King restores its pre-cast patrol after the final cast finishes"
	)

	elk_king.queue_free()
	detector_body.queue_free()
	await fixture.process_frames(1)


func test_range_exit_and_damage_keep_concurrent_casts_stable() -> void:
	var start_position := Vector2(12000.0, 0.0)
	var elk_king := harness.instantiate_enemy(
		ELK_KING_SCENE,
		start_position,
		{"idle_duration": 0.0, "patrol_range": 1000.0}
	)
	await fixture.physics_frames(4)
	var patrol_direction := signf(elk_king.velocity.x)
	var detector_shape := elk_king.get_node(
		"SkillDetect/CollisionShape2D"
	) as CollisionShape2D
	var detector_body := harness.add_body(detector_shape.global_position)
	await fixture.physics_frames(3)
	await fixture.process_frames(2)

	var thunder := elk_king.get_node(
		"SkillDetect/ThunderSkill/Thunder"
	) as Area2D
	var thunder_animation := thunder.get_node("AnimationPlayer") as AnimationPlayer
	var earthquake := elk_king.get_node(
		"SkillDetect/EarthquakeSkill/Earthquake"
	) as Area2D
	var earthquake_animation := earthquake.get_node("AnimationPlayer") as AnimationPlayer
	var shield := elk_king.get_node("ShieldSkill/Shield") as Area2D
	var shield_animation_player := shield.get_node("AnimationPlayer") as AnimationPlayer
	var break_duration := shield_animation_player.get_animation("break").length
	var thunder_restarts := [0]
	var earthquake_restarts := [0]
	thunder_animation.animation_started.connect(
		func(animation_name: StringName) -> void:
			if animation_name == &"cast":
				thunder_restarts[0] += 1
	)
	earthquake_animation.animation_started.connect(
		func(animation_name: StringName) -> void:
			if animation_name == &"cast":
				earthquake_restarts[0] += 1
	)
	var cast_position := elk_king.global_position
	var thunder_position := thunder.global_position
	var earthquake_position := earthquake.global_position
	var starting_health: int = elk_king.get_current_health()

	detector_body.queue_free()
	await fixture.physics_frames(2)
	elk_king.take_damage(1, Vector2.ZERO)
	fixture.expect(
		shield.visible and shield_animation_player.current_animation == &"break",
		"Casting Elk Shield enters its Shield Break Window"
	)
	fixture.expect(
		elk_king.get_current_health() == starting_health,
		"Casting Elk Shield prevents an authoritative health change"
	)
	fixture.expect(
		harness.is_playing(elk_king, &"skill"),
		"Shielded damage preserves the earthquake body presentation"
	)

	await fixture.wait_seconds(0.1)
	elk_king.take_damage(1, Vector2.ZERO)
	fixture.expect(
		elk_king.get_current_health() == starting_health,
		"Casting Elk Shield rejects damage during its Shield Break Window"
	)
	await fixture.wait_seconds(
		break_duration - shield_animation_player.current_animation_position + 0.1
	)
	elk_king.take_damage(1, Vector2.ZERO)
	fixture.expect(
		elk_king.get_current_health() == starting_health - 1,
		"Unshielded casting damage reduces authoritative health"
	)
	fixture.expect(
		is_equal_approx(elk_king.global_position.x, cast_position.x),
		"Unshielded casting damage applies no knockback"
	)
	await fixture.process_frames(2)
	fixture.expect(
		thunder_animation.is_playing() and earthquake_animation.is_playing(),
		"Range exit and damage do not shorten either active cast"
	)
	fixture.expect(
		harness.is_playing(elk_king, &"skill"),
		"Unshielded damage does not replace earthquake presentation with hurt"
	)
	fixture.expect(
		is_equal_approx(elk_king.global_position.x, cast_position.x),
		"Elk King stays movement-locked while both damaged casts remain active"
	)
	fixture.expect(
		thunder.global_position == thunder_position
		and earthquake.global_position == earthquake_position,
		"Range exit and damage do not retarget active casts"
	)
	fixture.expect(
		thunder_restarts[0] == 0 and earthquake_restarts[0] == 0,
		"Range exit and damage do not restart active casts"
	)

	var earthquake_time_left := (
		earthquake_animation.get_animation(&"cast").length
		- earthquake_animation.current_animation_position
	)
	await fixture.wait_seconds(maxf(earthquake_time_left - 0.08, 0.0))
	fixture.expect(
		earthquake_animation.is_playing(),
		"Range exit and damage preserve the packed earthquake cast duration"
	)
	await fixture.wait_seconds(0.12)
	fixture.expect(
		thunder_animation.is_playing() and not earthquake_animation.is_playing(),
		"Earthquake finishing does not cancel continuing thunder after damage"
	)
	fixture.expect(
		harness.is_playing(elk_king, &"idle"),
		"Damaged Elk King returns to stationary idle while thunder continues"
	)
	fixture.expect(
		is_equal_approx(elk_king.global_position.x, cast_position.x),
		"One skill finishing does not release the damaged Casting Window"
	)

	var thunder_time_left := (
		thunder_animation.get_animation(&"cast").length
		- thunder_animation.current_animation_position
	)
	await fixture.wait_seconds(maxf(thunder_time_left - 0.08, 0.0))
	fixture.expect(
		thunder_animation.is_playing(),
		"Range exit and damage preserve the packed thunder cast duration"
	)
	fixture.expect(
		is_equal_approx(elk_king.global_position.x, cast_position.x),
		"Elk King remains movement-locked through the full thunder duration"
	)
	await fixture.wait_seconds(0.12)
	fixture.expect(
		(elk_king.global_position.x - cast_position.x) * patrol_direction > 0.0,
		"Elk King restores patrol only after the final damaged cast finishes"
	)

	elk_king.queue_free()
	await fixture.process_frames(1)


func test_packed_earthquake_cast_delivers_one_damage() -> void:
	var start_position := Vector2(9000.0, 0.0)
	var target := add_damage_recorder(
		start_position + Vector2(900.0, 0.0)
	)
	var elk_king := harness.instantiate_enemy(
		ELK_KING_SCENE,
		start_position,
		{"idle_duration": 10.0, "patrol_range": 1000.0}
	)
	var detector_shape := elk_king.get_node(
		"SkillDetect/CollisionShape2D"
	) as CollisionShape2D
	var detector_body := harness.add_body(detector_shape.global_position)
	await fixture.physics_frames(3)
	await fixture.process_frames(1)

	var earthquake := elk_king.get_node(
		"SkillDetect/EarthquakeSkill/Earthquake"
	) as Area2D
	target.global_position = earthquake.global_position
	await fixture.wait_seconds(0.78)
	fixture.expect(
		target.damage_event_count == 1 and target.damage_total == 1,
		"One Elk King cast delivers one damage through its packed earthquake effect"
	)
	target.global_position = start_position + Vector2(900.0, 0.0)
	await fixture.physics_frames(1)
	target.global_position = earthquake.global_position
	await fixture.physics_frames(1)
	fixture.expect(
		target.damage_event_count == 1 and target.damage_total == 1,
		"One Elk King earthquake cannot damage the same target twice after re-entry"
	)
	await fixture.wait_seconds(0.2)

	elk_king.queue_free()
	detector_body.queue_free()
	target.queue_free()
	await fixture.process_frames(1)


func test_packed_thunder_cast_delivers_one_damage() -> void:
	var start_position := Vector2(15000.0, 0.0)
	var target := add_damage_recorder(
		start_position + Vector2(900.0, 0.0)
	)
	var elk_king := harness.instantiate_enemy(
		ELK_KING_SCENE,
		start_position,
		{"idle_duration": 10.0, "patrol_range": 1000.0}
	)
	var earthquake_cooldown := elk_king.get_node(
		"SkillDetect/EarthquakeSkill/Cooldown"
	) as Timer
	earthquake_cooldown.start()
	var detector_shape := elk_king.get_node(
		"SkillDetect/CollisionShape2D"
	) as CollisionShape2D
	var detector_body := harness.add_body(detector_shape.global_position)
	await fixture.physics_frames(3)
	await fixture.process_frames(1)

	var thunder := elk_king.get_node(
		"SkillDetect/ThunderSkill/Thunder"
	) as Area2D
	target.global_position = thunder.global_position
	await fixture.wait_seconds(1.05)
	fixture.expect(
		target.damage_event_count == 1 and target.damage_total == 1,
		"One Elk King cast delivers one damage through its packed thunder effect"
	)
	target.global_position = start_position + Vector2(900.0, 0.0)
	await fixture.physics_frames(1)
	target.global_position = thunder.global_position
	await fixture.physics_frames(1)
	fixture.expect(
		target.damage_event_count == 1 and target.damage_total == 1,
		"One Elk King thunder cannot damage the same target twice after re-entry"
	)
	await fixture.wait_seconds(0.6)

	elk_king.queue_free()
	detector_body.queue_free()
	target.queue_free()
	await fixture.process_frames(1)


func test_concurrent_casts_deliver_two_independent_damage_events() -> void:
	var start_position := Vector2(18000.0, 0.0)
	var elk_king := harness.instantiate_enemy(
		ELK_KING_SCENE,
		start_position,
		{"idle_duration": 10.0, "patrol_range": 1000.0}
	)
	var detector_shape := elk_king.get_node(
		"SkillDetect/CollisionShape2D"
	) as CollisionShape2D
	var target := add_damage_recorder(
		detector_shape.global_position,
		Vector2(400.0, 600.0)
	)
	await fixture.physics_frames(3)
	await fixture.process_frames(1)

	await fixture.wait_seconds(0.78)
	fixture.expect(
		target.damage_event_count == 1 and target.damage_total == 1,
		"Concurrent earthquake resolves its own one-damage event"
	)
	await fixture.wait_seconds(0.32)
	fixture.expect(
		target.damage_event_count == 2 and target.damage_total == 2,
		"Concurrent thunder resolves independently for exactly two total damage"
	)
	await fixture.wait_seconds(0.65)

	elk_king.queue_free()
	target.queue_free()
	await fixture.process_frames(1)


func test_defeat_preserves_pending_thunder_until_explicit_presentation() -> void:
	var start_position := Vector2(21000.0, 0.0)
	var elk_king := harness.instantiate_enemy(
		ELK_KING_SCENE,
		start_position,
		{"idle_duration": 10.0, "patrol_range": 1000.0}
	)
	var earthquake_cooldown := elk_king.get_node(
		"SkillDetect/EarthquakeSkill/Cooldown"
	) as Timer
	earthquake_cooldown.start()
	var detector_shape := elk_king.get_node(
		"SkillDetect/CollisionShape2D"
	) as CollisionShape2D
	var detector_body := harness.add_body(detector_shape.global_position)
	await fixture.physics_frames(3)
	await fixture.process_frames(1)

	var thunder := elk_king.get_node(
		"SkillDetect/ThunderSkill/Thunder"
	) as Area2D
	var thunder_animation := thunder.get_node("AnimationPlayer") as AnimationPlayer
	var target := add_damage_recorder(thunder.global_position)
	var death_notification_count := [0]
	elk_king.died.connect(
		func() -> void: death_notification_count[0] += 1
	)
	fixture.expect(
		thunder_animation.is_playing()
		and thunder_animation.current_animation == &"cast",
		"Elk King begins thunder before Defeat"
	)
	elk_king.turn_around()
	fixture.expect(
		harness.enemy_sprite_is_flipped(elk_king),
		"Elk King faces right before Defeat"
	)

	await deplete_elk_king(elk_king)
	fixture.expect(
		not elk_king.is_in_group("enemies"),
		"Elk King Defeat immediately removes it from active Enemies"
	)
	fixture.expect(
		death_notification_count[0] == 1,
		"Elk King Defeat immediately publishes one notification"
	)
	fixture.expect(
		elk_king.velocity == Vector2.ZERO
		and not harness.enemy_sprite_is_flipped(elk_king),
		"Elk King Defeat immediately stops movement and forces it to face left"
	)
	await fixture.process_frames(1)
	fixture.expect(
		not harness.is_playing(elk_king, &"dead"),
		"Elk King Defeat waits for an explicit death-presentation request"
	)
	await fixture.physics_frames(2)
	fixture.expect(
		not harness.enemy_has_body_collision(elk_king)
		and not harness.enemy_has_hurt_collision(elk_king),
		"Elk King Defeat disables body and hurt collisions"
	)
	elk_king.take_damage(elk_king.get_maximum_health(), Vector2.ZERO)
	fixture.expect(
		death_notification_count[0] == 1,
		"Repeated damage does not duplicate the Elk King Defeat notification"
	)

	await fixture.wait_seconds(
		maxf(0.95 - thunder_animation.current_animation_position, 0.01)
	)
	fixture.expect(
		is_instance_valid(elk_king),
		"Elk King remains Level-owned while its pending thunder continues"
	)
	if is_instance_valid(elk_king):
		fixture.expect(
			thunder_animation.is_playing(),
			"Pending thunder presentation continues independently after Elk King Defeat"
		)
	fixture.expect(
		target.damage_event_count == 0,
		"Pending thunder has not damaged its target before impact"
	)

	await fixture.wait_seconds(0.15)
	fixture.expect(
		target.damage_event_count == 1 and target.damage_total == 1,
		"Pending thunder resolves one damage after Elk King Defeat"
	)
	await fixture.wait_seconds(0.7)
	fixture.expect(
		is_instance_valid(elk_king) and not thunder_animation.is_playing(),
		"Elk King remains valid after its pending thunder presentation finishes"
	)

	elk_king.request_death_presentation()
	await fixture.process_frames(2)
	fixture.expect(
		harness.is_playing(elk_king, &"dead"),
		"One explicit request starts the Elk King death presentation"
	)
	await fixture.wait_seconds(0.2)
	var presentation_position := harness.animation_position(elk_king, &"dead")
	elk_king.request_death_presentation()
	await fixture.process_frames(2)
	fixture.expect(
		harness.animation_position(elk_king, &"dead") >= presentation_position,
		"Repeated requests do not restart or duplicate the death presentation"
	)
	await fixture.wait_seconds(6.0)
	fixture.expect(
		is_instance_valid(elk_king),
		"Elk King remains Level-owned after its death presentation finishes"
	)
	fixture.expect(
		death_notification_count[0] == 1,
		"Presentation requests do not duplicate the Elk King Defeat notification"
	)

	elk_king.queue_free()
	detector_body.queue_free()
	target.queue_free()
	await fixture.process_frames(1)


func test_defeat_preserves_thunder_committed_before_deferred_start() -> void:
	var start_position := Vector2(22500.0, 0.0)
	var elk_king := harness.instantiate_enemy(
		ELK_KING_SCENE,
		start_position,
		{"idle_duration": 10.0, "patrol_range": 1000.0}
	)
	var thunder_cooldown := elk_king.get_node(
		"SkillDetect/ThunderSkill/Cooldown"
	) as Timer
	var earthquake_cooldown := elk_king.get_node(
		"SkillDetect/EarthquakeSkill/Cooldown"
	) as Timer
	thunder_cooldown.start()
	earthquake_cooldown.start()
	var detector_shape := elk_king.get_node(
		"SkillDetect/CollisionShape2D"
	) as CollisionShape2D
	var detector_body := harness.add_body(detector_shape.global_position)
	await fixture.physics_frames(2)
	var thunder := elk_king.get_node(
		"SkillDetect/ThunderSkill/Thunder"
	) as Area2D
	var thunder_animation := thunder.get_node("AnimationPlayer") as AnimationPlayer

	thunder_cooldown.stop()
	thunder_cooldown.timeout.emit()
	fixture.expect(
		not thunder_animation.is_playing(),
		"Elk King commits thunder before its deferred effect presentation starts"
	)
	await deplete_elk_king(elk_king)
	await fixture.process_frames(1)
	fixture.expect(
		thunder_animation.is_playing()
		and thunder_animation.current_animation == &"cast",
		"Committed thunder continues its effect presentation after Elk King Defeat"
	)
	var target := add_damage_recorder(thunder.global_position)

	await fixture.wait_seconds(
		maxf(1.05 - thunder_animation.current_animation_position, 0.01)
	)
	fixture.expect(
		target.damage_event_count == 1 and target.damage_total == 1,
		"Thunder committed before deferred start still resolves after Defeat"
	)
	await fixture.wait_seconds(0.7)
	fixture.expect(
		is_instance_valid(elk_king),
		"Elk King remains Level-owned after deferred-start thunder finishes"
	)

	elk_king.queue_free()
	detector_body.queue_free()
	target.queue_free()
	await fixture.process_frames(1)


func test_defeat_preserves_earthquake_without_starting_another_cast() -> void:
	var start_position := Vector2(24000.0, 0.0)
	var elk_king := harness.instantiate_enemy(
		ELK_KING_SCENE,
		start_position,
		{"idle_duration": 10.0, "patrol_range": 1000.0}
	)
	var thunder_cooldown := elk_king.get_node(
		"SkillDetect/ThunderSkill/Cooldown"
	) as Timer
	thunder_cooldown.start()
	var thunder_animation := elk_king.get_node(
		"SkillDetect/ThunderSkill/Thunder/AnimationPlayer"
	) as AnimationPlayer
	var earthquake_cooldown := elk_king.get_node(
		"SkillDetect/EarthquakeSkill/Cooldown"
	) as Timer
	var earthquake := elk_king.get_node(
		"SkillDetect/EarthquakeSkill/Earthquake"
	) as Area2D
	var earthquake_animation := earthquake.get_node("AnimationPlayer") as AnimationPlayer
	var earthquake_cast_count := [0]
	earthquake_animation.animation_started.connect(
		func(animation_name: StringName) -> void:
			if animation_name == &"cast":
				earthquake_cast_count[0] += 1
	)
	var detector_shape := elk_king.get_node(
		"SkillDetect/CollisionShape2D"
	) as CollisionShape2D
	var detector_body := harness.add_body(detector_shape.global_position)
	await fixture.physics_frames(3)
	await fixture.process_frames(1)
	var target := add_damage_recorder(earthquake.global_position)
	fixture.expect(
		earthquake_cast_count[0] == 1 and earthquake_animation.is_playing(),
		"Elk King begins one earthquake before Defeat"
	)

	await deplete_elk_king(elk_king)
	await fixture.wait_seconds(
		maxf(0.75 - earthquake_animation.current_animation_position, 0.01)
	)
	fixture.expect(
		is_instance_valid(elk_king),
		"Pending earthquake keeps the Elk King valid after its death presentation"
	)
	fixture.expect(
		target.damage_event_count == 1 and target.damage_total == 1,
		"Pending earthquake still resolves one damage after Elk King Defeat"
	)
	if is_instance_valid(elk_king):
		fixture.expect(
			earthquake_animation.is_playing(),
			"Pending earthquake presentation continues independently after Defeat"
		)
	await fixture.wait_seconds(
		maxf(
			earthquake_animation.get_animation(&"cast").length
				- earthquake_animation.current_animation_position,
			0.01
		) + 0.1
	)
	fixture.expect(
		is_instance_valid(elk_king),
		"Elk King remains Level-owned after its committed earthquake finishes"
	)
	thunder_cooldown.stop()
	thunder_cooldown.timeout.emit()
	earthquake_cooldown.stop()
	earthquake_cooldown.timeout.emit()
	await fixture.process_frames(2)
	fixture.expect(
		earthquake_cast_count[0] == 1 and not thunder_animation.is_playing(),
		"Persistent presence starts no new thunder or earthquake after Elk King Defeat"
	)

	elk_king.queue_free()
	detector_body.queue_free()
	target.queue_free()
	await fixture.process_frames(1)


func deplete_elk_king(elk_king: CharacterBody2D) -> void:
	var shield_animation_player := elk_king.get_node(
		"ShieldSkill/Shield/AnimationPlayer"
	) as AnimationPlayer
	elk_king.take_damage(1, Vector2.ZERO)
	await fixture.wait_seconds(
		shield_animation_player.get_animation("break").length + 0.1
	)
	elk_king.take_damage(elk_king.get_maximum_health(), Vector2.ZERO)


func test_cooldowns_retrigger_independently_during_persistent_presence() -> void:
	var elk_king := harness.instantiate_enemy(
		ELK_KING_SCENE,
		Vector2(5000.0, 0.0),
		{"idle_duration": 10.0, "patrol_range": 1000.0}
	)
	var detector_shape := elk_king.get_node(
		"SkillDetect/CollisionShape2D"
	) as CollisionShape2D
	var detector_body := harness.add_body(detector_shape.global_position)
	await fixture.physics_frames(3)
	await fixture.process_frames(1)

	var thunder_animation := elk_king.get_node(
		"SkillDetect/ThunderSkill/Thunder/AnimationPlayer"
	) as AnimationPlayer
	var earthquake_animation := elk_king.get_node(
		"SkillDetect/EarthquakeSkill/Earthquake/AnimationPlayer"
	) as AnimationPlayer
	var thunder_restart_count := [0]
	var earthquake_restart_count := [0]
	thunder_animation.animation_started.connect(
		func(animation_name: StringName) -> void:
			if animation_name == &"cast":
				thunder_restart_count[0] += 1
	)
	earthquake_animation.animation_started.connect(
		func(animation_name: StringName) -> void:
			if animation_name == &"cast":
				earthquake_restart_count[0] += 1
	)

	await fixture.wait_seconds(4.1)
	fixture.expect(
		thunder_restart_count[0] == 1,
		"Thunder retriggers after its three-second cast-started cooldown"
	)
	fixture.expect(
		earthquake_restart_count[0] == 0,
		"Thunder readiness does not reset or prematurely start earthquake"
	)

	await fixture.wait_seconds(2.1)
	fixture.expect(
		thunder_restart_count[0] == 2,
		"Thunder keeps its independent three-second cadence"
	)
	fixture.expect(
		earthquake_restart_count[0] == 1,
		"Earthquake retriggers after its independent five-second cooldown"
	)
	await fixture.wait_seconds(1.6)

	elk_king.queue_free()
	detector_body.queue_free()
	await fixture.process_frames(1)
