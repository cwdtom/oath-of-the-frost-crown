extends SceneTree


const WOLF_SCENE := preload("res://enemies/wolf.tscn")
const PLAYER_04_SCENE := preload("res://player/player_04.tscn")
const EnemyHarness := preload("res://tests/enemy_scene_harness.gd")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const DASH_DISTANCE := 300.0
const SKILL_ANIMATION := &"skill"
const WOLF_DASH_WARNING_DURATION := 0.7
const PLAYER_HURT_IMMUNITY_WAIT := 1.55

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
	await test_persistent_contact_retriggers_after_hurt_immunity()
	await test_contact_started_during_hurt_immunity_damages_afterward()
	await test_separated_enemy_does_not_retrigger_contact_damage()
	await test_simultaneous_contacts_deal_only_one_damage()
	await test_contact_source_without_damage_capability_does_not_retrigger()
	await test_persistent_contact_damages_after_shield_break_window()
	await test_close_player_receives_warning_before_dash()
	await test_left_facing_wolf_warns_close_player_on_left()
	await test_skill_detection_area_controls_warning()
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


func test_persistent_contact_retriggers_after_hurt_immunity() -> void:
	var wolf_position := Vector2(2500.0, 0.0)
	var wolf := harness.instantiate_enemy(
		WOLF_SCENE,
		wolf_position,
		{"idle_duration": 10.0}
	)
	var wall := harness.add_environment_wall(
		wolf_position + Vector2(-93.0, 0.0),
		Vector2(20.0, 200.0)
	)
	var player := harness.instantiate_actor(
		preload("res://player/player.tscn"),
		wolf_position + Vector2(-65.0, 0.0)
	)
	var hurt_event_count: Array[int] = [0]
	var hurt_physics_frames: Array[int] = []
	player.connect(
		&"hurt_taken",
		func() -> void:
			hurt_event_count[0] += 1
			hurt_physics_frames.append(Engine.get_physics_frames())
	)
	player.velocity = Vector2(600.0, 0.0)

	await fixture.physics_frames(2)
	fixture.expect(
		hurt_event_count[0] == 1,
		"Persistent Enemy contact first damages Player once"
	)
	player.set_physics_process(false)
	await fixture.wait_seconds(PLAYER_HURT_IMMUNITY_WAIT)
	fixture.expect(
		hurt_event_count[0] == 1 and not player.is_hurt_immune(),
		"Persistent contact waits while Player physics is suspended"
	)
	var first_reenabled_physics_frame := Engine.get_physics_frames() + 1
	player.set_physics_process(true)
	await fixture.physics_frames(2)
	fixture.expect(
		(
			hurt_event_count[0] == 2
			and player.get_current_health() == 3
			and hurt_physics_frames[-1] == first_reenabled_physics_frame
		),
		(
			"Persistent Enemy contact immediately damages Player after hurt immunity; "
			+ "hurt_events=%s health=%s player_x=%s wolf_x=%s"
			% [
				hurt_event_count[0],
				player.get_current_health(),
				player.global_position.x,
				wolf.global_position.x,
			]
		)
	)

	wolf.queue_free()
	wall.queue_free()
	player.queue_free()
	await fixture.process_frames(1)


func test_contact_started_during_hurt_immunity_damages_afterward() -> void:
	var wolf_position := Vector2(3500.0, 0.0)
	var wolf := harness.instantiate_enemy(
		WOLF_SCENE,
		wolf_position,
		{"idle_duration": 10.0}
	)
	var wall := harness.add_environment_wall(
		wolf_position + Vector2(-93.0, 0.0),
		Vector2(20.0, 200.0)
	)
	var player := harness.instantiate_actor(
		preload("res://player/player.tscn"),
		wolf_position + Vector2(-300.0, 0.0)
	)
	var hurt_event_count: Array[int] = [0]
	player.connect(&"hurt_taken", func() -> void: hurt_event_count[0] += 1)
	player.set_physics_process(false)
	player.take_damage(1, Vector2.ZERO)
	player.global_position = wolf_position + Vector2(-65.0, 0.0)

	await fixture.wait_seconds(PLAYER_HURT_IMMUNITY_WAIT)
	player.set_physics_process(true)
	await fixture.physics_frames(2)
	fixture.expect(
		hurt_event_count[0] == 2 and player.get_current_health() == 3,
		"Enemy contact started during hurt immunity damages Player afterward"
	)

	wolf.queue_free()
	wall.queue_free()
	player.queue_free()
	await fixture.process_frames(1)


func test_separated_enemy_does_not_retrigger_contact_damage() -> void:
	var wolf_position := Vector2(4000.0, 0.0)
	var wolf := harness.instantiate_enemy(
		WOLF_SCENE,
		wolf_position,
		{"idle_duration": 10.0}
	)
	var player := harness.instantiate_actor(
		preload("res://player/player.tscn"),
		wolf_position + Vector2(-300.0, 0.0)
	)
	var hurt_event_count: Array[int] = [0]
	player.connect(&"hurt_taken", func() -> void: hurt_event_count[0] += 1)
	player.set_physics_process(false)
	player.take_damage(1, Vector2.ZERO)
	player.global_position = wolf_position + Vector2(-68.0, 0.0)

	await fixture.wait_seconds(PLAYER_HURT_IMMUNITY_WAIT)
	player.set_physics_process(true)
	await fixture.physics_frames(2)
	fixture.expect(
		hurt_event_count[0] == 1 and player.get_current_health() == 4,
		"Separated Enemy cannot retrigger persistent contact damage"
	)

	wolf.queue_free()
	player.queue_free()
	await fixture.process_frames(1)


func test_simultaneous_contacts_deal_only_one_damage() -> void:
	var player_position := Vector2(4500.0, 0.0)
	var left_wolf := harness.instantiate_enemy(
		WOLF_SCENE,
		player_position + Vector2(-65.0, 0.0),
		{"idle_duration": 10.0}
	)
	var right_wolf := harness.instantiate_enemy(
		WOLF_SCENE,
		player_position + Vector2(65.0, 0.0),
		{"idle_duration": 10.0}
	)
	var player := harness.instantiate_actor(
		preload("res://player/player.tscn"),
		player_position
	)
	var hurt_event_count: Array[int] = [0]
	player.connect(&"hurt_taken", func() -> void: hurt_event_count[0] += 1)
	player.set_physics_process(false)
	player.take_damage(1, Vector2.ZERO)

	await fixture.wait_seconds(PLAYER_HURT_IMMUNITY_WAIT)
	player.set_physics_process(true)
	await fixture.physics_frames(2)
	fixture.expect(
		hurt_event_count[0] == 2 and player.get_current_health() == 3,
		"Simultaneous Enemy contacts deal only one damage after hurt immunity"
	)

	left_wolf.queue_free()
	right_wolf.queue_free()
	player.queue_free()
	await fixture.process_frames(1)


func test_contact_source_without_damage_capability_does_not_retrigger() -> void:
	var wolf_position := Vector2(5500.0, 0.0)
	var wolf := harness.instantiate_enemy(
		WOLF_SCENE,
		wolf_position,
		{"idle_duration": 10.0}
	)
	var wall := harness.add_environment_wall(
		wolf_position + Vector2(-93.0, 0.0),
		Vector2(20.0, 200.0)
	)
	var player := harness.instantiate_actor(
		preload("res://player/player.tscn"),
		wolf_position + Vector2(-300.0, 0.0)
	)
	var hurt_event_count: Array[int] = [0]
	player.connect(&"hurt_taken", func() -> void: hurt_event_count[0] += 1)
	player.take_damage(1, Vector2.ZERO)
	player.global_position = wolf_position + Vector2(-65.0, 0.0)
	wolf.remove_from_group("enemies")

	await fixture.wait_seconds(PLAYER_HURT_IMMUNITY_WAIT)
	await fixture.physics_frames(1)
	fixture.expect(
		hurt_event_count[0] == 1 and player.get_current_health() == 4,
		"Contact source without Enemy damage capability cannot damage Player"
	)

	wolf.queue_free()
	wall.queue_free()
	player.queue_free()
	await fixture.process_frames(1)


func test_persistent_contact_damages_after_shield_break_window() -> void:
	var wolf_position := Vector2(6500.0, 0.0)
	var wolf := harness.instantiate_enemy(
		WOLF_SCENE,
		wolf_position,
		{"idle_duration": 10.0}
	)
	var wall := harness.add_environment_wall(
		wolf_position + Vector2(-93.0, 0.0),
		Vector2(20.0, 200.0)
	)
	var player := harness.instantiate_actor(
		PLAYER_04_SCENE,
		wolf_position + Vector2(-65.0, 0.0)
	)
	var hurt_event_count: Array[int] = [0]
	player.connect(&"hurt_taken", func() -> void: hurt_event_count[0] += 1)

	await fixture.physics_frames(2)
	fixture.expect(
		hurt_event_count[0] == 0 and player.get_current_health() == 8,
		"Available Player Shield negates persistent Enemy contact"
	)
	await fixture.wait_seconds(0.5)
	await fixture.physics_frames(1)
	fixture.expect(
		hurt_event_count[0] == 1 and player.get_current_health() == 7,
		"Persistent Enemy contact damages Player after Shield Break Window"
	)

	wolf.queue_free()
	wall.queue_free()
	player.queue_free()
	await fixture.process_frames(1)


func test_close_player_receives_warning_before_dash() -> void:
	var wolf_position := Vector2(7500.0, 0.0)
	var wolf := harness.instantiate_enemy(
		WOLF_SCENE,
		wolf_position,
		{"idle_duration": 10.0}
	)
	var hurt_event_count: Array[int] = [0]
	var player := harness.instantiate_passive_player(
		wolf_position + Vector2(61.0, 0.0),
		func() -> void: hurt_event_count[0] += 1
	)
	var warning := wolf.get_node("WarnMark") as Node2D

	await fixture.physics_frames(3)
	fixture.expect(
		warning.visible
		and wolf.global_position.is_equal_approx(wolf_position)
		and hurt_event_count[0] == 0,
		(
			"Close Player presence starts a stationary Wolf Dash Warning before damage; "
			+ "visible=%s position=%s hurt_events=%s"
			% [warning.visible, wolf.global_position, hurt_event_count[0]]
		)
	)
	await fixture.wait_seconds(WOLF_DASH_WARNING_DURATION - 0.1)
	fixture.expect(
		warning.visible
		and wolf.global_position.is_equal_approx(wolf_position)
		and hurt_event_count[0] == 0,
		"Wolf Dash Warning remains stationary and harmless for its full duration"
	)
	await fixture.wait_seconds(0.15)
	await fixture.physics_frames(2)
	fixture.expect(
		not warning.visible and hurt_event_count[0] == 1,
		"Close Wolf dash begins and damages Player only after its warning"
	)

	wolf.queue_free()
	player.queue_free()
	await fixture.process_frames(1)


func test_left_facing_wolf_warns_close_player_on_left() -> void:
	var wolf := harness.instantiate_enemy(
		WOLF_SCENE,
		Vector2(8500.0, 0.0),
		{"idle_duration": 0.0, "patrol_range": 20.0}
	)
	for _frame in 60:
		await fixture.physics_frames(1)
		if harness.enemy_sprite_is_flipped(wolf):
			break
	var warning_position := wolf.global_position
	var player := harness.instantiate_passive_player(
		warning_position + Vector2(-70.0, 0.0),
		func() -> void: pass
	)
	var warning := wolf.get_node("WarnMark") as Node2D

	await fixture.physics_frames(3)
	fixture.expect(
		harness.enemy_sprite_is_flipped(wolf)
		and warning.visible
		and wolf.global_position.is_equal_approx(warning_position),
		(
			"Left-facing Wolf warns a close Player on its left before dashing; "
			+ "flipped=%s visible=%s start=%s current=%s overlaps=%s"
			% [
				harness.enemy_sprite_is_flipped(wolf),
				warning.visible,
				warning_position,
				wolf.global_position,
				(wolf.get_node("SkillDetect") as Area2D).get_overlapping_bodies().size(),
			]
		)
	)

	wolf.queue_free()
	player.queue_free()
	await fixture.process_frames(1)


func test_skill_detection_area_controls_warning() -> void:
	var wolf_position := Vector2(9500.0, 0.0)
	var wolf := harness.instantiate_enemy(
		WOLF_SCENE,
		wolf_position,
		{"idle_duration": 10.0}
	)
	var player := harness.instantiate_passive_player(
		wolf_position + Vector2(450.0, 0.0),
		func() -> void: pass
	)
	var warning := wolf.get_node("WarnMark") as Node2D

	await fixture.wait_seconds(WOLF_DASH_WARNING_DURATION + 0.1)
	fixture.expect(
		not warning.visible and wolf.global_position.is_equal_approx(wolf_position),
		"Player beyond Wolf Skill Detection Area does not start a warning"
	)
	await harness.reenter_skill_detection(
		player,
		wolf_position + Vector2(100.0, 0.0)
	)
	fixture.expect(
		warning.visible and wolf.global_position.is_equal_approx(wolf_position),
		(
			"Player entering Wolf Skill Detection Area starts a warning; "
			+ "visible=%s position=%s overlaps=%s"
			% [
				warning.visible,
				wolf.global_position,
				(wolf.get_node("SkillDetect") as Area2D).get_overlapping_bodies().size(),
			]
		)
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
	var warning := wolf.get_node("WarnMark") as Node2D

	await fixture.physics_frames(3)
	fixture.expect(
		warning.visible and wolf.global_position.is_equal_approx(start_position),
		"Gameplay detection starts a stationary Wolf Dash Warning"
	)
	player.position = start_position - Vector2(1000.0, 0.0)
	await fixture.wait_seconds(WOLF_DASH_WARNING_DURATION)
	fixture.expect(
		wolf.global_position.x > start_position.x
		and harness.is_playing(wolf, SKILL_ANIMATION),
		"Wolf completes its committed warning after Player leaves and starts its dash"
	)
	var speed_sample_x := wolf.global_position.x
	await fixture.physics_frames(7)
	fixture.expect(
		absf(wolf.global_position.x - speed_sample_x - 40.0) <= 1.0,
		(
			"Wolf keeps its 400 pixel per second dash speed; "
			+ "sample_x=%s current_x=%s"
			% [speed_sample_x, wolf.global_position.x]
		)
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
	await fixture.wait_seconds(0.2)
	fixture.expect(
		not warning.visible and is_equal_approx(wolf.global_position.x, dash_end_x),
		"Wolf cannot start another warning during dash cooldown"
	)
	await fixture.wait_seconds(3.2)
	await harness.reenter_skill_detection(player, wolf.global_position + Vector2(100.0, 0.0))
	await fixture.wait_seconds(0.1)
	fixture.expect(
		not warning.visible and is_equal_approx(wolf.global_position.x, dash_end_x),
		"Wolf keeps the full five second cooldown from dash start"
	)
	await fixture.wait_seconds(0.6)
	fixture.expect(
		warning.visible and is_equal_approx(wolf.global_position.x, dash_end_x),
		"Persistent Player presence starts another warning when cooldown expires"
	)
	await fixture.wait_seconds(WOLF_DASH_WARNING_DURATION)
	await fixture.physics_frames(3)
	fixture.expect(wolf.global_position.x > dash_end_x, "Wolf dashes again after its next warning")
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
	var warning := wolf.get_node("WarnMark") as Node2D
	var health_before_skill: int = wolf.get_current_health()
	await fixture.physics_frames(3)

	var early_weapon := harness.add_weapon(wolf.global_position)
	await fixture.physics_frames(3)
	early_weapon.queue_free()
	fixture.expect(
		warning.visible and wolf.get_current_health() == health_before_skill,
		"Wolf Dash Warning grants weapon immunity"
	)
	await fixture.wait_seconds(WOLF_DASH_WARNING_DURATION)
	var late_weapon := harness.add_weapon(wolf.global_position)
	await fixture.physics_frames(3)
	late_weapon.queue_free()
	fixture.expect(
		wolf.get_current_health() == health_before_skill,
		"Wolf dash keeps the warning's weapon immunity"
	)
	await fixture.wait_seconds(0.8)

	fixture.expect(hurt_event_count[0] == 1, "One Wolf dash collision damages Player once")
	fixture.expect(
		player.global_position.x > player_start.x,
		"Wolf dash knocks Player away from collision"
	)
	await harness.deliver_hit(wolf, Vector2(-20.0, 0.0))
	fixture.expect(
		wolf.is_in_group("enemies")
		and wolf.get_current_health() == health_before_skill - 1,
		"Wolf accepts weapon damage after its warning and dash immunity end"
	)
