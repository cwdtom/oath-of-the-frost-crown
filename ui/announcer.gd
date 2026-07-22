extends CanvasLayer


signal announcement_finished

@export_multiline var announcement_text := ""

@onready var label: Label = $Control/VBoxContainer/MarginContainer/Label


func get_announcement_text() -> String:
	return announcement_text


func _ready() -> void:
	label.text = announcement_text


func _on_timer_timeout() -> void:
	announcement_finished.emit()
