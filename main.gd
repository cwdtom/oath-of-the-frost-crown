extends Node2D


const LEVEL_01_SCENE := preload("res://levels/level_01.tscn")
const RESULT_DEAD := "DEAD"
const RESULT_VICTORY := "VICTORY"

var level: Node2D

@onready var game_result_popup: CanvasLayer = $GameResultPopup
@onready var result_label: Label = $GameResultPopup/Control/NinePatchRect/VBoxContainer/Label
@onready var retry_button: Button = $GameResultPopup/Control/NinePatchRect/VBoxContainer/HBoxContainer/Retry
@onready var quit_button: Button = $GameResultPopup/Control/NinePatchRect/VBoxContainer/HBoxContainer/Quit


func _ready() -> void:
	level = $Level01
	game_result_popup.visible = false
	connect_level_events()
	retry_button.pressed.connect(_on_retry_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func connect_level_events() -> void:
	var player := level.get_node("Player")
	var wolf_king := level.get_node("Enemies/WolfKing")
	player.connect("died", _on_player_died)
	wolf_king.connect("died", _on_wolf_king_died)


func show_result(result_text: String) -> void:
	if game_result_popup.visible:
		return

	result_label.text = result_text
	game_result_popup.visible = true


func restart_level() -> void:
	game_result_popup.visible = false

	var old_level := level
	remove_child(old_level)
	old_level.queue_free()

	level = LEVEL_01_SCENE.instantiate() as Node2D
	level.name = "Level01"
	add_child(level)
	move_child(level, 0)
	connect_level_events()


func _on_player_died() -> void:
	show_result(RESULT_DEAD)


func _on_wolf_king_died() -> void:
	show_result(RESULT_VICTORY)


func _on_retry_pressed() -> void:
	restart_level()


func _on_quit_pressed() -> void:
	get_tree().quit()
