extends Node2D


const LEVEL_00_SCENE := preload("res://levels/level_00.tscn")
const LEVEL_01_SCENE := preload("res://levels/level_01.tscn")
const RESULT_DEAD := "DEAD"
const RESULT_VICTORY := "VICTORY"

var level: Node2D = null
var suspended_level_01: Node2D = null

@onready var title: Control = $Title
@onready var game_result_popup: CanvasLayer = $GameResultPopup
@onready var result_label: Label = $GameResultPopup/Control/NinePatchRect/VBoxContainer/Label
@onready var retry_button: Button = $GameResultPopup/Control/NinePatchRect/VBoxContainer/HBoxContainer/Retry
@onready var quit_button: Button = $GameResultPopup/Control/NinePatchRect/VBoxContainer/HBoxContainer/Quit


func _ready() -> void:
	game_result_popup.visible = false
	title.connect("start_requested", _on_title_start_requested)
	retry_button.pressed.connect(_on_retry_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func connect_level_events() -> void:
	var player := level.get_node("Player")
	var wolf_king := level.get_node("Enemies/WolfKing")
	player.connect("died", _on_player_died)
	wolf_king.connect("died", _on_wolf_king_died)


func set_player_controls_enabled(enabled: bool) -> void:
	if level == null:
		return

	var player := level.get_node_or_null("Player")
	if player != null and player.has_method("set_controls_enabled"):
		player.set_controls_enabled(enabled)


func show_result(result_text: String) -> void:
	if game_result_popup.visible:
		return

	set_player_controls_enabled(false)
	result_label.text = result_text
	game_result_popup.visible = true


func start_level_01(play_intro: bool = true) -> void:
	game_result_popup.visible = false

	if level != null:
		var old_level := level
		level = null
		remove_child(old_level)
		old_level.queue_free()

	level = LEVEL_01_SCENE.instantiate() as Node2D
	level.name = "Level01"
	if not play_intro:
		var story := level.get_node_or_null("Story")
		if story != null:
			level.remove_child(story)
			story.queue_free()

	add_child(level)
	move_child(level, 0)
	if play_intro:
		level.connect("intro_finished", _on_level_01_intro_finished)
	connect_level_events()


func play_level_00() -> void:
	suspended_level_01 = level
	var background := suspended_level_01.get_node("Background")
	background.call("stop_music")
	remove_child(suspended_level_01)

	level = LEVEL_00_SCENE.instantiate() as Node2D
	level.name = "Level00"
	var story := level.get_node("Story")
	story.connect("story_finished", _on_level_00_story_finished)
	add_child(level)
	move_child(level, 0)


func _on_title_start_requested() -> void:
	title.visible = false
	title.queue_free()
	start_level_01()


func _on_level_01_intro_finished() -> void:
	play_level_00()


func _on_level_00_story_finished() -> void:
	var finished_level_00 := level
	level = suspended_level_01
	suspended_level_01 = null

	remove_child(finished_level_00)
	finished_level_00.queue_free()
	add_child(level)
	move_child(level, 0)


func _on_player_died() -> void:
	show_result(RESULT_DEAD)


func _on_wolf_king_died() -> void:
	show_result(RESULT_VICTORY)


func _on_retry_pressed() -> void:
	start_level_01(false)


func _on_quit_pressed() -> void:
	get_tree().quit()
