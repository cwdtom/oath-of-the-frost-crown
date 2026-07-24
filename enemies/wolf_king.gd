extends "res://enemies/enemy.gd"


signal died

const WOLF_KING_MAX_HEALTH := 5
const THUNDER_CAST_ANIMATION := &"cast"
const THUNDER_CAST_MIN_DISTANCE := 400.0
const THUNDER_CAST_MAX_DISTANCE := 750.0
const THUNDER_GROUND_RAY_UP_DISTANCE := 800.0
const THUNDER_GROUND_RAY_DOWN_DISTANCE := 1400.0
const WOLF_KING_SKILL_DISTANCE := 300.0
const WOLF_KING_SKILL_SPEED := 600.0
const WOLF_KING_SKILL_WARNING_ANIMATION := &"warn"

var _rng := RandomNumberGenerator.new()
var _player: Node2D = null

@onready var _health_bar: TextureProgressBar = $HealthBar/TextureProgressBar
@onready var _thunder: Area2D = $Thunder
@onready var _thunder_sprite: Sprite2D = $Thunder/Sprite2D
@onready var _thunder_collision_shape: CollisionShape2D = $Thunder/CollisionShape2D
@onready var _thunder_animation_player: AnimationPlayer = $Thunder/AnimationPlayer
@onready var _thunder_particles: CPUParticles2D = $Thunder/CPUParticles2D
@onready var _thunder_start_offset: Vector2 = _thunder.position


func _ready() -> void:
	_rng.randomize()
	_thunder.top_level = true
	_player = _find_player()
	_reset_thunder()
	super._ready()


func _get_max_health() -> int:
	return WOLF_KING_MAX_HEALTH


func _get_skill_animation() -> StringName:
	return RUN_ANIMATION


func _get_skill_warning_animation() -> StringName:
	return WOLF_KING_SKILL_WARNING_ANIMATION


func _get_moving_skill_distance() -> float:
	return WOLF_KING_SKILL_DISTANCE


func _get_moving_skill_speed() -> float:
	return WOLF_KING_SKILL_SPEED


func _blocks_weapon_damage_during_skill() -> bool:
	return true


func _get_hurt_knockback_distance() -> float:
	return 0.0


func _get_hurt_return_state() -> int:
	return RUN


func _start_species_skill() -> void:
	super._start_species_skill()
	_cast_thunder()


func _prepare_hurt(_knockback_direction: Vector2) -> void:
	move_direction = _get_player_side()
	face_move_direction()


func _update_health_presentation(current_health: int, maximum_health: int) -> void:
	_health_bar.max_value = maximum_health
	_health_bar.value = current_health


func _prepare_death_presentation() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	skill_detect_collision_shape.set_deferred("disabled", true)
	_reset_thunder()
	died.emit()


func _cast_thunder() -> void:
	var thunder_x := global_position.x + _get_thunder_x_offset()
	var thunder_y := _get_thunder_ground_y(thunder_x)
	call_deferred("_play_thunder_cast", thunder_x, thunder_y)


func _play_thunder_cast(thunder_x: float, thunder_y: float) -> void:
	if state == DEAD or is_hurt_immune():
		return

	_thunder.global_position = Vector2(thunder_x, thunder_y)
	_thunder_animation_player.stop()
	_thunder_animation_player.play(THUNDER_CAST_ANIMATION)
	_thunder.start_cast()


func _get_thunder_ground_y(thunder_x: float) -> float:
	var from := Vector2(thunder_x, global_position.y - THUNDER_GROUND_RAY_UP_DISTANCE)
	var to := Vector2(thunder_x, global_position.y + THUNDER_GROUND_RAY_DOWN_DISTANCE)
	var query := PhysicsRayQueryParameters2D.create(from, to, ENVIRONMENT_COLLISION_MASK)
	query.exclude = [get_rid()]

	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return global_position.y + _thunder_start_offset.y

	var hit_position: Vector2 = hit["position"]
	return hit_position.y - _get_thunder_bottom_offset()


func _get_thunder_bottom_offset() -> float:
	var rectangle_shape := _thunder_collision_shape.shape as RectangleShape2D
	if rectangle_shape != null:
		return _thunder_collision_shape.position.y + rectangle_shape.size.y * 0.5

	var circle_shape := _thunder_collision_shape.shape as CircleShape2D
	if circle_shape != null:
		return _thunder_collision_shape.position.y + circle_shape.radius

	return _thunder_particles.position.y


func _get_thunder_x_offset() -> float:
	return move_direction * _rng.randf_range(
		THUNDER_CAST_MIN_DISTANCE,
		THUNDER_CAST_MAX_DISTANCE
	)


func _get_player_side() -> float:
	if _player != null and is_instance_valid(_player):
		if _player.global_position.x < global_position.x:
			return -1.0
		if _player.global_position.x > global_position.x:
			return 1.0

	return -1.0 if move_direction < 0.0 else 1.0


func _find_player() -> Node2D:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null

	return current_scene.find_child("Player", true, false) as Node2D


func _reset_thunder() -> void:
	call_deferred("_apply_thunder_reset")


func _apply_thunder_reset() -> void:
	_thunder.cancel_cast()
	_thunder_animation_player.stop()
	_thunder_sprite.visible = false
	_thunder_collision_shape.set_deferred("disabled", true)
	_thunder_particles.emitting = false
