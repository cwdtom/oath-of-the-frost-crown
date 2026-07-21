extends "res://player/player.gd"


const SHIELD_BREAK_ANIMATION := &"break"
const SHIELD_IDLE_ANIMATION := &"idle"

@onready var _shield: Area2D = $VisualRoot/ShieldSkill/Shield
@onready var _shield_cooldown: Timer = $VisualRoot/ShieldSkill/Cooldown
@onready var _shield_animation_player: AnimationPlayer = $VisualRoot/ShieldSkill/Shield/AnimationPlayer

var _shield_break_window_active := false


func _ready() -> void:
	_shield_cooldown.timeout.connect(_restore_shield)
	super._ready()


func take_damage(amount: int, knockback_direction: Vector2) -> void:
	if amount <= 0 or _damage_immune or is_health_depleted() or is_hurt_immune():
		return

	if _shield_break_window_active:
		return
	if _shield.visible:
		_shield_break_window_active = true
		_shield_animation_player.play(SHIELD_BREAK_ANIMATION)
		await _shield_animation_player.animation_finished
		_shield.hide()
		_shield_cooldown.start()
		_shield_break_window_active = false
		return

	super.take_damage(amount, knockback_direction)


func _restore_shield() -> void:
	_shield_animation_player.play(SHIELD_IDLE_ANIMATION)
	_shield.show()
