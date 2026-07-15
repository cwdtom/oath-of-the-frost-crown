extends Area2D


func _on_body_entered(body: Node2D) -> void:
	if body == null or not is_instance_valid(body):
		return

	body.take_damage(1, body.global_position - global_position)
