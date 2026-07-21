extends SceneTree


class CountingDamageableActor:
	extends DamageableActor

	var damage_received := 0


	func take_damage(amount: int, _knockback_direction: Vector2) -> void:
		damage_received += amount


const LEVEL_04_SCENE := preload("res://levels/level_04.tscn")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const PLAYER_LAYER := 1 << 1
const EXPECTED_MAXIMUM_HEALTH := 15
const EXPECTED_AWAKENING_DISTANCE := 600.0
const EXPECTED_PURSUIT_SPEED := 150.0
const EXPECTED_SWORD_GLEAM_COOLDOWN := 4.0

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	fixture.set_project_setting("physics/2d/default_gravity", 0.0)

	var level := fixture.instantiate_scene(LEVEL_04_SCENE) as CampaignLevel
	fixture.set_current_scene(level)
	await fixture.process_frames(2)
	fixture.set_paused(false)

	var player := level.get_node_or_null("Player") as DamageableActor
	var valdemar := level.get_node_or_null("Enemies/Valdemar") as DamageableActor
	fixture.expect(player != null, "Level 04 contains the real Player 04 actor")
	fixture.expect(valdemar != null, "Level 04 contains the dedicated Valdemar actor")
	if player != null and valdemar != null:
		await verify_production_configuration(valdemar)
		await verify_activation_sequence(level, player, valdemar)
		await verify_sword_pursuit_and_gleam(player, valdemar)

	Input.action_release("right")
	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func verify_production_configuration(valdemar: DamageableActor) -> void:
	fixture.expect(
		valdemar.get_script().resource_path == "res://enemies/valdemar.gd",
		"Valdemar owns a dedicated behavior script"
	)
	fixture.expect(
		valdemar.get_script().get_base_script().resource_path
		== "res://combat/damageable_actor.gd",
		"Valdemar uses DamageableActor without inheriting shared Enemy behavior"
	)
	fixture.expect(
		float(valdemar.get("awakening_distance")) == EXPECTED_AWAKENING_DISTANCE,
		"Valdemar has a 600-pixel Awakening boundary"
	)
	fixture.expect(
		valdemar.call("get_maximum_health") == EXPECTED_MAXIMUM_HEALTH,
		"Valdemar has fifteen maximum health"
	)

	var animation_player := valdemar.get_node("AnimationPlayer") as AnimationPlayer
	for specification in [
		{"name": &"attack", "duration": 0.5},
		{"name": &"dead", "duration": 0.9},
		{"name": &"hurt", "duration": 0.4},
		{"name": &"skill", "duration": 6.0},
		{"name": &"transformation", "duration": 0.9},
	]:
		var animation_name := specification["name"] as StringName
		fixture.expect(
			is_equal_approx(
				animation_player.get_animation(animation_name).length,
				float(specification["duration"])
			),
			"Valdemar %s has its production duration" % animation_name
		)
	fixture.expect(
		is_equal_approx(
			(valdemar.get_node("SwordGleamCooldown") as Timer).wait_time,
			EXPECTED_SWORD_GLEAM_COOLDOWN
		),
		"Valdemar Sword Gleam has a four-second cooldown"
	)
	fixture.expect(
		is_equal_approx(
			(
				valdemar.get_node("SwordGleam/AnimationPlayer") as AnimationPlayer
			).get_animation(&"cast").length,
			0.5
		),
		"Valdemar's Guard Sword Gleam presentation lasts half a second"
	)
	fixture.expect(
		valdemar.get("pursuit_speed") == EXPECTED_PURSUIT_SPEED,
		"Valdemar pursues at 150 pixels per second"
	)
	fixture.expect(
		valdemar.get_node_or_null("SkillDetect") == null,
		"Valdemar pursuit has no Skill Detection Area gate"
	)
	var black_water_cooldown := valdemar.get_node("BlackWaterCooldown") as Timer
	fixture.expect(
		is_equal_approx(black_water_cooldown.wait_time, 16.0)
		and black_water_cooldown.one_shot,
		"Valdemar Black Water has a sixteen-second interval"
	)


func verify_activation_sequence(
	level: CampaignLevel,
	player: DamageableActor,
	valdemar: DamageableActor
) -> void:
	var normal := valdemar.get_node("Normal") as Sprite2D
	var dark_mode := valdemar.get_node("DarkMode") as Sprite2D
	var health_bar_root := valdemar.get_node("HealthBar") as CanvasItem
	var health_bar := valdemar.get_node("HealthBar/TextureProgressBar") as TextureProgressBar
	var awakening_boundary := valdemar.get_node("AwakeningBoundary") as Area2D
	var awakening_shape := awakening_boundary.get_node("CollisionShape2D") as CollisionShape2D
	var hurt_box_collision := valdemar.get_node("HurtBox/CollisionShape2D") as CollisionShape2D
	var sword_cooldown := valdemar.get_node("SwordGleamCooldown") as Timer
	var black_water_cooldown := valdemar.get_node("BlackWaterCooldown") as Timer
	var animation_tree := valdemar.get_node("AnimationTree") as AnimationTree
	var animation_state := animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	var health_notifications: Array[Vector2i] = []
	var black_water_notifications := [0]
	var death_notifications := [0]
	var awakening_count := [0]
	fixture.expect(
		awakening_boundary.collision_mask == PLAYER_LAYER
		and is_equal_approx(
			(awakening_shape.shape as RectangleShape2D).size.x,
			EXPECTED_AWAKENING_DISTANCE * 2.0
		),
		"Valdemar's centered Awakening boundary monitors the Player across 600 pixels per side"
	)
	valdemar.connect(
		&"health_changed",
		func(current: int, maximum: int) -> void:
			health_notifications.append(Vector2i(current, maximum))
	)
	valdemar.connect(
		&"black_water_requested",
		func() -> void: black_water_notifications[0] += 1
	)
	valdemar.connect(&"died", func() -> void: death_notifications[0] += 1)
	animation_tree.animation_started.connect(
		func(animation_name: StringName) -> void:
			if animation_name == &"transformation":
				awakening_count[0] += 1
	)

	fixture.expect(normal.visible and not dark_mode.visible, "Valdemar begins in Normal Form")
	fixture.expect(not health_bar_root.visible, "Normal Form hides Valdemar's Health Bar")
	fixture.expect(
		valdemar.call("get_current_health") == EXPECTED_MAXIMUM_HEALTH,
		"Normal Form retains fifteen health"
	)
	fixture.expect(
		not valdemar.is_physics_processing()
		and valdemar.velocity == Vector2.ZERO
		and hurt_box_collision.disabled
		and sword_cooldown.is_stopped()
		and black_water_cooldown.is_stopped(),
		"Normal Form stops pursuit and active skill timing"
	)
	valdemar.take_damage(3, Vector2.ZERO)
	fixture.expect(
		valdemar.call("get_current_health") == EXPECTED_MAXIMUM_HEALTH
		and health_notifications.is_empty(),
		"Normal Form rejects direct incoming damage"
	)

	await cross_boss_door(level, player)
	fixture.expect(
		normal.visible and awakening_count[0] == 0,
		"Crossing the Boss Door does not start Valdemar Awakening"
	)

	awakening_boundary.monitoring = false
	await verify_contact_damage(player, valdemar, "Normal Form")
	await recover_player(player)
	player.global_position = (
		valdemar.global_position
		+ Vector2(-EXPECTED_AWAKENING_DISTANCE - 20.0, -5000.0)
	)
	await fixture.physics_frames(2)
	awakening_boundary.monitoring = true
	await fixture.physics_frames(2)

	player.global_position.x = valdemar.global_position.x - EXPECTED_AWAKENING_DISTANCE + 1.0
	for _frame in 4:
		await fixture.physics_frames(1)
		if animation_state.get_current_node() == &"transformation":
			break
	fixture.expect(
		awakening_count[0] == 1 and animation_state.get_current_node() == &"transformation",
		"Entering the horizontal boundary starts Valdemar Awakening once at any height"
	)
	fixture.expect(
		normal.visible
		and not dark_mode.visible
		and not health_bar_root.visible
		and not valdemar.is_physics_processing()
		and hurt_box_collision.disabled
		and sword_cooldown.is_stopped()
		and black_water_cooldown.is_stopped(),
		"Valdemar Awakening keeps active combat stopped and its Health Bar hidden"
	)
	valdemar.take_damage(3, Vector2.ZERO)
	fixture.expect(
		valdemar.call("get_current_health") == EXPECTED_MAXIMUM_HEALTH
		and health_notifications.is_empty(),
		"Valdemar Awakening rejects direct incoming damage"
	)

	await verify_contact_damage(player, valdemar, "Valdemar Awakening")
	await fixture.wait_seconds(0.70)
	fixture.expect(
		normal.visible and not dark_mode.visible and not health_bar_root.visible,
		"The complete transformation plays before Dark Mode begins"
	)
	for _frame in 20:
		await fixture.physics_frames(1)
		if valdemar.is_physics_processing():
			break
	fixture.expect(
		not normal.visible and dark_mode.visible,
		"Valdemar enters Dark Mode after the 0.9-second Awakening"
	)
	fixture.expect(
		health_bar_root.visible
		and health_bar.max_value == EXPECTED_MAXIMUM_HEALTH
		and health_bar.value == EXPECTED_MAXIMUM_HEALTH,
		"Dark Mode atomically presents fifteen of fifteen Boss health"
	)
	fixture.expect(
		valdemar.is_physics_processing()
		and not hurt_box_collision.disabled
		and sword_cooldown.is_stopped()
		and not black_water_cooldown.is_stopped(),
		"Dark Mode enables active behavior with Sword Gleam ready and Black Water timing started"
	)

	valdemar.take_damage(1, Vector2.ZERO)
	fixture.expect(
		valdemar.call("get_current_health") == EXPECTED_MAXIMUM_HEALTH - 1
		and health_bar.value == EXPECTED_MAXIMUM_HEALTH - 1
		and health_notifications == [Vector2i(14, 15)],
		"Dark Mode enables incoming damage and publishes Health Presentation changes"
	)
	fixture.expect(
		black_water_notifications[0] == 0 and death_notifications[0] == 0,
		"Valdemar exposes inactive Black Water and Defeat event seams"
	)

	player.global_position.x = valdemar.global_position.x - EXPECTED_AWAKENING_DISTANCE - 20.0
	await fixture.physics_frames(2)
	player.global_position.x = valdemar.global_position.x - EXPECTED_AWAKENING_DISTANCE + 1.0
	await fixture.physics_frames(2)
	fixture.expect(
		awakening_count[0] == 1 and dark_mode.visible,
		"The Awakening boundary cannot restart after its first entry"
	)


func verify_sword_pursuit_and_gleam(
	player: DamageableActor,
	valdemar: DamageableActor
) -> void:
	var dark_mode := valdemar.get_node("DarkMode") as Sprite2D
	var sword_gleam := valdemar.get_node("SwordGleam") as Area2D
	var sword_collision := sword_gleam.get_node("CollisionShape2D") as CollisionShape2D
	var sword_animation := sword_gleam.get_node("AnimationPlayer") as AnimationPlayer
	var sword_cooldown := valdemar.get_node("SwordGleamCooldown") as Timer
	var animation_tree := valdemar.get_node("AnimationTree") as AnimationTree
	var animation_state := animation_tree.get(
		"parameters/playback"
	) as AnimationNodeStateMachinePlayback
	var sword_offset := absf(sword_gleam.position.x)
	var attack_start_frames: Array[int] = []
	var gleam_start_frames: Array[int] = []
	animation_tree.animation_started.connect(
		func(animation_name: StringName) -> void:
			if animation_name == &"attack":
				attack_start_frames.append(Engine.get_physics_frames())
	)
	sword_animation.animation_started.connect(
		func(animation_name: StringName) -> void:
			if animation_name == &"cast":
				gleam_start_frames.append(Engine.get_physics_frames())
	)

	await recover_player(player)
	(player.get_node("VisualRoot/ShieldSkill/Shield") as CanvasItem).hide()
	player.set_physics_process(false)
	player.global_position = valdemar.global_position + Vector2(-1500.0, -5000.0)
	var pursuit_start_x := valdemar.global_position.x
	var pursuit_frames := 6
	await fixture.physics_frames(pursuit_frames)
	var expected_pursuit_x := (
		pursuit_start_x
		- EXPECTED_PURSUIT_SPEED * (pursuit_frames - 1) / Engine.physics_ticks_per_second
	)
	fixture.expect(
		is_equal_approx(valdemar.global_position.x, expected_pursuit_x),
		"Dark Mode pursues an unbounded horizontal target at 150 pixels per second regardless of height"
	)
	fixture.expect(
		not dark_mode.flip_h
		and sword_gleam.position.x < 0.0
		and sword_gleam.scale.x > 0.0,
		"Left pursuit keeps Valdemar and Sword Gleam coherently west-facing"
	)

	var snap_target_x := valdemar.global_position.x - 1.0
	player.global_position = Vector2(
		snap_target_x - sword_offset,
		valdemar.global_position.y
	)
	var per_cast_target := CountingDamageableActor.new()
	per_cast_target.collision_layer = PLAYER_LAYER
	per_cast_target.collision_mask = 0
	per_cast_target.global_position = player.global_position
	var per_cast_target_shape := CollisionShape2D.new()
	var per_cast_target_rectangle := RectangleShape2D.new()
	per_cast_target_rectangle.size = Vector2(20.0, 20.0)
	per_cast_target_shape.shape = per_cast_target_rectangle
	per_cast_target.add_child(per_cast_target_shape)
	fixture.add_node(per_cast_target, player.get_parent())
	var health_before_first_cast := int(player.call("get_current_health"))
	await fixture.physics_frames(1)
	fixture.expect(
		is_equal_approx(valdemar.global_position.x, snap_target_x)
		and is_equal_approx(sword_gleam.global_position.x, player.global_position.x),
		"Pursuit snaps across its next step to align the facing Sword Gleam center without oscillation"
	)
	fixture.expect(
		attack_start_frames.size() == 1
		and gleam_start_frames.size() == 1
		and attack_start_frames[0] == gleam_start_frames[0]
		and animation_state.get_current_node() == &"attack"
		and sword_animation.current_animation == &"cast",
		"Immediate readiness starts Valdemar and Sword Gleam together in one physics frame"
	)
	fixture.expect(
		not sword_cooldown.is_stopped()
		and sword_cooldown.time_left > EXPECTED_SWORD_GLEAM_COOLDOWN - 0.1,
		"Sword Gleam starts its independent four-second cooldown at attack start"
	)

	await fixture.wait_seconds(0.10)
	fixture.expect(
		player.call("get_current_health") == health_before_first_cast
		and sword_collision.disabled,
		"Sword Gleam does not expose damage before 0.15 seconds"
	)
	await fixture.wait_seconds(0.10)
	fixture.expect(
		player.call("get_current_health") == health_before_first_cast - 1
		and per_cast_target.damage_received == 1
		and not sword_collision.disabled,
		"Sword Gleam exposes one damage per target from 0.15 seconds"
	)
	per_cast_target.global_position.x += 400.0
	await fixture.physics_frames(2)
	per_cast_target.global_position.x -= 400.0
	await fixture.physics_frames(2)
	fixture.expect(
		per_cast_target.damage_received == 1,
		"One active Sword Gleam cannot damage a target again after it exits and re-enters"
	)
	per_cast_target.collision_layer = 0

	var locked_position := valdemar.global_position
	var locked_gleam_position := sword_gleam.position
	var locked_gleam_scale := sword_gleam.scale
	player.global_position = valdemar.global_position + Vector2(1000.0, 0.0)
	await fixture.wait_seconds(0.12)
	fixture.expect(
		valdemar.global_position == locked_position
		and not dark_mode.flip_h
		and sword_gleam.position == locked_gleam_position
		and sword_gleam.scale == locked_gleam_scale
		and not sword_collision.disabled
		and animation_state.get_current_node() == &"attack",
		"Sword Gleam remains damaging while locking Valdemar's position, facing, and release through 0.5 seconds"
	)
	fixture.expect(
		player.call("get_current_health") == health_before_first_cast - 1,
		"One Sword Gleam release damages the real Player at most once"
	)

	await fixture.wait_seconds(0.15)
	var pursuit_resume_x := valdemar.global_position.x
	await fixture.physics_frames(3)
	fixture.expect(
		animation_state.get_current_node() == &"run"
		and valdemar.global_position.x > pursuit_resume_x
		and dark_mode.flip_h
		and sword_gleam.position.x > 0.0
		and sword_gleam.scale.x < 0.0
		and not sword_gleam.visible
		and sword_collision.disabled
		and sword_collision.global_position.x > valdemar.global_position.x,
		"Pursuit resumes after 0.5 seconds and mirrors the complete Sword Gleam to the Player's right"
	)

	player.global_position = valdemar.global_position + Vector2(-1000.0, -5000.0)
	var turn_start_x := valdemar.global_position.x
	await fixture.physics_frames(3)
	fixture.expect(
		valdemar.global_position.x < turn_start_x
		and not dark_mode.flip_h
		and attack_start_frames.size() == 1,
		"Sword cooldown pursuit keeps correcting alignment when the Player changes sides and height"
	)

	player.global_position = Vector2(
		valdemar.global_position.x - sword_offset,
		valdemar.global_position.y
	)
	await fixture.physics_frames(2)
	fixture.expect(
		is_equal_approx(sword_gleam.global_position.x, player.global_position.x)
		and animation_state.get_current_node() == &"idle"
		and attack_start_frames.size() == 1,
		"Valdemar holds current alignment without attacking while Sword Gleam cools down"
	)

	await fixture.wait_seconds(maxf(sword_cooldown.time_left - 0.10, 0.0))
	fixture.expect(
		attack_start_frames.size() == 1,
		"Sword Gleam cannot release again before its four-second cooldown completes"
	)
	var health_before_second_cast := int(player.call("get_current_health"))
	await fixture.wait_seconds(0.20)
	fixture.expect(
		attack_start_frames.size() == 2
		and gleam_start_frames.size() == 2
		and attack_start_frames[1] == gleam_start_frames[1],
		"An aligned Sword Gleam releases again when its independent cooldown completes"
	)
	await fixture.wait_seconds(0.20)
	fixture.expect(
		player.call("get_current_health") == health_before_second_cast - 1,
		"Each later Sword Gleam release contributes one new damage event"
	)
	player.set_physics_process(true)


func cross_boss_door(level: CampaignLevel, player: DamageableActor) -> void:
	var boss_door := level.get_node("BossDoor") as Area2D
	player.global_position = boss_door.global_position + Vector2(-30.0, 0.0)
	await fixture.physics_frames(2)
	player.global_position.x = boss_door.global_position.x + 30.0
	await fixture.physics_frames(2)


func verify_contact_damage(
	player: DamageableActor,
	valdemar: DamageableActor,
	form_name: String
) -> void:
	var shield := player.get_node("VisualRoot/ShieldSkill/Shield") as CanvasItem
	shield.hide()
	var health_before := int(player.call("get_current_health"))
	player.global_position = valdemar.global_position + Vector2(-55.0, 0.0)
	Input.action_press("right")
	for _frame in 12:
		await fixture.physics_frames(1)
		if int(player.call("get_current_health")) < health_before:
			break
	Input.action_release("right")
	fixture.expect(
		player.call("get_current_health") == health_before - 1,
		"Physical Valdemar contact deals one damage in %s" % form_name
	)


func recover_player(player: DamageableActor) -> void:
	var hurt_duration := (
		(player.get_node("AnimationPlayer") as AnimationPlayer).get_animation(&"hurt").length
	)
	await fixture.wait_seconds(hurt_duration + 0.05)
	player.call("restore_full_health")
