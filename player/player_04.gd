extends "res://player/player.gd"


@onready var _shield: Area2D = $VisualRoot/ShieldSkill/Shield
@onready var _shield_cooldown: Timer = $VisualRoot/ShieldSkill/Cooldown

var _shield_break_window_active := false


func _ready() -> void:
	_shield_cooldown.timeout.connect(_shield.show)
	super._ready()


func take_damage(amount: int, knockback_direction: Vector2) -> void:
	if amount <= 0 or _damage_immune or is_health_depleted() or is_hurt_immune():
		return

	if _shield_break_window_active:
		return
	if _shield.visible:
		_shield_break_window_active = true
		await get_tree().create_timer(
			animation_player.get_animation(HURT_ANIMATION).length
		).timeout
		_shield.hide()
		_shield_cooldown.start()
		_shield_break_window_active = false
		return

	super.take_damage(amount, knockback_direction)
