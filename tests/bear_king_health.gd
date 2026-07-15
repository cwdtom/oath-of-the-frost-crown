extends SceneTree


const BEAR_KING_SCENE := preload("res://enemies/bear_king.tscn")
const EnemyHarness := preload("res://tests/enemy_scene_harness.gd")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const HURT_ANIMATION := &"hurt"
const SKILL_ANIMATION := &"skill"
const EARTHQUAKE_CAST_ANIMATION := &"cast"
const EXPECTED_HEALTH := 15
const EARTHQUAKE_OFFSET := Vector2(-228.0, 72.0)

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

	await test_earthquake_damage_and_cooldown()
	await test_damage_faces_attacker_and_interrupts_earthquake()

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func test_earthquake_damage_and_cooldown() -> void:
	var bear_king_position := Vector2(3500.0, 0.0)
	var bear_king := harness.instantiate_enemy(
		BEAR_KING_SCENE,
		bear_king_position,
		{"idle_duration": 10.0}
	)
	var hurt_event_count: Array[int] = [0]
	var player := harness.instantiate_passive_player(
		bear_king_position + EARTHQUAKE_OFFSET,
		func() -> void: hurt_event_count[0] += 1
	)

	await fixture.physics_frames(3)
	await fixture.wait_seconds(0.05)
	fixture.expect(
		harness.is_playing(bear_king, SKILL_ANIMATION),
		"Gameplay detection starts BearKing earthquake"
	)
	fixture.expect(
		harness.is_playing(bear_king, EARTHQUAKE_CAST_ANIMATION),
		"BearKing starts the shared earthquake presentation"
	)
	var skill_start_x := bear_king.global_position.x
	# Observe after the impact frame and before the one-second skill completes.
	await fixture.wait_seconds(0.8)
	await fixture.physics_frames(1)
	fixture.expect(hurt_event_count[0] == 1, "BearKing earthquake deals one point of damage once")
	await fixture.wait_seconds(0.3)
	fixture.expect(
		not harness.is_playing(bear_king, SKILL_ANIMATION),
		"BearKing earthquake completes once"
	)
	fixture.expect(
		is_equal_approx(bear_king.global_position.x, skill_start_x),
		"BearKing remains stationary during earthquake"
	)

	await harness.reenter_skill_detection(player, bear_king_position + EARTHQUAKE_OFFSET)
	fixture.expect(
		not harness.is_playing(bear_king, SKILL_ANIMATION),
		"BearKing cannot earthquake during cooldown"
	)
	await fixture.wait_seconds(1.45)
	await harness.reenter_skill_detection(player, bear_king_position + EARTHQUAKE_OFFSET)
	fixture.expect(
		not harness.is_playing(bear_king, SKILL_ANIMATION),
		"BearKing preserves its full three second earthquake cooldown"
	)
	await fixture.wait_seconds(0.55)
	await harness.reenter_skill_detection(player, bear_king_position + EARTHQUAKE_OFFSET)
	fixture.expect(
		harness.is_playing(bear_king, SKILL_ANIMATION),
		"BearKing can earthquake after cooldown"
	)


func test_damage_faces_attacker_and_interrupts_earthquake() -> void:
	var bear_king_position := Vector2(5500.0, 0.0)
	var bear_king := harness.instantiate_enemy(
		BEAR_KING_SCENE,
		bear_king_position,
		{"idle_duration": 10.0}
	)
	var hurt_event_count: Array[int] = [0]
	harness.instantiate_passive_player(
		bear_king_position + EARTHQUAKE_OFFSET,
		func() -> void: hurt_event_count[0] += 1
	)
	await fixture.physics_frames(3)
	await fixture.wait_seconds(0.05)
	fixture.expect(
		harness.is_playing(bear_king, SKILL_ANIMATION),
		"BearKing is vulnerable during earthquake"
	)

	await harness.deliver_hit(bear_king, Vector2(-50.0, 0.0))
	fixture.expect(
		bear_king.get_current_health() == EXPECTED_HEALTH - 1,
		"Weapon contact damages a vulnerable BearKing"
	)
	fixture.expect(
		harness.is_playing(bear_king, HURT_ANIMATION),
		"Accepted damage starts BearKing hurt presentation"
	)
	fixture.expect(
		not harness.enemy_sprite_is_flipped(bear_king),
		"BearKing faces an attacker on its left"
	)
	fixture.expect(
		is_equal_approx(bear_king.global_position.x, bear_king_position.x + 100.0),
		"BearKing keeps its 100 pixel hurt knockback"
	)
	fixture.expect(
		not harness.is_playing(bear_king, EARTHQUAKE_CAST_ANIMATION),
		"Accepted damage interrupts BearKing earthquake"
	)

	await fixture.wait_seconds(0.45)
	await harness.deliver_hit(bear_king, Vector2(50.0, 0.0))
	fixture.expect(
		bear_king.get_current_health() == EXPECTED_HEALTH - 2,
		"Later weapon contact delivers damage after recovery"
	)
	fixture.expect(
		harness.enemy_sprite_is_flipped(bear_king),
		"BearKing faces an attacker on its right"
	)
	await fixture.wait_seconds(0.3)
	fixture.expect(hurt_event_count[0] == 0, "Interrupted BearKing earthquake never reaches impact")
