extends Node2D


const LEVEL_00_SCENE := preload("res://levels/level_00.tscn")
const LEVEL_01_SCENE := preload("res://levels/level_01.tscn")
const LEVEL_02_SCENE := preload("res://levels/level_02.tscn")
const STORY_SCENE := preload("res://ui/story.tscn")
const LEVEL_01_VICTORY_STORY := "res://levels/level_01_a_story.json"
const LEVEL_02_VICTORY_STORY := "res://levels/level_02_a_story.json"
const RESULT_DEAD := "DEAD"

var level: Node2D = null
var suspended_level_01: Node2D = null
var victory_story_active := false
var current_level_scene: PackedScene = null

@onready var title: Control = $Title
@onready var guide: Control = $Guide
@onready var game_result_popup: CanvasLayer = $GameResultPopup
@onready var result_label: Label = $GameResultPopup/Control/NinePatchRect/VBoxContainer/Label
@onready var retry_button: Button = $GameResultPopup/Control/NinePatchRect/VBoxContainer/HBoxContainer/Retry
@onready var quit_button: Button = $GameResultPopup/Control/NinePatchRect/VBoxContainer/HBoxContainer/Quit


func _ready() -> void:
	game_result_popup.visible = false
	title.connect("start_requested", _on_title_start_requested)
	retry_button.pressed.connect(_on_retry_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _input(event: InputEvent) -> void:
	if not guide.visible:
		return
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	if not event.is_pressed() or event.is_echo():
		return

	get_viewport().set_input_as_handled()
	guide.visible = false
	start_level_01()


func connect_level_events() -> void:
	var player := level.get_node("Player")
	player.connect("died", _on_player_died)

	var wolf_king := level.get_node_or_null("Enemies/WolfKing")
	if wolf_king != null:
		wolf_king.connect("died", _on_wolf_king_died)

	var bear_king := level.get_node_or_null("Enemies/BearKing")
	if bear_king != null:
		bear_king.connect("died", _on_bear_king_died)


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


func start_level(scene: PackedScene, play_intro: bool) -> void:
	game_result_popup.visible = false

	if level != null:
		var old_level := level
		level = null
		remove_child(old_level)
		old_level.queue_free()

	current_level_scene = scene
	level = scene.instantiate() as Node2D
	var player := level.get_node("Player")
	player.restore_full_health()
	if not play_intro:
		var story := level.get_node_or_null("Story")
		if story != null:
			level.remove_child(story)
			story.queue_free()

	add_child(level)
	move_child(level, 0)
	connect_level_events()


func start_level_01(play_intro: bool = true) -> void:
	start_level(LEVEL_01_SCENE, play_intro)
	if play_intro:
		level.connect("intro_finished", _on_level_01_intro_finished)


func start_level_02(play_intro: bool = true) -> void:
	start_level(LEVEL_02_SCENE, play_intro)


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
	guide.visible = true


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
	if victory_story_active:
		return

	show_result(RESULT_DEAD)


func _on_wolf_king_died() -> void:
	play_victory_story(LEVEL_01_VICTORY_STORY, _on_victory_story_finished)


func _on_bear_king_died() -> void:
	play_victory_story(LEVEL_02_VICTORY_STORY, _on_level_02_victory_story_finished)


func play_victory_story(story_path: String, finished_callback: Callable) -> void:
	if victory_story_active:
		return

	victory_story_active = true
	game_result_popup.visible = false
	set_player_controls_enabled(false)
	var story := STORY_SCENE.instantiate() as CanvasLayer
	story.name = "VictoryStory"
	story.set("story_path", story_path)
	story.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	story.connect("story_finished", finished_callback.bind(story), CONNECT_ONE_SHOT)
	level.add_child(story)
	get_tree().paused = true


func _on_victory_story_finished(story: CanvasLayer) -> void:
	get_tree().paused = false
	story.queue_free()
	victory_story_active = false
	start_level_02()


func _on_level_02_victory_story_finished(story: CanvasLayer) -> void:
	get_tree().paused = false
	story.queue_free()
	victory_story_active = false
	set_player_controls_enabled(true)


func _on_retry_pressed() -> void:
	if current_level_scene == null:
		return

	start_level(current_level_scene, false)


func _on_quit_pressed() -> void:
	get_tree().quit()
