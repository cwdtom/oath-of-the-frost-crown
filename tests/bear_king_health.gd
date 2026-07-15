extends SceneTree


const BEAR_KING_SCENE := preload("res://enemies/bear_king.tscn")
const EnemyHarness := preload("res://tests/enemy_scene_harness.gd")
const HURT_ANIMATION := &"hurt"
const SKILL_ANIMATION := &"skill"
const EARTHQUAKE_CAST_ANIMATION := &"cast"
const EXPECTED_HEALTH := 15
const EARTHQUAKE_OFFSET := Vector2(-228.0, 72.0)

var failures: Array[String] = []
var harness: EnemySceneHarness


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	ProjectSettings.set_setting("physics/2d/default_gravity", 0.0)
	harness = EnemyHarness.new(self)

	await test_earthquake_damage_and_cooldown()
	await test_damage_faces_attacker_and_interrupts_earthquake()

	paused = false
	ProjectSettings.set_setting("physics/2d/default_gravity", original_gravity)
	harness.cleanup()
	await process_frame
	await process_frame
	finish()


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

	await harness.physics_frames(3)
	await create_timer(0.05).timeout
	expect(harness.is_playing(bear_king, SKILL_ANIMATION), "Gameplay detection starts BearKing earthquake")
	expect(
		harness.is_playing(bear_king, EARTHQUAKE_CAST_ANIMATION),
		"BearKing starts the shared earthquake presentation"
	)
	var skill_start_x := bear_king.global_position.x
	# Observe after the impact frame and before the one-second skill completes.
	await create_timer(0.8).timeout
	await physics_frame
	expect(hurt_event_count[0] == 1, "BearKing earthquake deals one point of damage once")
	await create_timer(0.3).timeout
	expect(not harness.is_playing(bear_king, SKILL_ANIMATION), "BearKing earthquake completes once")
	expect(
		is_equal_approx(bear_king.global_position.x, skill_start_x),
		"BearKing remains stationary during earthquake"
	)

	await harness.reenter_skill_detection(player, bear_king_position + EARTHQUAKE_OFFSET)
	expect(not harness.is_playing(bear_king, SKILL_ANIMATION), "BearKing cannot earthquake during cooldown")
	await create_timer(1.45).timeout
	await harness.reenter_skill_detection(player, bear_king_position + EARTHQUAKE_OFFSET)
	expect(
		not harness.is_playing(bear_king, SKILL_ANIMATION),
		"BearKing preserves its full three second earthquake cooldown"
	)
	await create_timer(0.55).timeout
	await harness.reenter_skill_detection(player, bear_king_position + EARTHQUAKE_OFFSET)
	expect(harness.is_playing(bear_king, SKILL_ANIMATION), "BearKing can earthquake after cooldown")


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
	await harness.physics_frames(3)
	await create_timer(0.05).timeout
	expect(harness.is_playing(bear_king, SKILL_ANIMATION), "BearKing is vulnerable during earthquake")

	await harness.deliver_hit(bear_king, Vector2(-50.0, 0.0))
	expect(
		bear_king.get_current_health() == EXPECTED_HEALTH - 1,
		"Weapon contact damages a vulnerable BearKing"
	)
	expect(harness.is_playing(bear_king, HURT_ANIMATION), "Accepted damage starts BearKing hurt presentation")
	expect(not harness.enemy_sprite_is_flipped(bear_king), "BearKing faces an attacker on its left")
	expect(
		is_equal_approx(bear_king.global_position.x, bear_king_position.x + 100.0),
		"BearKing keeps its 100 pixel hurt knockback"
	)
	expect(
		not harness.is_playing(bear_king, EARTHQUAKE_CAST_ANIMATION),
		"Accepted damage interrupts BearKing earthquake"
	)

	await create_timer(0.45).timeout
	await harness.deliver_hit(bear_king, Vector2(50.0, 0.0))
	expect(
		bear_king.get_current_health() == EXPECTED_HEALTH - 2,
		"Later weapon contact delivers damage after recovery"
	)
	expect(harness.enemy_sprite_is_flipped(bear_king), "BearKing faces an attacker on its right")
	await create_timer(0.3).timeout
	expect(hurt_event_count[0] == 0, "Interrupted BearKing earthquake never reaches impact")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("BearKing boss behavior test passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
