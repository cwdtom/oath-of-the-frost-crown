extends Area2D


const CAST_ANIMATION := &"cast"

var damaged_actors: Array[DamageableActor] = []


func _on_body_entered(body: Node2D) -> void:
	var actor := body as DamageableActor
	if actor == null or not is_instance_valid(actor):
		return
	if damaged_actors.has(actor):
		return

	damaged_actors.append(actor)
	actor.take_damage(1, actor.global_position - global_position)


func _on_animation_player_animation_started(animation_name: StringName) -> void:
	if animation_name == CAST_ANIMATION:
		damaged_actors.clear()
