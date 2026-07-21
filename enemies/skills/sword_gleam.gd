extends Area2D


const CAST_ANIMATION := &"cast"

@export var uses_horizontal_knockback := false

var damaged_actors: Array[DamageableActor] = []
var is_cast_active := false


func cancel_cast() -> void:
	is_cast_active = false


func _on_body_entered(body: Node2D) -> void:
	var actor := body as DamageableActor
	if (
		not is_cast_active
		or actor == null
		or not is_instance_valid(actor)
		or damaged_actors.has(actor)
	):
		return

	damaged_actors.append(actor)
	var knockback_direction := actor.global_position - global_position
	if uses_horizontal_knockback:
		knockback_direction = Vector2(signf(position.x), 0.0)
	actor.take_damage(1, knockback_direction)


func _on_animation_player_animation_started(animation_name: StringName) -> void:
	if animation_name != CAST_ANIMATION:
		return

	damaged_actors.clear()
	is_cast_active = true


func _on_animation_player_animation_finished(animation_name: StringName) -> void:
	if animation_name == CAST_ANIMATION:
		cancel_cast()
