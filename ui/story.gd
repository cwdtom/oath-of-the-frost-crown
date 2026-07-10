extends CanvasLayer


signal story_finished

const CONTENT_CHARACTER_INTERVAL := 0.05

@export_file("*.json") var story_path := "res://ui/story_test.json"

var story_nodes: Array = []
var current_node_index := -1
var content_character_elapsed := 0.0

@onready var left_portrait: TextureRect = $Control/Left
@onready var right_portrait: TextureRect = $Control/Right
@onready var name_label: Label = $Control/Chat/VBoxContainer/Name
@onready var content_label: Label = $Control/Chat/VBoxContainer/Content


func _ready() -> void:
	if not load_story():
		set_process_input(false)
		return

	show_next_node.call_deferred()


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return

	get_viewport().set_input_as_handled()
	if content_label.visible_characters < content_label.text.length():
		content_label.visible_characters = content_label.text.length()
		content_character_elapsed = 0.0
		return

	show_next_node()


func _process(delta: float) -> void:
	if content_label.visible_characters >= content_label.text.length():
		return

	content_character_elapsed += delta
	while content_character_elapsed >= CONTENT_CHARACTER_INTERVAL:
		content_character_elapsed -= CONTENT_CHARACTER_INTERVAL
		content_label.visible_characters += 1
		if content_label.visible_characters >= content_label.text.length():
			return


func load_story() -> bool:
	var file := FileAccess.open(story_path, FileAccess.READ)
	if file == null:
		push_error("Unable to open story file: %s" % story_path)
		return false

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		push_error(
			"Unable to parse story file at line %d: %s"
			% [json.get_error_line(), json.get_error_message()]
		)
		return false

	if not json.data is Array:
		push_error("Story file root must be an array: %s" % story_path)
		return false

	story_nodes = json.data
	return true


func show_next_node() -> void:
	current_node_index += 1
	if current_node_index >= story_nodes.size():
		set_process_input(false)
		story_finished.emit()
		return

	var story_node: Variant = story_nodes[current_node_index]
	if not story_node is Dictionary:
		push_error("Story node %d must be an object" % current_node_index)
		show_next_node()
		return

	name_label.text = str(story_node.get("name", ""))
	content_label.text = str(story_node.get("content", ""))
	content_label.visible_characters = 0
	content_character_elapsed = 0.0
	set_portrait(left_portrait, str(story_node.get("left", "")))
	set_portrait(right_portrait, str(story_node.get("right", "")))


func set_portrait(portrait: TextureRect, texture_path: String) -> void:
	portrait.texture = load(texture_path) as Texture2D if not texture_path.is_empty() else null
	portrait.visible = portrait.texture != null
