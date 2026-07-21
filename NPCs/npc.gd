extends Node2D


@onready var player: Node2D = get_parent().get_node("Player") as Node2D
@onready var sprite: Sprite2D = $Sprite2D


func _process(_delta: float) -> void:
	sprite.flip_h = player.global_position.x > global_position.x
