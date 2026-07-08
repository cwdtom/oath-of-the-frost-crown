extends Area2D

const PLAYER_LAYER := 1 << 1
const CAMERA_LIMIT_WAIT_THRESHOLD := 2.0
const CAMERA_LIMIT_WAIT_MAX_MSEC := 1500

var is_locked := false
var player_entered_from_left := false

@onready var static_collision_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	static_collision_shape.disabled = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if is_locked or not is_player(body):
		return

	player_entered_from_left = body.global_position.x < global_position.x


func _on_body_exited(body: Node2D) -> void:
	if is_locked or not is_player(body):
		return

	if player_entered_from_left and body.global_position.x > global_position.x:
		player_entered_from_left = false
		await lock_door(body)
		return

	player_entered_from_left = false


func lock_door(player: Node2D) -> void:
	is_locked = true
	visible = true
	static_collision_shape.set_deferred("disabled", false)
	await update_player_camera_limit(player)


func update_player_camera_limit(player: Node2D) -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return

	var limit_left := roundi(global_position.x)
	var original_camera_x := camera.position.x
	var half_view_width := get_viewport_rect().size.x * 0.5 / camera.zoom.x
	var target_center_x := global_position.x + half_view_width

	camera.global_position = Vector2(target_center_x, camera.global_position.y)
	await wait_for_camera_center_x(camera, target_center_x)

	camera.limit_left = limit_left
	camera.position.x = original_camera_x


func wait_for_camera_center_x(camera: Camera2D, target_x: float) -> void:
	var start_msec := Time.get_ticks_msec()

	while is_instance_valid(camera):
		await get_tree().process_frame

		if absf(camera.get_screen_center_position().x - target_x) <= CAMERA_LIMIT_WAIT_THRESHOLD:
			return

		if Time.get_ticks_msec() - start_msec >= CAMERA_LIMIT_WAIT_MAX_MSEC:
			return


func is_player(body: Node2D) -> bool:
	var collision_body := body as CollisionObject2D
	return collision_body != null and (collision_body.collision_layer & PLAYER_LAYER) != 0
