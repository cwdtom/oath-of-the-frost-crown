extends "res://enemies/bear.gd"


signal died

const BEAR_KING_MAX_HEALTH := 15

@onready var health_bar: TextureProgressBar = $HealthBar/TextureProgressBar


func _init() -> void:
	_health = BEAR_KING_MAX_HEALTH


func _ready() -> void:
	super._ready()
	health_bar.max_value = BEAR_KING_MAX_HEALTH
	health_bar.value = _health


func hurt(knockback_direction: Vector2 = Vector2.ZERO) -> void:
	if is_hurting or state == DEAD:
		return

	if not is_zero_approx(knockback_direction.x):
		move_direction = -signf(knockback_direction.x)
		face_move_direction()

	super.hurt(knockback_direction)
	health_bar.value = max(_health, 0)


func die() -> void:
	change_state(DEAD)
	process_mode = Node.PROCESS_MODE_ALWAYS
	died.emit()
	await get_tree().create_timer(animation_player.get_animation(DEAD_ANIMATION).length).timeout
	queue_free()
