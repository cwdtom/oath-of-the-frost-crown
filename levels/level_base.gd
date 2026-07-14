extends "res://levels/campaign_level.gd"


signal intro_finished

@export_node_path("Node") var _campaign_completion_source_path: NodePath

@onready var player = $Player
@onready var hud = $HUD
@onready var story: CanvasLayer = get_node_or_null("Story") as CanvasLayer
@onready var player_camera: Camera2D = $Player/Camera2D

var story_camera: Camera2D = null


func prepare_for_campaign(play_opening_story: bool) -> void:
	var level_player := get_node("Player")
	level_player.restore_full_health()
	if play_opening_story:
		return

	var opening_story := get_node_or_null("Story")
	if opening_story != null:
		remove_child(opening_story)
		opening_story.queue_free()


func is_campaign_story_phase_active() -> bool:
	return story != null


func is_campaign_control_available() -> bool:
	return is_inside_tree() and not get_tree().paused and player.controls_enabled


func is_campaign_hud_visible() -> bool:
	return is_inside_tree() and hud.visible


func get_campaign_camera_role() -> StringName:
	if story_camera != null and story_camera.is_current():
		return CAMERA_OPENING_STORY
	if player_camera.is_current():
		return CAMERA_PLAYER
	return CAMERA_NONE


func set_campaign_controls_enabled(enabled: bool) -> void:
	player.set_controls_enabled(enabled)


func suspend_from_campaign() -> void:
	var background := get_node_or_null("Background")
	if background != null:
		background.call("stop_music")


func restore_to_campaign() -> void:
	var background := get_node_or_null("Background")
	if background != null:
		background.call("start_music")


func _ready() -> void:
	hud.set_health(player.health)
	player.hurt_taken.connect(hud.decrease_health)
	player.connect("died", _on_campaign_defeated)

	var completion_source := get_node_or_null(_campaign_completion_source_path)
	if completion_source != null:
		completion_source.connect("died", _on_campaign_completed)

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
	campaign_story_phase_finished.emit()


func _on_campaign_defeated() -> void:
	campaign_outcome_reached.emit(OUTCOME_DEFEAT)


func _on_campaign_completed() -> void:
	campaign_outcome_reached.emit(OUTCOME_COMPLETION)
