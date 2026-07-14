extends SceneTree


const WOLF_KING_SCENE := preload("res://enemies/wolf_king.tscn")
const LEVEL_01_SCENE := preload("res://levels/level_01.tscn")
const EnemyHarness := preload("res://tests/enemy_scene_harness.gd")
const DEAD_ANIMATION := &"dead"
const HURT_ANIMATION := &"hurt"
const RUN_ANIMATION := &"run"
const EXPECTED_HEALTH := 5
const SKILL_DISTANCE := 300.0

var failures: Array[String] = []
var harness: EnemySceneHarness


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	ProjectSettings.set_setting("physics/2d/default_gravity", 0.0)
	harness = EnemyHarness.new(self)

	test_level_01_uses_wolf_king_scene()
	await test_encounter_configuration_and_patrol()
	await test_scaled_environment_wall_reversal()
	await test_moving_skill_has_no_wolf_contact_damage()
	await test_thunder_movement_delivery_and_cooldown()
	await test_hurt_cancels_pending_thunder()
	await test_paused_death_outcome_and_cleanup()

	ProjectSettings.set_setting("physics/2d/default_gravity", original_gravity)
	harness.cleanup()
	await process_frame
	await process_frame
	finish()


func test_level_01_uses_wolf_king_scene() -> void:
	var level := LEVEL_01_SCENE.instantiate()
	var level_wolf_king: CharacterBody2D
	for node in level.find_children("*", "CharacterBody2D", true, false):
		var candidate := node as CharacterBody2D
		if candidate != null and candidate.has_signal(&"died") and find_health_bar(candidate) != null:
			level_wolf_king = candidate
			break

	expect(level_wolf_king != null, "Level 01 contains its WolfKing encounter")
	level.free()


func test_encounter_configuration_and_patrol() -> void:
	var wolf_king := harness.instantiate_enemy(WOLF_KING_SCENE, Vector2.ZERO)
	var health_bar := find_health_bar(wolf_king)
	expect(health_bar != null, "WolfKing presents boss health")
	if health_bar != null:
		expect(
			health_bar.max_value == EXPECTED_HEALTH and health_bar.value == EXPECTED_HEALTH,
			"WolfKing presents its full five point health capacity"
		)
	expect(wolf_king.patrol_range == 300.0, "WolfKing keeps its 300 pixel patrol range")
	expect(wolf_king.run_speed == 150.0, "WolfKing keeps its 150 pixel run speed")
	expect(wolf_king.idle_duration == 1.0, "WolfKing keeps its one second idle duration")

	var patrol_start := Vector2(1000.0, 0.0)
	var patrol_wolf_king := harness.instantiate_enemy(
		WOLF_KING_SCENE,
		patrol_start,
		{"idle_duration": 0.15, "patrol_range": 40.0}
	)
	await create_timer(0.05).timeout
	expect(
		is_equal_approx(patrol_wolf_king.global_position.x, patrol_start.x),
		"WolfKing stays still during its configured idle"
	)
	await create_timer(0.15).timeout
	expect(patrol_wolf_king.global_position.x < patrol_start.x, "WolfKing begins patrolling left")
	expect(not harness.is_facing_right(patrol_wolf_king), "WolfKing faces its leftward patrol")
	await create_timer(0.3).timeout
	expect(
		is_equal_approx(patrol_wolf_king.global_position.x, patrol_start.x - 40.0),
		"WolfKing reverses at its configured left patrol limit"
	)
	await create_timer(0.2).timeout
	expect(
		patrol_wolf_king.global_position.x > patrol_start.x - 40.0,
		"WolfKing continues patrolling after its limit reversal"
	)
	expect(harness.is_facing_right(patrol_wolf_king), "WolfKing faces its rightward patrol")

	harness.remove_actor(wolf_king)
	harness.remove_actor(patrol_wolf_king)
	await process_frame


func test_scaled_environment_wall_reversal() -> void:
	var start_position := Vector2(1000.0, 0.0)
	var wall := harness.add_environment_wall(
		start_position + Vector2(-130.0, 48.0),
		Vector2(10.0, 8.0)
	)
	var wolf_king := harness.instantiate_enemy(
		WOLF_KING_SCENE,
		start_position,
		{
			"idle_duration": 0.0,
			"patrol_range": 1000.0,
			"scale": Vector2(2.0, 2.0),
		}
	)

	await harness.physics_frames(12)
	expect(
		wolf_king.global_position.x > start_position.x,
		"Scaled WolfKing reverses away from environment geometry"
	)
	expect(harness.is_facing_right(wolf_king), "Scaled WolfKing faces away from the wall")
	var turned_x := wolf_king.global_position.x
	await harness.physics_frames(6)
	expect(
		wolf_king.global_position.x > turned_x,
		"WolfKing keeps patrolling after its wall reversal"
	)

	harness.remove_actor(wolf_king)
	harness.remove_actor(wall)
	await process_frame


func test_moving_skill_has_no_wolf_contact_damage() -> void:
	var start_position := Vector2(2500.0, 0.0)
	var hurt_event_count: Array[int] = [0]
	var player := harness.instantiate_passive_player(
		start_position + Vector2(-70.0, 0.0),
		func() -> void: hurt_event_count[0] += 1
	)
	var wolf_king := harness.instantiate_enemy(
		WOLF_KING_SCENE,
		start_position,
		{"idle_duration": 10.0}
	)

	await harness.physics_frames(4)
	expect(hurt_event_count[0] == 0, "WolfKing movement does not inherit Wolf contact damage")

	harness.remove_actor(wolf_king)
	harness.remove_actor(player)
	await process_frame


func test_thunder_movement_delivery_and_cooldown() -> void:
	var start_position := Vector2(3500.0, 0.0)
	var floor_body := harness.add_environment_wall(
		start_position + Vector2(0.0, 300.0),
		Vector2(2000.0, 20.0)
	)
	var hurt_event_count: Array[int] = [0]
	var player := harness.instantiate_passive_player(
		start_position + Vector2(900.0, 0.0),
		func() -> void: hurt_event_count[0] += 1
	)
	var detector_body := harness.add_body(start_position + Vector2(-150.0, 0.0))
	var wolf_king := harness.instantiate_enemy(
		WOLF_KING_SCENE,
		start_position,
		{"idle_duration": 10.0}
	)

	await harness.physics_frames(3)
	await process_frame
	var thunder_area := find_top_level_area(wolf_king)
	var health_bar := find_health_bar(wolf_king)
	expect(
		thunder_area != null
		and thunder_area.global_position.x > start_position.x + 400.0
		and thunder_area.global_position.x <= start_position.x + 750.0,
		"WolfKing selects thunder on Player's right side"
	)
	expect(
		thunder_area != null and is_equal_approx(thunder_area.global_position.y, 35.0),
		"WolfKing grounds thunder against environment physics"
	)
	expect(harness.is_playing(wolf_king, RUN_ANIMATION), "WolfKing moves with its run presentation")

	harness.remove_actor(detector_body)
	var weapon := harness.add_weapon(wolf_king.global_position, Vector2(200.0, 200.0))
	await harness.physics_frames(2)
	harness.remove_actor(weapon)
	expect(
		health_bar != null and health_bar.value == EXPECTED_HEALTH,
		"WolfKing ignores weapon damage during its moving skill"
	)

	var speed_sample_x := wolf_king.global_position.x
	await harness.physics_frames(6)
	expect(
		absf(wolf_king.global_position.x - speed_sample_x + 60.0) <= 1.0,
		"WolfKing keeps its 600 pixel per second skill speed"
	)
	var repeated_detector := harness.add_body(wolf_king.global_position + Vector2(-150.0, 0.0))
	await harness.physics_frames(2)
	harness.remove_actor(repeated_detector)

	if thunder_area != null:
		player.global_position = thunder_area.global_position + Vector2(20.0, 0.0)
	var player_impact_x := player.global_position.x
	await create_timer(0.9).timeout
	await physics_frame
	expect(hurt_event_count[0] == 1, "One WolfKing thunder cast damages Player no more than once")
	expect(player.global_position.x > player_impact_x + 90.0, "Thunder keeps its Player knockback")
	expect(
		is_equal_approx(wolf_king.global_position.x, start_position.x - SKILL_DISTANCE),
		"Repeated detection cannot restart WolfKing's 300 pixel moving skill"
	)
	await create_timer(0.7).timeout
	expect(hurt_event_count[0] == 1, "Completed thunder does not damage Player again")

	var skill_end_x := wolf_king.global_position.x
	var cooldown_detector := harness.add_body(wolf_king.global_position + Vector2(-150.0, 0.0))
	await harness.physics_frames(3)
	harness.remove_actor(cooldown_detector)
	expect(
		is_equal_approx(wolf_king.global_position.x, skill_end_x),
		"WolfKing cannot restart its skill during cooldown"
	)
	await create_timer(1.25).timeout
	var ready_detector := harness.add_body(wolf_king.global_position + Vector2(-150.0, 0.0))
	await harness.physics_frames(3)
	expect(wolf_king.global_position.x < skill_end_x, "WolfKing can use its skill after three seconds")

	harness.remove_actor(wolf_king)
	harness.remove_actor(player)
	harness.remove_actor(ready_detector)
	harness.remove_actor(floor_body)
	await process_frame


func test_hurt_cancels_pending_thunder() -> void:
	var start_position := Vector2(5500.0, 0.0)
	var floor_body := harness.add_environment_wall(
		start_position + Vector2(0.0, 300.0),
		Vector2(2000.0, 20.0)
	)
	var hurt_event_count: Array[int] = [0]
	var player := harness.instantiate_passive_player(
		start_position + Vector2(900.0, 0.0),
		func() -> void: hurt_event_count[0] += 1
	)
	var detector_body := harness.add_body(start_position + Vector2(-150.0, 0.0))
	var wolf_king := harness.instantiate_enemy(
		WOLF_KING_SCENE,
		start_position,
		{"idle_duration": 10.0}
	)
	var health_bar := find_health_bar(wolf_king)

	await harness.physics_frames(3)
	await process_frame
	var thunder_area := find_top_level_area(wolf_king)
	harness.remove_actor(detector_body)
	await create_timer(0.55).timeout
	if thunder_area != null:
		player.global_position = thunder_area.global_position + Vector2(20.0, 0.0)

	await harness.deliver_hit(wolf_king, Vector2(-50.0, 0.0))
	expect(
		health_bar != null and health_bar.value == EXPECTED_HEALTH - 1,
		"Accepted damage updates WolfKing boss health presentation"
	)
	expect(harness.is_playing(wolf_king, HURT_ANIMATION), "Accepted damage starts WolfKing hurt")
	expect(harness.is_facing_right(wolf_king), "Hurt WolfKing faces Player on its right")
	await harness.deliver_hit(wolf_king, Vector2(50.0, 0.0))
	expect(
		health_bar != null and health_bar.value == EXPECTED_HEALTH - 1,
		"WolfKing ignores repeated damage during its hurt presentation"
	)
	await create_timer(0.5).timeout
	expect(hurt_event_count[0] == 0, "Accepted damage cancels pending WolfKing thunder")

	await create_timer(0.55).timeout
	var resumed_x := wolf_king.global_position.x
	await create_timer(0.1).timeout
	expect(wolf_king.global_position.x > resumed_x, "WolfKing resumes running after hurt presentation")
	expect(harness.is_playing(wolf_king, RUN_ANIMATION), "WolfKing resumes its run presentation")

	harness.remove_actor(wolf_king)
	harness.remove_actor(player)
	harness.remove_actor(floor_body)
	await process_frame


func test_paused_death_outcome_and_cleanup() -> void:
	var start_position := Vector2(7500.0, 0.0)
	var floor_body := harness.add_environment_wall(
		start_position + Vector2(0.0, 300.0),
		Vector2(2000.0, 20.0)
	)
	var delayed_hurt_count: Array[int] = [0]
	var player := harness.instantiate_passive_player(
		start_position + Vector2(900.0, 0.0),
		func() -> void: delayed_hurt_count[0] += 1
	)
	var wolf_king := harness.instantiate_enemy(
		WOLF_KING_SCENE,
		start_position,
		{"idle_duration": 10.0, "patrol_range": 1000.0}
	)
	var health_bar := find_health_bar(wolf_king)
	for hit_index in EXPECTED_HEALTH - 1:
		await harness.deliver_hit(wolf_king)
		if hit_index < EXPECTED_HEALTH - 2:
			await create_timer(1.05).timeout

	expect(health_bar != null and health_bar.value == 1.0, "WolfKing reaches one remaining health")
	await create_timer(1.05).timeout
	var detector_offset := 150.0 if harness.is_facing_right(wolf_king) else -150.0
	var detector_body := harness.add_body(wolf_king.global_position + Vector2(detector_offset, 0.0))
	await harness.physics_frames(3)
	await process_frame
	var thunder_area := find_top_level_area(wolf_king)
	harness.remove_actor(detector_body)
	await create_timer(0.55).timeout
	if thunder_area != null:
		player.global_position = thunder_area.global_position + Vector2(20.0, 0.0)

	var death_outcome_count: Array[int] = [0]
	wolf_king.connect(
		&"died",
		func() -> void:
			death_outcome_count[0] += 1
			paused = true
	)
	var first_weapon := harness.add_weapon(wolf_king.global_position + Vector2(-40.0, 0.0))
	var second_weapon := harness.add_weapon(wolf_king.global_position + Vector2(40.0, 0.0))
	await harness.physics_frames(3)
	await process_frame
	harness.remove_actor(first_weapon)
	harness.remove_actor(second_weapon)

	expect(death_outcome_count[0] == 1, "WolfKing emits one boss death outcome")
	expect(health_bar != null and health_bar.value == 0.0, "Lethal damage empties boss health")
	expect(not wolf_king.is_in_group("enemies"), "Dead WolfKing leaves the active Enemy group")
	expect(harness.is_playing(wolf_king, DEAD_ANIMATION), "Lethal damage starts WolfKing death")
	expect(not harness.enemy_has_body_collision(wolf_king), "Death disables WolfKing body collision")
	expect(not harness.enemy_has_hurt_collision(wolf_king), "Death disables WolfKing hurt collision")

	await create_timer(0.75).timeout
	expect(is_instance_valid(wolf_king), "Paused WolfKing remains during its death presentation")
	expect(delayed_hurt_count[0] == 0, "Death cancels pending WolfKing thunder")
	expect(
		harness.animation_position(wolf_king, DEAD_ANIMATION) >= 0.7,
		"WolfKing death presentation advances while Story-style pause is active"
	)
	await create_timer(1.3).timeout
	expect(not is_instance_valid(wolf_king), "WolfKing leaves after its two second death presentation")
	expect(death_outcome_count[0] == 1, "WolfKing death outcome remains singular after removal")
	paused = false

	harness.remove_actor(player)
	harness.remove_actor(floor_body)
	await process_frame


func find_top_level_area(enemy: CharacterBody2D) -> Area2D:
	for node in enemy.find_children("*", "Area2D", true, false):
		var area := node as Area2D
		if area != null and area.top_level:
			return area

	return null


func find_health_bar(enemy: CharacterBody2D) -> TextureProgressBar:
	for node in enemy.find_children("*", "TextureProgressBar", true, false):
		return node as TextureProgressBar

	return null


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("WolfKing Enemy lifecycle test passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
