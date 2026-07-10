extends Node2D


@onready var music: AudioStreamPlayer = $AudioStreamPlayer

var playback_position := 0.0


func _enter_tree() -> void:
	if is_node_ready():
		start_music.call_deferred()


func _ready() -> void:
	start_music()


func start_music() -> void:
	if DisplayServer.get_name() == "headless":
		stop_music()
		return

	music.play(playback_position)


func _exit_tree() -> void:
	stop_music()


func stop_music() -> void:
	if music.playing:
		playback_position = music.get_playback_position()
	music.stop()
