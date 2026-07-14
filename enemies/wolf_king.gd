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

var skill_distance_left := 0.0
var rng := RandomNumberGenerator.new()
var player: Node2D = null

@onready var health_bar: TextureProgressBar = $HealthBar/TextureProgressBar
@onready var thunder: Area2D = $Thunder
@onready var thunder_sprite: Sprite2D = $Thunder/Sprite2D
@onready var thunder_collision_shape: CollisionShape2D = $Thunder/CollisionShape2D
@onready var thunder_animation_player: AnimationPlayer = $Thunder/AnimationPlayer
@onready var thunder_particles: CPUParticles2D = $Thunder/CPUParticles2D
@onready var thunder_start_offset: Vector2 = thunder.position


func _ready() -> void:
	rng.randomize()
	thunder.top_level = true
	player = _find_player()
	_reset_thunder()
	super._ready()


func _get_max_health() -> int:
	return WOLF_KING_MAX_HEALTH


func _get_skill_animation() -> StringName:
	return RUN_ANIMATION


func _blocks_weapon_damage_during_skill() -> bool:
	return true


func _get_hurt_knockback_distance() -> float:
	return 0.0


func _get_hurt_return_state() -> int:
	return RUN


func _start_species_skill() -> void:
	skill_distance_left = WOLF_KING_SKILL_DISTANCE
	_cast_thunder()


func _update_species_skill(delta: float) -> void:
	var travel_distance := minf(WOLF_KING_SKILL_SPEED * delta, skill_distance_left)
	velocity.x = move_direction * travel_distance / delta
	skill_distance_left -= travel_distance


func _is_species_skill_complete() -> bool:
	return skill_distance_left <= 0.0


func finish_skill() -> void:
	velocity.x = 0.0
	start_x = global_position.x
	super.finish_skill()


func _prepare_hurt(_knockback_direction: Vector2) -> void:
	_reset_thunder()
	move_direction = _get_player_side()
	face_move_direction()


func _update_health_presentation() -> void:
	health_bar.max_value = WOLF_KING_MAX_HEALTH
	health_bar.value = max(_health, 0)


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
	if state == DEAD or is_hurting:
		return

	thunder.global_position = Vector2(thunder_x, thunder_y)
	thunder_animation_player.stop()
	thunder_animation_player.play(THUNDER_CAST_ANIMATION)
	thunder.start_cast()


func _get_thunder_ground_y(thunder_x: float) -> float:
	var from := Vector2(thunder_x, global_position.y - THUNDER_GROUND_RAY_UP_DISTANCE)
	var to := Vector2(thunder_x, global_position.y + THUNDER_GROUND_RAY_DOWN_DISTANCE)
	var query := PhysicsRayQueryParameters2D.create(from, to, ENVIRONMENT_COLLISION_MASK)
	query.exclude = [get_rid()]

	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return global_position.y + thunder_start_offset.y

	var hit_position: Vector2 = hit["position"]
	return hit_position.y - _get_thunder_bottom_offset()


func _get_thunder_bottom_offset() -> float:
	var rectangle_shape := thunder_collision_shape.shape as RectangleShape2D
	if rectangle_shape != null:
		return thunder_collision_shape.position.y + rectangle_shape.size.y * 0.5

	var circle_shape := thunder_collision_shape.shape as CircleShape2D
	if circle_shape != null:
		return thunder_collision_shape.position.y + circle_shape.radius

	return thunder_particles.position.y


func _get_thunder_x_offset() -> float:
	return _get_player_side() * rng.randf_range(
		THUNDER_CAST_MIN_DISTANCE,
		THUNDER_CAST_MAX_DISTANCE
	)


func _get_player_side() -> float:
	if player != null and is_instance_valid(player):
		if player.global_position.x < global_position.x:
			return -1.0
		if player.global_position.x > global_position.x:
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
	thunder.cancel_cast()
	thunder_animation_player.stop()
	thunder_sprite.visible = false
	thunder_collision_shape.set_deferred("disabled", true)
	thunder_particles.emitting = false
