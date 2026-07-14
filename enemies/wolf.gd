extends "res://enemies/enemy.gd"


const MAX_HEALTH := 2
const SKILL_DISTANCE := 300.0
const SKILL_SPEED := 400.0
const PLAYER_COLLISION_LAYER := 1 << 1
const WOLF_WALL_CHECK_DISTANCE := 56.0

var _skill_distance_left := 0.0


func _get_initial_move_direction() -> float:
	return 1.0


func _get_max_health() -> int:
	return MAX_HEALTH


func _get_sprite_flip(direction: float) -> bool:
	return direction < 0.0


func _get_run_animation() -> StringName:
	return &"running"


func _get_wall_check_distance() -> float:
	return WOLF_WALL_CHECK_DISTANCE


func _start_species_skill() -> void:
	_skill_distance_left = SKILL_DISTANCE


func _update_species_skill(delta: float) -> void:
	var travel_distance := minf(SKILL_SPEED * delta, _skill_distance_left)
	velocity.x = move_direction * travel_distance / delta
	_skill_distance_left -= travel_distance


func _handle_species_skill_collisions() -> void:
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		var body := collision.get_collider() as CollisionObject2D
		if (
			body == null
			or not is_instance_valid(body)
			or (body.collision_layer & PLAYER_COLLISION_LAYER) == 0
			or not body.has_method("hurt")
		):
			continue

		body.hurt(-collision.get_normal())


func _is_species_skill_complete() -> bool:
	return _skill_distance_left <= 0.0


func _blocks_weapon_damage_during_skill() -> bool:
	return true


func finish_skill() -> void:
	velocity.x = 0.0
	start_x = global_position.x
	super()
