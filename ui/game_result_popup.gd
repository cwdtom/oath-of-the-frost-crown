extends CanvasLayer


signal retry_requested
signal quit_requested

@onready var _result_label: Label = $Control/NinePatchRect/VBoxContainer/Label
@onready var _retry_button: Button = $Control/NinePatchRect/VBoxContainer/HBoxContainer/Retry
@onready var _quit_button: Button = $Control/NinePatchRect/VBoxContainer/HBoxContainer/Quit


func _ready() -> void:
	_retry_button.pressed.connect(_on_retry_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


func show_result(result_text: String) -> void:
	_result_label.text = result_text
	visible = true


func hide_result() -> void:
	visible = false


func is_result_visible() -> bool:
	return visible


func get_result_text() -> String:
	return _result_label.text


func _on_retry_pressed() -> void:
	retry_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()
