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
const EXPECTED_HURT_DURATION := 0.4
const EXPECTED_DEAD_DURATION := 0.9
const DEFEAT_SCENARIOS: Array[StringName] = [
	&"pursuit",
	&"waiting",
	&"hurt",
	&"sword_gleam",
	&"pending_black_water",
	&"active_black_water",
]

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
		await verify_dark_mode_combat_interactions(player, valdemar)
		await verify_pursuit_targeting_rules()
		await verify_defeat_preempts_every_dark_action()

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
	var skill_animation := animation_player.get_animation(&"skill")
	var skill_texture_track := skill_animation.find_track(
		NodePath("DarkMode:texture"),
		Animation.TYPE_VALUE
	)
	fixture.expect(
		skill_animation.track_get_key_count(skill_texture_track) == 9
		and is_equal_approx(
			skill_animation.track_get_key_time(skill_texture_track, 8),
			3.0
		),
		"Valdemar Black Water presents nine frames in its first three seconds"
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
		and black_water_cooldown.one_shot
		and not black_water_cooldown.autostart,
		"Valdemar Black Water has a non-autostart sixteen-second interval"
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
	var hurt_count := [0]
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
			elif animation_name == &"hurt":
				hurt_count[0] += 1
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
		and not black_water_cooldown.is_stopped()
		and black_water_cooldown.time_left > 15.8,
		"Dark Mode starts the production Black Water interval with Sword Gleam ready"
	)

	player.global_position = valdemar.global_position + Vector2(-1000.0, -5000.0)
	await fixture.physics_frames(2)
	var hurt_position := valdemar.global_position
	valdemar.take_damage(1, Vector2(1000.0, -1000.0))
	await fixture.physics_frames(1)
	fixture.expect(
		valdemar.call("get_current_health") == EXPECTED_MAXIMUM_HEALTH - 1
		and health_bar.value == EXPECTED_MAXIMUM_HEALTH - 1
		and health_notifications == [Vector2i(14, 15)]
		and valdemar.call("is_hurt_immune")
		and animation_state.get_current_node() == &"hurt"
		and hurt_count[0] == 1
		and valdemar.global_position == hurt_position,
		"Pursuit damage updates Health Presentation and starts Valdemar Hurt without displacement"
	)
	var hurt_play_position := animation_state.get_current_play_position()
	valdemar.take_damage(1, Vector2(-1000.0, 1000.0))
	await fixture.physics_frames(2)
	fixture.expect(
		valdemar.call("get_current_health") == EXPECTED_MAXIMUM_HEALTH - 1
		and health_notifications == [Vector2i(14, 15)]
		and hurt_count[0] == 1
		and animation_state.get_current_play_position() > hurt_play_position
		and valdemar.global_position == hurt_position,
		"Hurt immunity rejects repeated damage without restarting Valdemar Hurt or moving him"
	)
	await fixture.wait_seconds(EXPECTED_HURT_DURATION - 0.15)
	fixture.expect(
		valdemar.call("is_hurt_immune")
		and animation_state.get_current_node() == &"hurt"
		and valdemar.global_position == hurt_position,
		"Valdemar remains stationary for the complete Hurt response"
	)
	player.global_position = valdemar.global_position + Vector2(1000.0, -5000.0)
	await fixture.wait_seconds(0.15)
	await fixture.physics_frames(2)
	fixture.expect(
		not valdemar.call("is_hurt_immune")
		and animation_state.get_current_node() == &"run"
		and valdemar.global_position.x > hurt_position.x,
		"Completed Valdemar Hurt resumes Pursuit toward the Player's current position"
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


func verify_dark_mode_combat_interactions(
	player: DamageableActor,
	valdemar: DamageableActor
) -> void:
	var dark_mode := valdemar.get_node("DarkMode") as Sprite2D
	var health_bar := valdemar.get_node("HealthBar/TextureProgressBar") as TextureProgressBar
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
	player.global_position = valdemar.global_position + Vector2(-1500.0, 0.0)
	await fixture.physics_frames(2)
	player.global_position = valdemar.global_position + Vector2(-1500.0, -5000.0)
	var pursuit_start_x := valdemar.global_position.x
	var pursuit_frames := 6
	await fixture.physics_frames(pursuit_frames)
	var expected_pursuit_x := (
		pursuit_start_x
		- EXPECTED_PURSUIT_SPEED * (pursuit_frames - 1) / Engine.physics_ticks_per_second
	)
	fixture.expect(
		absf(valdemar.global_position.x - expected_pursuit_x)
		<= EXPECTED_PURSUIT_SPEED / Engine.physics_ticks_per_second,
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
	var valdemar_health_before_attack_damage := int(valdemar.call("get_current_health"))
	var locked_position := valdemar.global_position
	var locked_facing := dark_mode.flip_h
	var locked_gleam_position := sword_gleam.position
	var locked_gleam_scale := sword_gleam.scale
	var gleam_play_position := sword_animation.current_animation_position
	var cooldown_before_attack_damage := sword_cooldown.time_left
	valdemar.take_damage(1, Vector2(1000.0, 1000.0))
	await fixture.physics_frames(1)
	fixture.expect(
		valdemar.call("get_current_health") == valdemar_health_before_attack_damage - 1
		and health_bar.value == valdemar_health_before_attack_damage - 1
		and valdemar.call("is_hurt_immune")
		and animation_state.get_current_node() == &"attack"
		and sword_animation.current_animation == &"cast"
		and sword_animation.current_animation_position > gleam_play_position
		and valdemar.global_position == locked_position
		and dark_mode.flip_h == locked_facing
		and sword_gleam.position == locked_gleam_position
		and sword_gleam.scale == locked_gleam_scale
		and sword_cooldown.time_left < cooldown_before_attack_damage,
		"Damage during Sword Gleam updates health without interrupting its committed attack or cooldown"
	)
	valdemar.take_damage(1, Vector2(-1000.0, -1000.0))
	await fixture.physics_frames(1)
	fixture.expect(
		valdemar.call("get_current_health") == valdemar_health_before_attack_damage - 1
		and animation_state.get_current_node() == &"attack"
		and valdemar.global_position == locked_position,
		"Sword Gleam hurt immunity rejects repeated damage without changing the committed attack"
	)

	await fixture.wait_seconds(0.05)
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
	player.global_position = valdemar.global_position + Vector2(-1000.0, 0.0)
	var pursuit_resume_x := valdemar.global_position.x
	await fixture.physics_frames(2)
	fixture.expect(
		not valdemar.call("is_hurt_immune")
		and animation_state.get_current_node() == &"run"
		and valdemar.global_position.x < pursuit_resume_x
		and not dark_mode.flip_h
		and sword_gleam.position.x < 0.0
		and sword_gleam.scale.x > 0.0
		and not sword_gleam.visible
		and sword_collision.disabled
		and sword_collision.global_position.x < valdemar.global_position.x,
		"Ground-level Pursuit resumes after 0.5 seconds facing its movement direction"
	)

	player.global_position = valdemar.global_position + Vector2(1000.0, -5000.0)
	await fixture.physics_frames(2)
	fixture.expect(
		dark_mode.flip_h and animation_state.get_current_node() == &"run",
		"Airborne Pursuit turns east before moving toward its locked pre-turn destination"
	)
	player.global_position = valdemar.global_position + Vector2(-1000.0, -5000.0)
	var turn_start_x := valdemar.global_position.x
	await fixture.physics_frames(3)
	fixture.expect(
		valdemar.global_position.x > turn_start_x,
		"Airborne Pursuit keeps its locked pre-turn destination when the Player changes sides"
	)
	fixture.expect(
		dark_mode.flip_h,
		"Locked eastward Airborne Pursuit faces its movement direction"
	)
	fixture.expect(
		attack_start_frames.size() == 1,
		"A Player side change does not create a Sword Gleam release during locked pursuit"
	)
	await recover_player(player)
	player.set_physics_process(true)
	await verify_contact_damage(player, valdemar, "Dark Mode Pursuit")
	player.set_physics_process(false)

	var ground_alignment_position := valdemar.global_position
	player.global_position = Vector2(
		valdemar.global_position.x - sword_offset,
		valdemar.global_position.y
	)
	await fixture.physics_frames(2)
	fixture.expect(
		valdemar.global_position.x < ground_alignment_position.x
		and animation_state.get_current_node() == &"run"
		and attack_start_frames.size() == 1,
		"Ground-level Pursuit crosses a cooling Sword Gleam alignment toward the Player's body"
	)
	player.global_position = Vector2(
		valdemar.global_position.x - sword_offset,
		valdemar.global_position.y - 100.0
	)
	await fixture.physics_frames(2)
	fixture.expect(
		is_equal_approx(sword_gleam.global_position.x, player.global_position.x)
		and animation_state.get_current_node() == &"idle",
		"Airborne Pursuit waits at its Sword Gleam alignment while the skill cools down"
	)
	await recover_player(player)
	var valdemar_health_before_wait_damage := int(valdemar.call("get_current_health"))
	var waiting_position := valdemar.global_position
	var cooldown_before_hurt := sword_cooldown.time_left
	var weapon_hit := add_weapon_hit(valdemar.global_position)
	for _frame in 3:
		await fixture.physics_frames(1)
		if animation_state.get_current_node() == &"hurt":
			break
	weapon_hit.collision_layer = 0
	fixture.expect(
		valdemar.call("get_current_health") == valdemar_health_before_wait_damage - 1
		and health_bar.value == valdemar_health_before_wait_damage - 1,
		"Damage during Sword Gleam cooldown waiting reduces Valdemar health"
	)
	fixture.expect(
		animation_state.get_current_node() == &"hurt",
		"Damage during Sword Gleam cooldown waiting starts Valdemar Hurt"
	)
	fixture.expect(
		valdemar.global_position == waiting_position,
		"Damage during Sword Gleam cooldown waiting applies zero displacement"
	)
	player.set_physics_process(true)
	await verify_contact_damage(player, valdemar, "Valdemar Hurt")
	player.set_physics_process(false)
	player.global_position = Vector2(
		valdemar.global_position.x + sword_gleam.position.x,
		valdemar.global_position.y - 100.0
	)
	fixture.expect(
		animation_state.get_current_node() == &"hurt"
		and sword_cooldown.time_left < cooldown_before_hurt - 0.05
		and valdemar.global_position == waiting_position,
		"Sword Gleam cooldown and Valdemar Contact Damage remain active throughout Hurt"
	)
	await fixture.wait_seconds(EXPECTED_HURT_DURATION)
	fixture.expect(
		not valdemar.call("is_hurt_immune")
		and animation_state.get_current_node() != &"hurt",
		"Sword-cooldown Hurt completes before Valdemar resumes Pursuit"
	)

	await fixture.wait_seconds(maxf(sword_cooldown.time_left - 0.05, 0.0))
	fixture.expect(
		attack_start_frames.size() == 1,
		"Sword Gleam cannot release again before its four-second cooldown completes"
	)
	var health_before_second_cast := int(player.call("get_current_health"))
	for _frame in 8:
		await fixture.physics_frames(1)
		if attack_start_frames.size() == 2:
			break
	fixture.expect(
		attack_start_frames.size() == 2
		and gleam_start_frames.size() == 2
		and attack_start_frames[1] == gleam_start_frames[1],
		"An aligned Sword Gleam releases again when its independent cooldown completes"
	)
	var second_cast_position := valdemar.global_position
	player.set_physics_process(true)
	player.global_position = valdemar.global_position + Vector2(-55.0, 0.0)
	Input.action_press("right")
	for _frame in 7:
		await fixture.physics_frames(1)
		if int(player.call("get_current_health")) < health_before_second_cast:
			break
	Input.action_release("right")
	fixture.expect(
		player.call("get_current_health") == health_before_second_cast - 1
		and sword_collision.disabled
		and animation_state.get_current_node() == &"attack"
		and valdemar.global_position == second_cast_position,
		"Valdemar Contact Damage remains active during the locked Sword Gleam before its damage region opens"
	)
	player.set_physics_process(false)
	await verify_black_water_cycle_and_cast(player, valdemar, attack_start_frames)


func verify_pursuit_targeting_rules() -> void:
	var actors := await instantiate_active_valdemar()
	var level := actors["level"] as CampaignLevel
	var player := actors["player"] as DamageableActor
	var valdemar := actors["valdemar"] as DamageableActor
	if level == null or player == null or valdemar == null:
		fixture.expect(false, "Valdemar Pursuit rules load production actors")
		return

	var dark_mode := valdemar.get_node("DarkMode") as Sprite2D
	var sword_gleam := valdemar.get_node("SwordGleam") as Area2D
	var sword_cooldown := valdemar.get_node("SwordGleamCooldown") as Timer
	var black_water_cooldown := valdemar.get_node("BlackWaterCooldown") as Timer
	var animation_tree := valdemar.get_node("AnimationTree") as AnimationTree
	var animation_state := animation_tree.get(
		"parameters/playback"
	) as AnimationNodeStateMachinePlayback
	var attack_start_count := [0]
	animation_tree.animation_started.connect(
		func(animation_name: StringName) -> void:
			if animation_name == &"attack":
				attack_start_count[0] += 1
	)
	black_water_cooldown.stop()
	sword_cooldown.start(10.0)

	player.global_position = valdemar.global_position + Vector2(-1000.0, 0.0)
	await fixture.physics_frames(2)
	var turn_only_start_x := valdemar.global_position.x
	player.global_position = Vector2(
		turn_only_start_x + absf(sword_gleam.position.x),
		valdemar.global_position.y
	)
	sword_cooldown.stop()
	await fixture.physics_frames(2)
	fixture.expect(
		valdemar.global_position.x > turn_only_start_x
		and dark_mode.flip_h
		and animation_state.get_current_node() == &"run"
		and attack_start_count[0] == 0,
		"An ordinary turn that places Sword Gleam on the Player does not count as movement overlap"
	)
	sword_cooldown.start(10.0)

	player.global_position = valdemar.global_position + Vector2(1000.0, 9.99)
	var ground_start_x := valdemar.global_position.x
	await fixture.physics_frames(2)
	fixture.expect(
		valdemar.global_position.x > ground_start_x
		and dark_mode.flip_h
		and animation_state.get_current_node() == &"run",
		"A vertical difference below ten pixels pursues the Player's body while facing movement"
	)

	player.global_position = Vector2(
		valdemar.global_position.x + absf(sword_gleam.position.x),
		valdemar.global_position.y + 10.0
	)
	var boundary_position := valdemar.global_position
	await fixture.physics_frames(2)
	fixture.expect(
		valdemar.global_position == boundary_position
		and animation_state.get_current_node() == &"idle",
		"A vertical difference of exactly ten pixels uses Sword Gleam alignment"
	)

	var sword_offset := absf(sword_gleam.position.x)
	var locked_start_x := valdemar.global_position.x
	var airborne_player_x := locked_start_x + 100.0
	player.global_position = Vector2(
		airborne_player_x,
		valdemar.global_position.y + 100.0
	)
	sword_cooldown.stop()
	await fixture.physics_frames(2)
	fixture.expect(
		valdemar.global_position.x < locked_start_x
		and not dark_mode.flip_h
		and animation_state.get_current_node() == &"run"
		and attack_start_count[0] == 0,
		"Airborne Pursuit turns before moving toward its locked Sword Gleam destination without casting on the turn"
	)

	for _frame in 40:
		await fixture.physics_frames(1)
		if attack_start_count[0] == 1:
			break
	fixture.expect(
		attack_start_count[0] == 1
		and dark_mode.flip_h
		and is_equal_approx(
			sword_gleam.global_position.x,
			airborne_player_x
		)
		and is_equal_approx(
			valdemar.global_position.x,
			airborne_player_x - sword_offset
		),
		"Airborne Pursuit reaches its locked destination before turning back to release Sword Gleam"
	)

	if current_scene == level:
		current_scene = null
	level.free()


func verify_black_water_cycle_and_cast(
	player: DamageableActor,
	valdemar: DamageableActor,
	attack_start_frames: Array[int]
) -> void:
	var dark_mode := valdemar.get_node("DarkMode") as Sprite2D
	var health_bar := valdemar.get_node("HealthBar/TextureProgressBar") as TextureProgressBar
	var sword_cooldown := valdemar.get_node("SwordGleamCooldown") as Timer
	var black_water_cooldown := valdemar.get_node("BlackWaterCooldown") as Timer
	var animation_player := valdemar.get_node("AnimationPlayer") as AnimationPlayer
	var skill_animation := animation_player.get_animation(&"skill")
	var animation_tree := valdemar.get_node("AnimationTree") as AnimationTree
	var animation_state := animation_tree.get(
		"parameters/playback"
	) as AnimationNodeStateMachinePlayback
	var black_water_notifications := [0]
	valdemar.connect(
		&"black_water_requested",
		func() -> void: black_water_notifications[0] += 1
	)

	player.global_position = valdemar.global_position + Vector2(1000.0, -5000.0)
	await make_black_water_due_twice(black_water_cooldown)
	fixture.expect(
		black_water_notifications[0] == 0
		and animation_state.get_current_node() == &"attack"
		and attack_start_frames.size() == 2,
		"Due Black Water remains singularly pending while an active Sword Gleam finishes"
	)

	for _frame in 30:
		await fixture.physics_frames(1)
		if animation_state.get_current_node() == &"skill":
			break
	fixture.expect(
		black_water_notifications[0] == 1
		and animation_state.get_current_node() == &"skill"
		and attack_start_frames.size() == 2
		and dark_mode.flip_h,
		"One pending Black Water Cast starts facing the Player immediately after Sword Gleam"
	)
	fixture.expect(
		not black_water_cooldown.is_stopped()
		and black_water_cooldown.time_left > 15.8,
		"Black Water restarts its cycle when the delayed cast actually begins"
	)

	var cast_position := valdemar.global_position
	var cast_facing := dark_mode.flip_h
	var valdemar_health_before_cast_damage := int(valdemar.call("get_current_health"))
	var sword_cooldown_at_cast_start := sword_cooldown.time_left
	valdemar.take_damage(1, Vector2(-1000.0, 1000.0))
	await fixture.physics_frames(1)
	fixture.expect(
		valdemar.call("get_current_health") == valdemar_health_before_cast_damage - 1
		and health_bar.value == valdemar_health_before_cast_damage - 1
		and valdemar.call("is_hurt_immune")
		and animation_state.get_current_node() == &"skill"
		and valdemar.global_position == cast_position
		and dark_mode.flip_h == cast_facing,
		"Accepted damage preserves the committed Black Water Cast while updating health"
	)
	fixture.expect(
		sword_cooldown.time_left < sword_cooldown_at_cast_start,
		"Sword Gleam cooldown continues independently during Black Water Cast"
	)

	await recover_player(player)
	player.set_physics_process(true)
	await verify_contact_damage(player, valdemar, "Black Water Cast")
	player.set_physics_process(false)
	player.global_position = valdemar.global_position + Vector2(-1000.0, -5000.0)
	await recover_player(player)
	var player_health_without_black_water_effect := int(player.call("get_current_health"))
	var level_node_count := current_scene.find_children("*", "", true, false).size()

	await fixture.wait_seconds(
		maxf(2.75 - animation_state.get_current_play_position(), 0.0)
	)
	var penultimate_texture := dark_mode.texture
	await fixture.wait_seconds(0.40)
	var final_texture := dark_mode.texture
	fixture.expect(
		animation_state.get_current_node() == &"skill"
		and animation_state.get_current_play_position() >= 3.0
		and final_texture != penultimate_texture,
		"Black Water reaches its ninth presentation frame at three seconds"
	)
	await fixture.wait_seconds(
		maxf(5.70 - animation_state.get_current_play_position(), 0.0)
	)
	fixture.expect(
		animation_state.get_current_node() == &"skill"
		and dark_mode.texture == final_texture
		and valdemar.global_position == cast_position
		and dark_mode.flip_h == cast_facing
		and attack_start_frames.size() == 2,
		"Black Water holds its final frame and locked aim through the remaining three seconds"
	)
	fixture.expect(
		black_water_notifications[0] == 1
		and player.call("get_current_health") == player_health_without_black_water_effect
		and current_scene.find_children("*", "", true, false).size() == level_node_count
		and sword_cooldown.is_stopped(),
		"One Black Water request adds no effect or damage while Sword Gleam cooldown completes"
	)

	await fixture.wait_seconds(0.35)
	await fixture.physics_frames(2)
	fixture.expect(
		animation_state.get_current_node() != &"skill"
		and black_water_notifications[0] == 1,
		"Black Water Cast completes after six seconds without accumulating another cast"
	)

	skill_animation.length = 0.15
	player.global_position = Vector2(
		valdemar.global_position.x + absf(valdemar.get_node("SwordGleam").position.x),
		valdemar.global_position.y
	)
	black_water_cooldown.process_callback = Timer.TIMER_PROCESS_PHYSICS
	black_water_cooldown.start(0.001)
	black_water_cooldown.wait_time = 16.0
	for _frame in 2:
		await fixture.physics_frames(1)
		if animation_state.get_current_node() == &"skill":
			break
	fixture.expect(
		animation_state.get_current_node() == &"skill"
		and black_water_notifications[0] == 2
		and attack_start_frames.size() == 2,
		"A due Black Water Cast wins over an aligned Sword Gleam that has not started"
	)
	player.global_position = valdemar.global_position + Vector2(-1000.0, -5000.0)
	await fixture.wait_seconds(0.20)
	await fixture.physics_frames(1)

	var health_before_pending_hurt := int(valdemar.call("get_current_health"))
	valdemar.take_damage(1, Vector2.ZERO)
	await fixture.physics_frames(1)
	fixture.expect(
		valdemar.call("get_current_health") == health_before_pending_hurt - 1
		and animation_state.get_current_node() == &"hurt",
		"Pursuit damage begins Valdemar Hurt before the next Black Water due condition"
	)
	await make_black_water_due_twice(black_water_cooldown)
	fixture.expect(
		animation_state.get_current_node() == &"hurt"
		and black_water_notifications[0] == 2,
		"Repeated Black Water due conditions remain pending until Valdemar Hurt finishes"
	)
	for _frame in 30:
		await fixture.physics_frames(1)
		if black_water_notifications[0] == 3:
			break
	await fixture.physics_frames(1)
	fixture.expect(
		black_water_notifications[0] == 3
		and animation_state.get_current_node() == &"skill",
		"One pending Black Water Cast starts immediately after Hurt"
	)
	fixture.expect(
		black_water_cooldown.time_left > 15.8,
		"The cycle after Hurt restarts when the delayed Black Water Cast begins"
	)
	await fixture.wait_seconds(0.40)
	fixture.expect(
		black_water_notifications[0] == 3
		and animation_state.get_current_node() != &"skill",
		"Repeated due conditions cannot accumulate multiple pending Black Water Casts"
	)


func make_black_water_due_twice(black_water_cooldown: Timer) -> void:
	black_water_cooldown.start(0.02)
	await fixture.wait_seconds(0.04)
	black_water_cooldown.start(0.02)
	await fixture.wait_seconds(0.04)
	black_water_cooldown.wait_time = 16.0


func verify_defeat_preempts_every_dark_action() -> void:
	for scenario in DEFEAT_SCENARIOS:
		await verify_defeat_preempts_scenario(scenario)


func verify_defeat_preempts_scenario(scenario_name: StringName) -> void:
	var actors := await instantiate_active_valdemar()
	var level := actors["level"] as CampaignLevel
	var player := actors["player"] as DamageableActor
	var valdemar := actors["valdemar"] as DamageableActor
	if level == null or player == null or valdemar == null:
		fixture.expect(
			false,
			"Valdemar Defeat %s scenario loads production actors" % scenario_name
		)
		return

	var dark_mode := valdemar.get_node("DarkMode") as Sprite2D
	var dying := valdemar.get_node("Dying") as Sprite2D
	var body_collision := valdemar.get_node("CollisionShape2D") as CollisionShape2D
	var hurt_box := valdemar.get_node("HurtBox") as Area2D
	var hurt_box_collision := hurt_box.get_node("CollisionShape2D") as CollisionShape2D
	var health_bar_root := valdemar.get_node("HealthBar") as CanvasItem
	var sword_gleam := valdemar.get_node("SwordGleam") as Area2D
	var sword_collision := sword_gleam.get_node("CollisionShape2D") as CollisionShape2D
	var sword_cooldown := valdemar.get_node("SwordGleamCooldown") as Timer
	var black_water_cooldown := valdemar.get_node("BlackWaterCooldown") as Timer
	var animation_tree := valdemar.get_node("AnimationTree") as AnimationTree
	var animation_state := animation_tree.get(
		"parameters/playback"
	) as AnimationNodeStateMachinePlayback
	var death_notifications := [0]
	var black_water_notifications := [0]
	var campaign_outcomes: Array[StringName] = []
	valdemar.connect(&"died", func() -> void: death_notifications[0] += 1)
	valdemar.connect(
		&"black_water_requested",
		func() -> void: black_water_notifications[0] += 1
	)
	level.campaign_outcome_reached.connect(
		func(outcome: StringName) -> void: campaign_outcomes.append(outcome)
	)

	await prepare_defeat_scenario(
		scenario_name,
		player,
		valdemar,
		animation_state,
		sword_cooldown,
		black_water_cooldown,
		black_water_notifications
	)
	var notifications_before_defeat := int(black_water_notifications[0])
	var late_target := add_late_sword_target(sword_gleam.global_position, level)
	var defeat_position := valdemar.global_position
	var defeat_facing := dark_mode.flip_h
	if scenario_name == &"active_black_water":
		fixture.expect(
			defeat_facing,
			"Active Black Water Defeat scenario holds the non-default east facing"
		)
	if scenario_name != &"hurt":
		fixture.expect(
			bool(valdemar.call("apply_debug_health_override", 1)),
			"Valdemar Defeat %s scenario sets one remaining health" % scenario_name
		)

	valdemar.take_damage(1, Vector2(1000.0, -1000.0))
	fixture.expect(
		valdemar.call("is_health_depleted")
		and valdemar.call("get_current_health") == 0
		and not valdemar.is_physics_processing()
		and valdemar.velocity == Vector2.ZERO
		and valdemar.global_position == defeat_position
		and not health_bar_root.visible,
		"Lethal damage immediately ends movement and Health Presentation during %s"
		% scenario_name
	)
	fixture.expect(
		valdemar.collision_layer == 0
		and valdemar.collision_mask == 0
		and hurt_box.collision_layer == 0
		and hurt_box.collision_mask == 0
		and sword_gleam.collision_layer == 0
		and sword_gleam.collision_mask == 0,
		"Valdemar Defeat immediately removes combat collision during %s" % scenario_name
	)
	fixture.expect(
		sword_cooldown.is_stopped()
		and black_water_cooldown.is_stopped()
		and not bool(sword_gleam.get("is_cast_active"))
		and animation_state.get_current_node() == &"dead"
		and dark_mode.visible
		and not dying.visible
		and dark_mode.flip_h == defeat_facing
		and death_notifications[0] == 0,
		"Valdemar Defeat immediately cancels attacks and begins direction-preserving death during %s"
		% scenario_name
	)

	await fixture.physics_frames(1)
	fixture.expect(
		body_collision.disabled
		and hurt_box_collision.disabled
		and sword_collision.disabled,
		"Valdemar Defeat disables every combat shape during %s" % scenario_name
	)
	var player_health_after_defeat := int(player.call("get_current_health"))
	(player.get_node("VisualRoot/ShieldSkill/Shield") as CanvasItem).hide()
	player.global_position = valdemar.global_position + Vector2(-55.0, 0.0)
	player.set_physics_process(true)
	Input.action_press("right")
	await fixture.physics_frames(12)
	Input.action_release("right")
	await fixture.wait_seconds(0.45)
	fixture.expect(
		animation_state.get_current_node() == &"dead"
		and death_notifications[0] == 0
		and dark_mode.visible
		and not dying.visible
		and valdemar.global_position == defeat_position
		and dark_mode.flip_h == defeat_facing,
		"Valdemar plays the complete dead presentation during %s" % scenario_name
	)
	fixture.expect(
		player.call("get_current_health") == player_health_after_defeat
		and late_target.damage_received == 0
		and black_water_notifications[0] == notifications_before_defeat,
		"Valdemar Defeat prevents late contact, Sword Gleam, and Black Water effects during %s"
		% scenario_name
	)

	await fixture.wait_seconds(EXPECTED_DEAD_DURATION - 0.55)
	await fixture.process_frames(2)
	fixture.expect(
		is_instance_valid(valdemar)
		and valdemar.get_parent() == level.get_node("Enemies")
		and valdemar.is_visible_in_tree()
		and not dark_mode.visible
		and dying.visible
		and dying.flip_h == defeat_facing
		and valdemar.global_position == defeat_position,
		"Valdemar retains the direction-preserving Dying presentation after %s"
		% scenario_name
	)
	fixture.expect(
		death_notifications[0] == 1
		and campaign_outcomes.is_empty()
		and level.get_node_or_null("VictoryStory") == null,
		"Valdemar Dying emits one Defeat event without Level Completion during %s"
		% scenario_name
	)
	await fixture.wait_seconds(0.60)
	fixture.expect(
		is_instance_valid(valdemar)
		and dying.visible
		and death_notifications[0] == 1
		and campaign_outcomes.is_empty()
		and sword_cooldown.is_stopped()
		and black_water_cooldown.is_stopped()
		and black_water_notifications[0] == notifications_before_defeat,
		"Valdemar remains owned, terminal, and non-interactive after %s" % scenario_name
	)

	if current_scene == level:
		current_scene = null
	level.free()


func instantiate_active_valdemar() -> Dictionary:
	var level := fixture.instantiate_scene(LEVEL_04_SCENE) as CampaignLevel
	fixture.set_current_scene(level)
	await fixture.process_frames(2)
	fixture.set_paused(false)
	var player := level.get_node_or_null("Player") as DamageableActor
	var valdemar := level.get_node_or_null("Enemies/Valdemar") as DamageableActor
	if player == null or valdemar == null:
		return {"level": level, "player": player, "valdemar": valdemar}

	player.set_physics_process(false)
	player.global_position = valdemar.global_position + Vector2(-500.0, -5000.0)
	for _frame in 70:
		await fixture.physics_frames(1)
		if valdemar.is_physics_processing():
			break
	fixture.expect(
		valdemar.is_physics_processing(),
		"Production Valdemar reaches Dark Mode for a Defeat scenario"
	)
	return {"level": level, "player": player, "valdemar": valdemar}


func prepare_defeat_scenario(
	scenario_name: StringName,
	player: DamageableActor,
	valdemar: DamageableActor,
	animation_state: AnimationNodeStateMachinePlayback,
	sword_cooldown: Timer,
	black_water_cooldown: Timer,
	black_water_notifications: Array
) -> void:
	var sword_gleam := valdemar.get_node("SwordGleam") as Area2D
	player.global_position = valdemar.global_position + Vector2(-1000.0, 0.0)
	await fixture.physics_frames(1)
	player.global_position.y = valdemar.global_position.y - 5000.0
	await fixture.physics_frames(2)
	match scenario_name:
		&"pursuit":
			fixture.expect(
				animation_state.get_current_node() == &"run",
				"Valdemar Defeat scenario begins during Pursuit"
			)
		&"waiting":
			player.global_position = Vector2(
				valdemar.global_position.x - absf(sword_gleam.position.x),
				valdemar.global_position.y - 100.0
			)
			await fixture.physics_frames(2)
			await fixture.wait_seconds(0.55)
			await fixture.physics_frames(2)
			fixture.expect(
				animation_state.get_current_node() == &"idle"
				and not sword_cooldown.is_stopped(),
				"Valdemar Defeat scenario begins while aligned and waiting"
			)
		&"hurt":
			fixture.expect(
				bool(valdemar.call("apply_debug_health_override", 2)),
				"Valdemar Hurt Defeat scenario sets two remaining health"
			)
			valdemar.take_damage(1, Vector2.ZERO)
			await fixture.physics_frames(1)
			fixture.expect(
				animation_state.get_current_node() == &"hurt"
				and valdemar.call("is_hurt_immune")
				and valdemar.call("get_current_health") == 1,
				"Valdemar Defeat scenario begins during Hurt"
			)
		&"sword_gleam", &"pending_black_water":
			player.global_position = Vector2(
				valdemar.global_position.x - absf(sword_gleam.position.x),
				valdemar.global_position.y
			)
			await fixture.physics_frames(2)
			fixture.expect(
				animation_state.get_current_node() == &"attack",
				"Valdemar Defeat scenario begins during Sword Gleam"
			)
			if scenario_name == &"pending_black_water":
				black_water_cooldown.process_callback = Timer.TIMER_PROCESS_PHYSICS
				black_water_cooldown.start(0.001)
				await fixture.physics_frames(2)
				fixture.expect(
					animation_state.get_current_node() == &"attack"
					and black_water_notifications[0] == 0,
					"Valdemar Defeat scenario includes one pending Black Water Cast"
				)
		&"active_black_water":
			player.global_position = valdemar.global_position + Vector2(1000.0, -5000.0)
			await fixture.physics_frames(2)
			black_water_cooldown.process_callback = Timer.TIMER_PROCESS_PHYSICS
			black_water_cooldown.start(0.001)
			await fixture.physics_frames(2)
			fixture.expect(
				animation_state.get_current_node() == &"skill"
				and black_water_notifications[0] == 1,
				"Valdemar Defeat scenario begins during an active Black Water Cast"
			)
		_:
			fixture.expect(false, "Unknown Valdemar Defeat scenario: %s" % scenario_name)


func add_late_sword_target(position: Vector2, parent: Node) -> CountingDamageableActor:
	var target := CountingDamageableActor.new()
	target.collision_layer = PLAYER_LAYER
	target.collision_mask = 1 << 2
	target.global_position = position
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20.0, 20.0)
	collision.shape = shape
	target.add_child(collision)
	fixture.add_node(target, parent)
	return target


func add_weapon_hit(position: Vector2) -> Area2D:
	var weapon := Area2D.new()
	weapon.add_to_group("weapons")
	weapon.collision_layer = PLAYER_LAYER
	weapon.collision_mask = 1 << 2
	weapon.global_position = position
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20.0, 20.0)
	collision.shape = shape
	weapon.add_child(collision)
	fixture.add_node(weapon, current_scene)
	return weapon


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
