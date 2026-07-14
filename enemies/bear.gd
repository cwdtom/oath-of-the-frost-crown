extends "res://enemies/enemy.gd"


const MAX_HEALTH := 4
const EARTHQUAKE_CAST_ANIMATION := &"cast"

@onready var earthquake_animation_player: AnimationPlayer = $Earthquake/AnimationPlayer


func _init() -> void:
	health = MAX_HEALTH


func _play_species_skill_presentation() -> void:
	earthquake_animation_player.play(EARTHQUAKE_CAST_ANIMATION)


func _is_playing_animation(animation_name: StringName) -> bool:
	if animation_name == EARTHQUAKE_CAST_ANIMATION:
		return (
			earthquake_animation_player.is_playing()
			and earthquake_animation_player.current_animation == animation_name
		)

	return super._is_playing_animation(animation_name)


func _get_animation_position(animation_name: StringName) -> float:
	if animation_name == EARTHQUAKE_CAST_ANIMATION:
		if not _is_playing_animation(animation_name):
			return -1.0

		return earthquake_animation_player.current_animation_position

	return super._get_animation_position(animation_name)
