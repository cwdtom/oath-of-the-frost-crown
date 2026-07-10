extends SceneTree


const PLAYER_SCENE := preload("res://player/player.tscn")
const WOLF_SCENE := preload("res://enemies/wolf.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	ProjectSettings.set_setting("physics/2d/default_gravity", 0.0)

	var world := Node2D.new()
	root.add_child(world)

	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	player.position = Vector2(100.0, 0.0)
	world.add_child(player)
	player.set_physics_process(false)

	var wolf := WOLF_SCENE.instantiate() as CharacterBody2D
	wolf.position = Vector2.ZERO
	world.add_child(wolf)
	wolf.get_node("SkillDetect").monitoring = false
	wolf.call("start_skill")
	var skill_state: int = wolf.get("state")

	await physics_frame

	var wolf_health_before: int = wolf.get("health")
	var weapon_area := player.get_node("VisualRoot/WeaponMount/Area2D") as Area2D
	wolf.call("_on_hurt_box_area_entered", weapon_area)
	expect(wolf.get("health") == wolf_health_before, "Dashing wolf ignores sword damage")

	var player_health_before: int = player.get("health")
	var wolf_collided_with_player := false
	for _frame in 60:
		await physics_frame
		for collision_index in wolf.get_slide_collision_count():
			var collision := wolf.get_slide_collision(collision_index)
			if collision.get_collider() == player:
				wolf_collided_with_player = true
		if wolf.get("state") != skill_state:
			await physics_frame
			break

	expect(wolf_collided_with_player, "Dashing wolf physically collides with the player")
	expect(wolf.get("state") != skill_state, "Wolf completes the dash before damage is checked")
	expect(
		player.get("health") == player_health_before - 1,
		"Dashing wolf damages the player on collision"
	)
	expect(player.position.x > 100.0, "Dashing wolf knocks the player away from the collision")

	ProjectSettings.set_setting("physics/2d/default_gravity", original_gravity)
	world.queue_free()
	await process_frame
	finish()


func expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("Wolf skill damage test passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
