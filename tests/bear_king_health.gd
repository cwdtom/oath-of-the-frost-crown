extends SceneTree


const BEAR_KING_SCENE := preload("res://enemies/bear_king.tscn")
const EXPECTED_HEALTH := 15
const EXPECTED_PATROL_RANGE := 160.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bear_king := BEAR_KING_SCENE.instantiate() as CharacterBody2D
	root.add_child(bear_king)
	await process_frame

	if bear_king.get_script().resource_path != "res://enemies/bear_king.gd":
		push_error("Bear King scene does not use bear_king.gd")
		quit(1)
		return

	if bear_king.get("health") != EXPECTED_HEALTH:
		push_error("Bear King health is not %d" % EXPECTED_HEALTH)
		quit(1)
		return

	if bear_king.get("patrol_range") != EXPECTED_PATROL_RANGE:
		push_error("Bear King patrol range is not %s" % EXPECTED_PATROL_RANGE)
		quit(1)
		return

	bear_king.set_physics_process(false)
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = bear_king.global_position + Vector2(-100.0, 36.0)
	var wall_collision := CollisionShape2D.new()
	var wall_shape := RectangleShape2D.new()
	wall_shape.size = Vector2(10.0, 8.0)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	root.add_child(wall)
	wall.force_update_transform()
	await create_timer(0.05).timeout

	if not bear_king.call("is_front_blocked"):
		push_error("Bear King wall check does not account for its 1.5 scale")
		quit(1)
		return

	print("Bear King health test passed")
	quit(0)
