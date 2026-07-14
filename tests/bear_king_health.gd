extends SceneTree


const BEAR_KING_SCENE := preload("res://enemies/bear_king.tscn")
const LEVEL_02_SCENE := preload("res://levels/level_02.tscn")
const PLAYER_SCENE := preload("res://player/player.tscn")
const EnemyHarness := preload("res://tests/enemy_scene_harness.gd")
const DEAD_ANIMATION := &"dead"
const HURT_ANIMATION := &"hurt"
const IDLE_ANIMATION := &"idle"
const RUN_ANIMATION := &"run"
const SKILL_ANIMATION := &"skill"
const EARTHQUAKE_CAST_ANIMATION := &"cast"
const EXPECTED_HEALTH := 15
const EARTHQUAKE_OFFSET := Vector2(-228.0, 72.0)

var failures: Array[String] = []
var harness: EnemySceneHarness
var passive_players: Array[CharacterBody2D] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	ProjectSettings.set_setting("physics/2d/default_gravity", 0.0)
	harness = EnemyHarness.new(self)

	test_level_02_uses_bear_king_scene()
	await test_encounter_configuration_and_patrol()
	await test_scaled_environment_wall_reversal()
	await test_earthquake_damage_and_cooldown()
	await test_damage_faces_attacker_and_interrupts_earthquake()
	await test_paused_death_outcome_and_cleanup()

	paused = false
	ProjectSettings.set_setting("physics/2d/default_gravity", original_gravity)
	stop_passive_player_audio()
	harness.cleanup()
	await process_frame
	await process_frame
	finish()


func test_level_02_uses_bear_king_scene() -> void:
	var level := LEVEL_02_SCENE.instantiate()
	var level_bear_king: CharacterBody2D
	for node in level.find_children("*", "CharacterBody2D", true, false):
		if node.has_signal(&"died"):
			level_bear_king = node as CharacterBody2D
			break

	expect(level_bear_king != null, "Level 02 contains its BearKing encounter")
	level.free()


func test_encounter_configuration_and_patrol() -> void:
	var bear_king := harness.instantiate_enemy(BEAR_KING_SCENE, Vector2.ZERO)
	var health_bar := find_health_bar(bear_king)
	expect(health_bar != null, "BearKing presents boss health")
	if health_bar != null:
		expect(
			health_bar.max_value == EXPECTED_HEALTH and health_bar.value == EXPECTED_HEALTH,
			"BearKing presents its full 15 point health capacity"
		)
		expect(
			health_bar.fill_mode == TextureProgressBar.FILL_LEFT_TO_RIGHT,
			"BearKing health presentation shrinks from right to left"
		)

	expect(bear_king.patrol_range == 160.0, "BearKing keeps its 160 pixel patrol range")
	expect(bear_king.run_speed == 80.0, "BearKing keeps its 80 pixel run speed")
	expect(bear_king.idle_duration == 1.0, "BearKing keeps its one second idle duration")
	expect(bear_king.scale == Vector2(1.5, 1.5), "BearKing keeps its encounter scale")
	expect(
		is_equal_approx(animation_length(bear_king, HURT_ANIMATION), 0.4),
		"BearKing keeps its hurt-immunity presentation timing"
	)
	expect(
		is_equal_approx(animation_length(bear_king, SKILL_ANIMATION), 0.95),
		"BearKing keeps its earthquake presentation timing"
	)
	expect(
		is_equal_approx(animation_length(bear_king, DEAD_ANIMATION), 1.0),
		"BearKing keeps its death presentation timing"
	)

	var patrol_bear_king := harness.instantiate_enemy(
		BEAR_KING_SCENE,
		Vector2(1000.0, 0.0),
		{"idle_duration": 0.2, "patrol_range": 1000.0}
	)
	var start_x := patrol_bear_king.global_position.x
	await create_timer(0.05).timeout
	expect(is_playing(patrol_bear_king, IDLE_ANIMATION), "BearKing initializes idling")
	expect(
		is_equal_approx(patrol_bear_king.global_position.x, start_x),
		"BearKing stays still during its configured idle"
	)
	await create_timer(0.2).timeout
	expect(is_playing(patrol_bear_king, RUN_ANIMATION), "BearKing enters its run presentation")
	expect(patrol_bear_king.global_position.x < start_x, "BearKing begins its patrol leftward")
	expect(not is_facing_right(patrol_bear_king), "BearKing faces its patrol direction")


func test_scaled_environment_wall_reversal() -> void:
	var start_position := Vector2(2000.0, 0.0)
	harness.add_environment_wall(start_position + Vector2(-100.0, 36.0), Vector2(10.0, 8.0))
	var bear_king := harness.instantiate_enemy(
		BEAR_KING_SCENE,
		start_position,
		{"idle_duration": 0.0, "patrol_range": 1000.0}
	)

	await physics_frames(12)
	expect(
		bear_king.global_position.x > start_position.x,
		"Scaled BearKing reverses away from an environment wall"
	)
	expect(is_facing_right(bear_king), "Scaled BearKing faces away from the wall")
	var turned_x := bear_king.global_position.x
	await physics_frames(6)
	expect(
		bear_king.global_position.x > turned_x,
		"BearKing continues patrolling after its wall reversal"
	)


func test_earthquake_damage_and_cooldown() -> void:
	var bear_king_position := Vector2(3500.0, 0.0)
	var bear_king := harness.instantiate_enemy(
		BEAR_KING_SCENE,
		bear_king_position,
		{"idle_duration": 10.0}
	)
	var hurt_events: Array[int] = [0]
	var player := instantiate_passive_player(
		bear_king_position + EARTHQUAKE_OFFSET,
		hurt_events
	)

	await physics_frames(3)
	await create_timer(0.05).timeout
	expect(is_playing(bear_king, SKILL_ANIMATION), "Gameplay detection starts BearKing earthquake")
	expect(
		is_playing(bear_king, EARTHQUAKE_CAST_ANIMATION),
		"BearKing starts the shared earthquake presentation"
	)
	var skill_start_x := bear_king.global_position.x
	await create_timer(0.7).timeout
	await physics_frame
	expect(hurt_events[0] == 1, "BearKing earthquake deals one point of damage once")
	await create_timer(0.3).timeout
	expect(not is_playing(bear_king, SKILL_ANIMATION), "BearKing earthquake completes once")
	expect(
		is_equal_approx(bear_king.global_position.x, skill_start_x),
		"BearKing remains stationary during earthquake"
	)

	await reenter_skill_detection(player, bear_king_position + EARTHQUAKE_OFFSET)
	expect(not is_playing(bear_king, SKILL_ANIMATION), "BearKing cannot earthquake during cooldown")
	await create_timer(1.45).timeout
	await reenter_skill_detection(player, bear_king_position + EARTHQUAKE_OFFSET)
	expect(
		not is_playing(bear_king, SKILL_ANIMATION),
		"BearKing preserves its full three second earthquake cooldown"
	)
	await create_timer(0.55).timeout
	await reenter_skill_detection(player, bear_king_position + EARTHQUAKE_OFFSET)
	expect(is_playing(bear_king, SKILL_ANIMATION), "BearKing can earthquake after cooldown")


func test_damage_faces_attacker_and_interrupts_earthquake() -> void:
	var bear_king_position := Vector2(5500.0, 0.0)
	var bear_king := harness.instantiate_enemy(
		BEAR_KING_SCENE,
		bear_king_position,
		{"idle_duration": 10.0}
	)
	var health_bar := find_health_bar(bear_king)
	var hurt_events: Array[int] = [0]
	instantiate_passive_player(bear_king_position + EARTHQUAKE_OFFSET, hurt_events)
	await physics_frames(3)
	await create_timer(0.05).timeout
	expect(is_playing(bear_king, SKILL_ANIMATION), "BearKing is vulnerable during earthquake")

	await deliver_hit(bear_king, Vector2(-50.0, 0.0))
	expect(
		health_bar != null and health_bar.value == EXPECTED_HEALTH - 1,
		"Accepted damage immediately updates BearKing health presentation"
	)
	expect(is_playing(bear_king, HURT_ANIMATION), "Accepted damage starts BearKing hurt presentation")
	expect(not is_facing_right(bear_king), "BearKing faces an attacker on its left")
	expect(
		is_equal_approx(bear_king.global_position.x, bear_king_position.x + 100.0),
		"BearKing keeps its 100 pixel hurt knockback"
	)
	expect(
		not is_playing(bear_king, EARTHQUAKE_CAST_ANIMATION),
		"Accepted damage interrupts BearKing earthquake"
	)

	await deliver_hit(bear_king, Vector2(50.0, 0.0))
	expect(
		health_bar != null and health_bar.value == EXPECTED_HEALTH - 1,
		"BearKing ignores damage during its hurt-immunity window"
	)
	expect(not is_facing_right(bear_king), "Ignored damage does not change BearKing facing")
	await create_timer(0.45).timeout
	await deliver_hit(bear_king, Vector2(50.0, 0.0))
	expect(
		health_bar != null and health_bar.value == EXPECTED_HEALTH - 2,
		"BearKing accepts damage after hurt immunity ends"
	)
	expect(is_facing_right(bear_king), "BearKing faces an attacker on its right")
	await create_timer(0.3).timeout
	expect(hurt_events[0] == 0, "Interrupted BearKing earthquake never reaches impact")


func test_paused_death_outcome_and_cleanup() -> void:
	var bear_king_position := Vector2(7500.0, 0.0)
	var bear_king := harness.instantiate_enemy(
		BEAR_KING_SCENE,
		bear_king_position,
		{"idle_duration": 10.0}
	)
	var health_bar := find_health_bar(bear_king)
	for hit_index in EXPECTED_HEALTH - 1:
		await deliver_hit(bear_king)
		if hit_index < EXPECTED_HEALTH - 2:
			await create_timer(0.45).timeout

	expect(health_bar != null and health_bar.value == 1.0, "BearKing reaches one remaining health")
	await create_timer(0.45).timeout
	var hurt_events: Array[int] = [0]
	instantiate_passive_player(bear_king.global_position + EARTHQUAKE_OFFSET, hurt_events)
	await physics_frames(3)
	await create_timer(0.05).timeout
	expect(is_playing(bear_king, SKILL_ANIMATION), "BearKing can earthquake before a lethal hit")

	var death_outcomes: Array[int] = [0]
	bear_king.connect(
		&"died",
		func() -> void:
			death_outcomes[0] += 1
			paused = true
	)
	var first_weapon := harness.add_weapon(bear_king.global_position + Vector2(-40.0, 0.0))
	var second_weapon := harness.add_weapon(bear_king.global_position + Vector2(40.0, 0.0))
	await physics_frames(3)
	await process_frame
	harness.remove_actor(first_weapon)
	harness.remove_actor(second_weapon)
	await process_frame

	expect(death_outcomes[0] == 1, "BearKing emits one boss death outcome")
	expect(health_bar != null and health_bar.value == 0.0, "Lethal damage empties boss health presentation")
	expect(not bear_king.is_in_group("enemies"), "Dead BearKing leaves the active Enemy group")
	expect(is_playing(bear_king, DEAD_ANIMATION), "Lethal damage starts BearKing death presentation")
	expect(
		not is_playing(bear_king, EARTHQUAKE_CAST_ANIMATION),
		"Death interrupts BearKing earthquake"
	)
	expect(not harness.enemy_has_body_collision(bear_king), "Death disables BearKing body collision")
	expect(not harness.enemy_has_hurt_collision(bear_king), "Death disables BearKing hurt collision")

	await create_timer(0.7).timeout
	expect(is_instance_valid(bear_king), "Paused BearKing remains for its death presentation")
	expect(hurt_events[0] == 0, "Dead BearKing cannot produce a delayed earthquake impact")
	expect(
		animation_position(bear_king, DEAD_ANIMATION) >= 0.65,
		"BearKing death presentation advances while Story-style pause is active"
	)
	await create_timer(0.35).timeout
	expect(not is_instance_valid(bear_king), "BearKing leaves only after its death presentation completes")
	expect(death_outcomes[0] == 1, "BearKing death outcome remains singular after removal")
	paused = false


func deliver_hit(bear_king: CharacterBody2D, offset := Vector2.ZERO) -> void:
	var weapon := harness.add_weapon(bear_king.global_position + offset)
	await physics_frames(3)
	await process_frame
	harness.remove_actor(weapon)
	await physics_frames(2)
	await process_frame


func reenter_skill_detection(actor: CharacterBody2D, detection_position: Vector2) -> void:
	actor.position = detection_position + Vector2(500.0, 0.0)
	await physics_frames(2)
	actor.position = detection_position
	await physics_frames(2)
	await create_timer(0.05).timeout


func physics_frames(count: int) -> void:
	for _frame in count:
		await physics_frame


func instantiate_passive_player(position: Vector2, hurt_events: Array[int]) -> CharacterBody2D:
	var player := harness.instantiate_actor(PLAYER_SCENE, position)
	player.set_physics_process(false)
	player.hurt_taken.connect(func() -> void: hurt_events[0] += 1)
	passive_players.append(player)
	return player


func stop_passive_player_audio() -> void:
	for player in passive_players:
		if not is_instance_valid(player):
			continue
		player.process_mode = Node.PROCESS_MODE_DISABLED
		for node in player.find_children("*", "AudioStreamPlayer2D", true, false):
			(node as AudioStreamPlayer2D).stop()


func find_health_bar(enemy: CharacterBody2D) -> TextureProgressBar:
	for node in enemy.find_children("*", "TextureProgressBar", true, false):
		return node as TextureProgressBar

	return null


func is_playing(enemy: CharacterBody2D, animation_name: StringName) -> bool:
	return bool(enemy.call("_is_playing_animation", animation_name))


func animation_position(enemy: CharacterBody2D, animation_name: StringName) -> float:
	return float(enemy.call("_get_animation_position", animation_name))


func animation_length(enemy: CharacterBody2D, animation_name: StringName) -> float:
	return float(enemy.call("_get_animation_length", animation_name))


func is_facing_right(enemy: CharacterBody2D) -> bool:
	return bool(enemy.call("_is_facing_right"))


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("BearKing Enemy lifecycle test passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
