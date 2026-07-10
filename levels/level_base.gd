extends Node2D


signal intro_finished

@onready var player = $Player
@onready var hud = $HUD
@onready var spawn_point = $SpawnPoint
@onready var story: CanvasLayer = get_node_or_null("Story") as CanvasLayer
@onready var player_camera: Camera2D = $Player/Camera2D

var story_camera: Camera2D = null


func _ready() -> void:
	player.global_position = spawn_point.global_position
	hud.set_health(player.health)
	player.hurt_taken.connect(hud.decrease_health)

	if story != null:
		story_camera = Camera2D.new()
		story_camera.name = "StoryCamera"
		story_camera.position = Vector2.ZERO
		story_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
		story_camera.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		add_child(story_camera)
		story_camera.make_current()
		story_camera.force_update_scroll()

		hud.visible = false
		story.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		story.connect("story_finished", _on_story_finished)
		get_tree().paused = true


func _exit_tree() -> void:
	if story != null:
		get_tree().paused = false


func _on_story_finished() -> void:
	var finished_story := story
	var finished_camera := story_camera
	story = null
	story_camera = null

	player_camera.make_current()
	player_camera.reset_smoothing()
	player_camera.force_update_scroll()
	finished_camera.queue_free()

	hud.visible = true
	get_tree().paused = false
	finished_story.queue_free()
	intro_finished.emit()
