extends Area2D


const CAST_ANIMATION := &"cast"

@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _player: DamageableActor = $"../Player"


func cast() -> void:
	_animation_player.stop()
	_animation_player.play(CAST_ANIMATION)


func _physics_process(_delta: float) -> void:
	if (
		_animation_player.current_animation != CAST_ANIMATION
		or not _animation_player.is_playing()
	):
		return

	for body in get_overlapping_bodies():
		if body != _player:
			continue

		_player.take_damage(1, _player.global_position - global_position)
		return
