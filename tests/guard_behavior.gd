extends SceneTree


class CountingDamageableActor:
	extends DamageableActor

	var damage_count := 0


	func take_damage(_amount: int, _knockback_direction: Vector2) -> void:
		damage_count += 1


const GUARD_SCENE := preload("res://enemies/guard.tscn")
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

	await test_standard_enemy_health_and_damage()
	await test_sword_gleam_cast_and_damage()
	await test_sword_gleam_damages_same_target_once_per_cast()
	await test_sword_gleam_follows_guard_facing()
	await test_persistent_detection_retriggers_after_five_second_cooldown()
	await test_damage_does_not_interrupt_sword_gleam()
	await test_death_cancels_sword_gleam()

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func test_standard_enemy_health_and_damage() -> void:
	var guard := harness.instantiate_enemy(GUARD_SCENE, Vector2.ZERO)
	await fixture.process_frames(2)

	fixture.expect(
		guard.has_method("get_current_health"),
		"Guard exposes the standard Enemy health contract"
	)
	if guard.has_method("get_current_health"):
		fixture.expect(
			guard.call("get_current_health") == 3,
			"Guard starts with three health"
		)

	await harness.deliver_hit(guard)
	fixture.expect(
		guard.call("get_current_health") == 2,
		"Guard takes damage through the standard Enemy hurt contract"
	)

	guard.queue_free()
	await fixture.process_frames(1)


func test_sword_gleam_cast_and_damage() -> void:
	var casting_guard := harness.instantiate_enemy(
		GUARD_SCENE,
		Vector2(3000.0, 0.0),
		{"idle_duration": 10.0}
	)
	var hurt_event_count: Array[int] = [0]
	var player := harness.instantiate_passive_player(
		casting_guard.global_position + Vector2(-92.5, 9.0),
		func() -> void: hurt_event_count[0] += 1
	)
	await fixture.physics_frames(3)
	await fixture.wait_seconds(0.05)

	fixture.expect(
		harness.is_playing(casting_guard, &"skill"),
		"Guard plays its attack motion when releasing Sword Gleam"
	)
	var sword_gleam_animation_player := casting_guard.get_node(
		"SkillDetect/SwordGleam/AnimationPlayer"
	) as AnimationPlayer
	var skill_start_x := casting_guard.global_position.x
	fixture.expect(
		sword_gleam_animation_player.is_playing()
		and sword_gleam_animation_player.current_animation == &"cast",
		"Guard and Sword Gleam cast presentations start together"
	)
	await fixture.wait_seconds(0.55)
	fixture.expect(
		hurt_event_count[0] == 1,
		"One Sword Gleam release damages the Player once"
	)
	fixture.expect(
		is_equal_approx(casting_guard.global_position.x, skill_start_x),
		"Guard remains stationary throughout Sword Gleam"
	)
	fixture.expect(
		not harness.is_playing(casting_guard, &"skill")
		and not sword_gleam_animation_player.is_playing(),
		"Guard and Sword Gleam finish their synchronized presentations"
	)

	casting_guard.queue_free()
	player.queue_free()
	await fixture.process_frames(1)


func test_sword_gleam_damages_same_target_once_per_cast() -> void:
	var guard_position := Vector2(4500.0, 0.0)
	var guard := harness.instantiate_enemy(
		GUARD_SCENE,
		guard_position,
		{"idle_duration": 10.0}
	)
	var actor := add_counting_damageable_actor(
		guard_position + Vector2(-92.5, 9.0)
	)
	for _frame in 20:
		if actor.damage_count == 1:
			break
		await fixture.physics_frames(1)
	fixture.expect(
		actor.damage_count == 1,
		"Sword Gleam damages a target entering its active region"
	)

	actor.position += Vector2(400.0, 0.0)
	await fixture.physics_frames(2)
	actor.position -= Vector2(400.0, 0.0)
	await fixture.physics_frames(2)
	fixture.expect(
		actor.damage_count == 1,
		"One Sword Gleam cast cannot damage the same target twice"
	)

	guard.queue_free()
	actor.queue_free()
	await fixture.process_frames(1)


func test_sword_gleam_follows_guard_facing() -> void:
	var turning_guard_position := Vector2(6000.0, 0.0)
	var wall := harness.add_environment_wall(
		turning_guard_position + Vector2(-60.0, 24.0),
		Vector2(10.0, 8.0)
	)
	var turning_guard := harness.instantiate_enemy(
		GUARD_SCENE,
		turning_guard_position,
		{"idle_duration": 0.0, "patrol_range": 1000.0}
	)
	await fixture.physics_frames(12)

	fixture.expect(
		harness.enemy_sprite_is_flipped(turning_guard),
		"Guard turns right when its left-facing patrol meets a wall"
	)
	var turned_sword_gleam := turning_guard.get_node(
		"SkillDetect/SwordGleam"
	) as Area2D
	fixture.expect(
		turned_sword_gleam.position.x > 0.0 and turned_sword_gleam.scale.x < 0.0,
		"Sword Gleam moves to the facing side and mirrors when Guard turns right"
	)
	var right_hurt_event_count: Array[int] = [0]
	var right_player := harness.instantiate_passive_player(
		turning_guard.global_position + Vector2(92.5, 9.0),
		func() -> void: right_hurt_event_count[0] += 1
	)
	var left_hurt_event_count: Array[int] = [0]
	var left_player := harness.instantiate_passive_player(
		turning_guard.global_position + Vector2(-92.5, 9.0),
		func() -> void: left_hurt_event_count[0] += 1
	)
	await fixture.physics_frames(3)
	await fixture.wait_seconds(0.2)

	for child_path in ["Sprite2D", "CPUParticles2D", "CollisionShape2D"]:
		var child := turned_sword_gleam.get_node(child_path) as Node2D
		fixture.expect(
			child.global_position.x > turning_guard.global_position.x,
			"Sword Gleam %s follows Guard's right-facing side" % child_path
		)
	await fixture.wait_seconds(0.35)
	fixture.expect(
		right_hurt_event_count[0] == 1 and left_hurt_event_count[0] == 0,
		"Right-facing Sword Gleam damages only the Player in front"
	)

	turning_guard.queue_free()
	wall.queue_free()
	right_player.queue_free()
	left_player.queue_free()
	await fixture.process_frames(1)


func test_persistent_detection_retriggers_after_five_second_cooldown() -> void:
	var guard_position := Vector2(9000.0, 0.0)
	var guard := harness.instantiate_enemy(
		GUARD_SCENE,
		guard_position,
		{"idle_duration": 10.0}
	)
	var cooldown := guard.get_node("SkillDetect/Cooldown") as Timer
	fixture.expect(
		is_equal_approx(cooldown.wait_time, 5.0),
		"Sword Gleam has a five second cooldown"
	)
	cooldown.wait_time = 0.75

	var cast_count: Array[int] = [0]
	var animation_player := guard.get_node(
		"SkillDetect/SwordGleam/AnimationPlayer"
	) as AnimationPlayer
	animation_player.animation_started.connect(
		func(animation_name: StringName) -> void:
			if animation_name == &"cast":
				cast_count[0] += 1
	)
	var player := harness.add_body(guard_position + Vector2(-92.5, 9.0))
	await fixture.wait_seconds(1.0)

	fixture.expect(
		cast_count[0] >= 2,
		"Guard releases again when the Player remains inside after cooldown"
	)

	guard.queue_free()
	player.queue_free()
	await fixture.process_frames(1)


func test_damage_does_not_interrupt_sword_gleam() -> void:
	var guard_position := Vector2(12000.0, 0.0)
	var guard := harness.instantiate_enemy(
		GUARD_SCENE,
		guard_position,
		{"idle_duration": 10.0}
	)
	var hurt_event_count: Array[int] = [0]
	var player := harness.instantiate_passive_player(
		guard_position + Vector2(-92.5, 9.0),
		func() -> void: hurt_event_count[0] += 1
	)
	await fixture.physics_frames(3)
	await fixture.wait_seconds(0.05)

	guard.take_damage(1, Vector2.ZERO)
	guard.take_damage(1, Vector2.ZERO)
	var animation_player := guard.get_node(
		"SkillDetect/SwordGleam/AnimationPlayer"
	) as AnimationPlayer
	fixture.expect(
		animation_player.is_playing()
		and animation_player.current_animation == &"cast",
		"Non-lethal damage does not interrupt Sword Gleam"
	)
	fixture.expect(
		guard.get_current_health() == 2 and guard.is_hurt_immune(),
		"Sword Gleam keeps standard hurt immunity after accepting damage"
	)
	await fixture.wait_seconds(0.55)
	fixture.expect(
		hurt_event_count[0] == 1,
		"Sword Gleam still damages the Player after Guard takes non-lethal damage"
	)

	guard.queue_free()
	player.queue_free()
	await fixture.process_frames(1)


func add_counting_damageable_actor(position: Vector2) -> CountingDamageableActor:
	var actor := CountingDamageableActor.new()
	actor.collision_layer = 1 << 1
	actor.collision_mask = 0
	actor.position = position
	var collision_shape := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20.0, 20.0)
	collision_shape.shape = shape
	actor.add_child(collision_shape)
	fixture.add_node(actor, harness.world)
	return actor


func test_death_cancels_sword_gleam() -> void:
	var guard_position := Vector2(15000.0, 0.0)
	var guard := harness.instantiate_enemy(
		GUARD_SCENE,
		guard_position,
		{"idle_duration": 10.0}
	)
	var hurt_event_count: Array[int] = [0]
	var player := harness.instantiate_passive_player(
		guard_position + Vector2(-92.5, 9.0),
		func() -> void: hurt_event_count[0] += 1
	)
	await fixture.physics_frames(3)
	await fixture.wait_seconds(0.05)

	guard.take_damage(3, Vector2.ZERO)
	await fixture.process_frames(1)
	var animation_player := guard.get_node(
		"SkillDetect/SwordGleam/AnimationPlayer"
	) as AnimationPlayer
	fixture.expect(
		not animation_player.is_playing(),
		"Guard Defeat stops the Sword Gleam presentation"
	)
	await fixture.wait_seconds(0.3)
	fixture.expect(
		hurt_event_count[0] == 0,
		"Guard Defeat prevents pending Sword Gleam damage"
	)

	if is_instance_valid(guard):
		guard.queue_free()
	player.queue_free()
	await fixture.process_frames(1)
