extends Area2D


func _on_body_entered(body: Node2D) -> void:
	if body == null or not is_instance_valid(body) or not body.has_method("hurt"):
		return

	body.hurt(body.global_position - global_position)
