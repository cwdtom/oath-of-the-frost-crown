extends Node2D


@onready var music: AudioStreamPlayer = $AudioStreamPlayer


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		clear_music()
		return

	music.play()


func _exit_tree() -> void:
	clear_music()


func clear_music() -> void:
	music.stop()
	music.stream = null
