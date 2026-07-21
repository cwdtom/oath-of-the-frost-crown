extends "res://enemies/enemy.gd"


const MAX_HEALTH := 3
const SWORD_GLEAM_CAST_ANIMATION := &"cast"
const RESET_ANIMATION := &"RESET"

@onready var sword_gleam_animation_player: AnimationPlayer = (
	$SkillDetect/SwordGleam/AnimationPlayer
)
@onready var sword_gleam: Area2D = $SkillDetect/SwordGleam
@onready var _sword_gleam_offset_x := absf(sword_gleam.position.x)
@onready var _sword_gleam_scale_x := absf(sword_gleam.scale.x)


func _get_max_health() -> int:
	return MAX_HEALTH


func face_move_direction() -> void:
	super.face_move_direction()
	sword_gleam.position.x = _sword_gleam_offset_x * move_direction
	sword_gleam.scale.x = -_sword_gleam_scale_x * move_direction


func _play_species_skill_presentation() -> void:
	sword_gleam_animation_player.play(SWORD_GLEAM_CAST_ANIMATION)


func _stop_species_skill_presentation() -> void:
	sword_gleam.cancel_cast()
	call_deferred("_reset_sword_gleam_presentation")


func _reset_sword_gleam_presentation() -> void:
	sword_gleam_animation_player.play(RESET_ANIMATION)
	sword_gleam_animation_player.advance(0.0)
	sword_gleam_animation_player.stop()
