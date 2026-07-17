extends "res://enemies/elk.gd"


signal died

const ELK_KING_MAX_HEALTH := 10

@onready var _health_bar: TextureProgressBar = $HealthBar/TextureProgressBar


func _get_max_health() -> int:
	return ELK_KING_MAX_HEALTH


func _update_health_presentation(current_health: int, maximum_health: int) -> void:
	_health_bar.max_value = maximum_health
	_health_bar.value = current_health


func _prepare_death_presentation() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	died.emit()


func _get_skill_cooldown_timer() -> Timer:
	return $SkillDetect/ThunderSkill/Cooldown


func _get_thunder() -> Area2D:
	return $SkillDetect/ThunderSkill/Thunder
