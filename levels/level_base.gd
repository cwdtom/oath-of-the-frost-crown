extends Node2D


@onready var player = $Player
@onready var hud = $HUD
@onready var spawn_point = $SpawnPoint


func _ready() -> void:
	player.global_position = spawn_point.global_position
	hud.set_health(player.health)
	player.hurt_taken.connect(hud.decrease_health)
