extends SceneTree


const BEAR_KING_SCENE := preload("res://enemies/bear_king.tscn")
const LEVEL_02_SCENE := preload("res://levels/level_02.tscn")
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

	var health_bar := bear_king.get_node_or_null("HealthBar/TextureProgressBar") as TextureProgressBar
	if (
		health_bar == null
		or health_bar.max_value != EXPECTED_HEALTH
		or health_bar.value != EXPECTED_HEALTH
	):
		push_error("Bear King health bar is not initialized to %d/%d" % [EXPECTED_HEALTH, EXPECTED_HEALTH])
		quit(1)
		return

	if health_bar.fill_mode != TextureProgressBar.FILL_LEFT_TO_RIGHT:
		push_error("Boss health bars do not shrink from right to left")
		quit(1)
		return

	bear_king.call("hurt", Vector2.LEFT)
	var sprite := bear_king.get_node("Sprite2D") as Sprite2D
	if bear_king.get("health") != EXPECTED_HEALTH - 1 or health_bar.value != EXPECTED_HEALTH - 1:
		push_error("Bear King health bar does not update immediately after damage")
		quit(1)
		return
	if bear_king.get("move_direction") <= 0.0 or not sprite.flip_h:
		push_error("Bear King does not immediately face an attacker on its right")
		quit(1)
		return

	bear_king.call("hurt", Vector2.RIGHT)
	if (
		bear_king.get("health") != EXPECTED_HEALTH - 1
		or health_bar.value != EXPECTED_HEALTH - 1
		or bear_king.get("move_direction") <= 0.0
		or not sprite.flip_h
	):
		push_error("Bear King reacts to damage again during hurt immunity")
		quit(1)
		return

	if bear_king.get("patrol_range") != EXPECTED_PATROL_RANGE:
		push_error("Bear King patrol range is not %s" % EXPECTED_PATROL_RANGE)
		quit(1)
		return

	bear_king.set_physics_process(false)
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = bear_king.global_position + Vector2(100.0 * bear_king.get("move_direction"), 36.0)
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

	var level_02 := LEVEL_02_SCENE.instantiate()
	var level_bear_king := level_02.get_node("Enemies/BearKing") as CharacterBody2D
	var level_bear_king_script := level_bear_king.get_script() as Script
	if (
		level_bear_king_script == null
		or level_bear_king_script.resource_path != "res://enemies/bear_king.gd"
	):
		level_02.free()
		push_error("Level 02 Bear King does not inherit bear_king.gd")
		quit(1)
		return

	var story := level_02.get_node_or_null("Story")
	if story != null:
		level_02.remove_child(story)
		story.free()
	var level_bear_king_start_x := level_bear_king.global_position.x
	root.add_child(level_02)
	await create_timer(1.3).timeout
	var level_bear_king_animation_tree := level_bear_king.get_node("AnimationTree") as AnimationTree
	var level_bear_king_animation_state: AnimationNodeStateMachinePlayback = (
		level_bear_king_animation_tree.get("parameters/playback")
	)
	var level_bear_king_moved := not is_equal_approx(
		level_bear_king.global_position.x,
		level_bear_king_start_x
	)
	var level_bear_king_is_running := level_bear_king_animation_state.get_current_node() == &"run"
	root.remove_child(level_02)
	level_02.free()
	if not level_bear_king_moved or not level_bear_king_is_running:
		push_error("Level 02 Bear King does not patrol with its run animation")
		quit(1)
		return

	bear_king.free()
	wall.free()
	await process_frame
	print("Bear King health test passed")
	quit(0)
