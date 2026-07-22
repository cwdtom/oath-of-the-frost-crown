extends Node2D


@onready var music: AudioStreamPlayer = $AudioStreamPlayer

var playback_position := 0.0
var music_autostart_enabled := true
var music_started := false


func _enter_tree() -> void:
	if is_node_ready() and music_autostart_enabled:
		start_music.call_deferred()


func _ready() -> void:
	if music_autostart_enabled:
		start_music()


func set_music_autostart_enabled(enabled: bool) -> void:
	music_autostart_enabled = enabled


func start_music() -> void:
	music_started = true
	if DisplayServer.get_name() == "headless":
		stop_music()
		return

	music.play(playback_position)


func is_music_playing() -> bool:
	return music.playing


func has_music_started() -> bool:
	return music_started


func get_music_playback_position() -> float:
	if music.playing:
		return music.get_playback_position()
	return playback_position


func _exit_tree() -> void:
	stop_music()


func stop_music() -> void:
	if music.playing:
		playback_position = music.get_playback_position()
	music.stop()
