extends Area2D


func _on_body_entered(body: Node2D) -> void:
	var actor := body as DamageableActor
	if actor == null or not is_instance_valid(actor):
		return

	actor.take_damage(1, actor.global_position - global_position)
