extends Control


signal start_requested

const BACKGROUND_LAYER_SPEEDS := {
	"Background/Sky": Vector2(-6.0, 0.0),
	"Background/FarTree": Vector2(-14.0, 0.0),
	"Background/Fog": Vector2(-24.0, 0.0),
	"Background/NearTree": Vector2(-42.0, 0.0),
}

var background_offsets := {}

@onready var start_button: Button = $VBoxContainer/Start
@onready var quit_button: Button = $VBoxContainer/Quit


func _ready() -> void:
	fit_to_viewport()
	get_viewport().size_changed.connect(fit_to_viewport)

	for path in BACKGROUND_LAYER_SPEEDS:
		background_offsets[path] = Vector2.ZERO

	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func fit_to_viewport() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _process(delta: float) -> void:
	for path in BACKGROUND_LAYER_SPEEDS:
		var layer := get_node_or_null(NodePath(path)) as Parallax2D
		if layer == null:
			continue

		var offset: Vector2 = background_offsets[path]
		offset += BACKGROUND_LAYER_SPEEDS[path] * delta
		background_offsets[path] = offset
		layer.set("scroll_offset", offset)


func _on_start_pressed() -> void:
	start_requested.emit()


func _on_quit_pressed() -> void:
	get_tree().quit()
