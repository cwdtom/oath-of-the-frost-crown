extends "res://enemies/enemy.gd"


const MAX_HEALTH := 4
const EARTHQUAKE_CAST_ANIMATION := &"cast"
const RESET_ANIMATION := &"RESET"

@onready var earthquake_animation_player: AnimationPlayer = $Earthquake/AnimationPlayer


func _get_max_health() -> int:
	return MAX_HEALTH


func _play_species_skill_presentation() -> void:
	earthquake_animation_player.play(EARTHQUAKE_CAST_ANIMATION)


func _stop_species_skill_presentation() -> void:
	call_deferred("_reset_earthquake_presentation")


func _reset_earthquake_presentation() -> void:
	earthquake_animation_player.play(RESET_ANIMATION)
	earthquake_animation_player.advance(0.0)
	earthquake_animation_player.stop()


func _get_species_animation_position(animation_name: StringName) -> float:
	if (
		animation_name != EARTHQUAKE_CAST_ANIMATION
		or not earthquake_animation_player.is_playing()
	):
		return -1.0

	return earthquake_animation_player.current_animation_position
