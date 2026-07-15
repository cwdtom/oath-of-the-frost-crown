extends "res://enemies/bear.gd"


signal died

const BEAR_KING_MAX_HEALTH := 15

@onready var health_bar: TextureProgressBar = $HealthBar/TextureProgressBar


func _get_max_health() -> int:
	return BEAR_KING_MAX_HEALTH


func _update_health_presentation(current_health: int, maximum_health: int) -> void:
	health_bar.max_value = maximum_health
	health_bar.value = current_health


func _prepare_hurt(knockback_direction: Vector2) -> void:
	if not is_zero_approx(knockback_direction.x):
		move_direction = -signf(knockback_direction.x)
		face_move_direction()


func _prepare_death_presentation() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	died.emit()
