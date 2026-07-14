extends "res://enemies/enemy.gd"


const MAX_HEALTH := 2
const SKILL_DISTANCE := 300.0
const SKILL_SPEED := 400.0
const PLAYER_COLLISION_LAYER := 1 << 1
const WOLF_WALL_CHECK_DISTANCE := 56.0


func _get_initial_move_direction() -> float:
	return 1.0


func _get_max_health() -> int:
	return MAX_HEALTH


func _get_sprite_flip(direction: float) -> bool:
	return direction < 0.0


func _get_run_animation() -> StringName:
	return &"running"


func _get_moving_skill_distance() -> float:
	return SKILL_DISTANCE


func _get_moving_skill_speed() -> float:
	return SKILL_SPEED


func _get_wall_check_distance() -> float:
	return WOLF_WALL_CHECK_DISTANCE


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


func _blocks_weapon_damage_during_skill() -> bool:
	return true
