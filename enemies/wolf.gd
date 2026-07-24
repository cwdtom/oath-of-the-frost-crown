extends "res://enemies/enemy.gd"


const MAX_HEALTH := 2
const SKILL_DISTANCE := 300.0
const SKILL_SPEED := 400.0
const SKILL_WARNING_ANIMATION := &"warn"


func _get_initial_move_direction() -> float:
	return 1.0


func _get_max_health() -> int:
	return MAX_HEALTH


func _get_sprite_flip(direction: float) -> bool:
	return direction < 0.0


func _get_run_animation() -> StringName:
	return &"running"


func _get_skill_warning_animation() -> StringName:
	return SKILL_WARNING_ANIMATION


func _get_moving_skill_distance() -> float:
	return SKILL_DISTANCE


func _get_moving_skill_speed() -> float:
	return SKILL_SPEED


func _handle_species_skill_collisions() -> void:
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		var actor := collision.get_collider() as DamageableActor
		if actor == null or not is_instance_valid(actor):
			continue

		actor.take_damage(1, -collision.get_normal())


func _blocks_weapon_damage_during_skill() -> bool:
	return true
