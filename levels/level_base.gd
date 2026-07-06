extends Node2D


@onready var player = $Player
@onready var hud = $HUD


func _ready() -> void:
	hud.set_health(player.health)
	player.hurt_taken.connect(hud.decrease_health)
