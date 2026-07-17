extends "res://enemies/elk.gd"


func _get_skill_cooldown_timer() -> Timer:
	return $SkillDetect/ThunderSkill/Cooldown


func _get_thunder() -> Area2D:
	return $SkillDetect/ThunderSkill/Thunder
