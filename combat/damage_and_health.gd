class_name DamageAndHealth
extends RefCounted


signal health_changed(current_health: int, maximum_health: int)
signal depleted

var _current_health: int
var _maximum_health: int
var _is_depleted := false
var _is_hurt_immune := false


func _init(maximum_health: int) -> void:
	assert(maximum_health > 0)
	_maximum_health = maximum_health
	_current_health = maximum_health


func get_current_health() -> int:
	return _current_health


func get_maximum_health() -> int:
	return _maximum_health


func is_depleted() -> bool:
	return _is_depleted


func is_hurt_immune() -> bool:
	return _is_hurt_immune


func accept_damage(amount: int) -> bool:
	if amount <= 0 or _is_depleted or _is_hurt_immune:
		return false

	_current_health = max(_current_health - amount, 0)
	_is_depleted = _current_health == 0
	_is_hurt_immune = not _is_depleted
	health_changed.emit(_current_health, _maximum_health)
	if _is_depleted:
		depleted.emit()
	return true


func end_hurt_immunity() -> void:
	_is_hurt_immune = false


func restore_full_health() -> void:
	_current_health = _maximum_health
	_is_depleted = false
	health_changed.emit(_current_health, _maximum_health)
