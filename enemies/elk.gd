extends "res://enemies/enemy.gd"


const MAX_HEALTH := 3
const THUNDER_CAST_ANIMATION := &"cast"
const THUNDER_GROUND_RAY_UP_DISTANCE := 800.0
const THUNDER_GROUND_RAY_DOWN_DISTANCE := 1400.0

var _rng := RandomNumberGenerator.new()

@onready var _thunder: Area2D = _get_thunder()
@onready var _thunder_sprite: Sprite2D = _thunder.get_node("Sprite2D")
@onready var _thunder_collision_shape: CollisionShape2D = _thunder.get_node("CollisionShape2D")
@onready var _thunder_animation_player: AnimationPlayer = _thunder.get_node("AnimationPlayer")
@onready var _thunder_particles: CPUParticles2D = _thunder.get_node("CPUParticles2D")
@onready var _thunder_start_offset: Vector2 = _thunder.position
@onready var _shield: Area2D = $ShieldSkill/Shield
@onready var _shield_cooldown_timer: Timer = $ShieldSkill/Cooldown


func _ready() -> void:
	_rng.randomize()
	_thunder.top_level = true
	_reset_thunder()
	_shield_cooldown_timer.timeout.connect(_shield.show)
	super._ready()


func _get_max_health() -> int:
	return MAX_HEALTH


func take_damage(amount: int, knockback_direction: Vector2) -> void:
	if amount > 0 and _shield.visible and not is_health_depleted():
		_shield.hide()
		_shield_cooldown_timer.start()
		return

	super.take_damage(amount, knockback_direction)


func _get_skill_animation() -> StringName:
	return IDLE_ANIMATION


func _get_thunder() -> Area2D:
	return $SkillDetect/Thunder


func _start_species_skill() -> void:
	_cast_thunder()
	await get_tree().create_timer(
		_thunder_animation_player.get_animation(THUNDER_CAST_ANIMATION).length
	).timeout
	if state == SKILL:
		finish_skill()


func _stop_species_skill_presentation() -> void:
	_reset_thunder()


func _cast_thunder() -> void:
	var thunder_x := global_position.x + _get_thunder_x_offset()
	var thunder_y := _get_thunder_ground_y(thunder_x)
	call_deferred("_play_thunder_cast", thunder_x, thunder_y)


func _play_thunder_cast(thunder_x: float, thunder_y: float) -> void:
	if state == DEAD:
		return

	_thunder.global_position = Vector2(thunder_x, thunder_y)
	_thunder_animation_player.stop()
	_thunder_animation_player.play(THUNDER_CAST_ANIMATION)
	_thunder.start_cast()


func _get_thunder_x_offset() -> float:
	var detection_shape := skill_detect_collision_shape.shape as RectangleShape2D
	var detection_center := absf(skill_detect_collision_shape.position.x)
	var detection_half_width := detection_shape.size.x * 0.5
	return move_direction * _rng.randf_range(
		detection_center - detection_half_width,
		detection_center + detection_half_width
	)


func _get_thunder_ground_y(thunder_x: float) -> float:
	var from := Vector2(
		thunder_x,
		global_position.y - THUNDER_GROUND_RAY_UP_DISTANCE
	)
	var to := Vector2(
		thunder_x,
		global_position.y + THUNDER_GROUND_RAY_DOWN_DISTANCE
	)
	var query := PhysicsRayQueryParameters2D.create(from, to, ENVIRONMENT_COLLISION_MASK)
	query.exclude = [get_rid()]

	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return global_position.y + _thunder_start_offset.y

	var hit_position: Vector2 = hit["position"]
	var rectangle_shape := _thunder_collision_shape.shape as RectangleShape2D
	var thunder_scale_y := absf(_thunder.global_transform.get_scale().y)
	return hit_position.y - (
		_thunder_collision_shape.position.y + rectangle_shape.size.y * 0.5
	) * thunder_scale_y


func _reset_thunder() -> void:
	call_deferred("_apply_thunder_reset")


func _apply_thunder_reset() -> void:
	_thunder.cancel_cast()
	_thunder_animation_player.stop()
	_thunder_sprite.visible = false
	_thunder_collision_shape.set_deferred("disabled", true)
	_thunder_particles.emitting = false
