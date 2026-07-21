extends SceneTree


const WOLF_SCENE := preload("res://enemies/wolf.tscn")
const PLAYER_04_SCENE := preload("res://player/player_04.tscn")
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
	await test_persistent_contact_retriggers_after_hurt_immunity()
	await test_contact_started_during_hurt_immunity_damages_afterward()
	await test_separated_enemy_does_not_retrigger_contact_damage()
	await test_simultaneous_contacts_deal_only_one_damage()
	await test_contact_source_without_damage_capability_does_not_retrigger()
	await test_persistent_contact_damages_after_shield_break_window()
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
	await fixture.wait_seconds(0.95)
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

	await fixture.wait_seconds(0.95)
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

	await fixture.wait_seconds(0.95)
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

	await fixture.wait_seconds(0.95)
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

	await fixture.wait_seconds(0.95)
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
