extends "res://levels/campaign_level.gd"


@export_node_path("Node") var _campaign_completion_source_path: NodePath
@export_file("*.json") var _campaign_victory_story_path := ""

@onready var player = $Player
@onready var hud = $HUD
@onready var story: CanvasLayer = get_node_or_null("Story") as CanvasLayer
@onready var announcer: CanvasLayer = get_node_or_null("Announcer") as CanvasLayer
@onready var player_camera: Camera2D = $Player/Camera2D

var story_camera: Camera2D = null


func prepare_for_campaign(play_opening_story: bool) -> void:
	var level_player := get_node("Player")
	level_player.restore_full_health()
	if play_opening_story:
		var background := get_node_or_null("Background")
		if background != null:
			background.call("set_music_autostart_enabled", false)
		return

	var opening_story := get_node_or_null("Story")
	if opening_story != null:
		remove_child(opening_story)
		opening_story.queue_free()

	var act_announcer := get_node_or_null("Announcer")
	if act_announcer != null:
		remove_child(act_announcer)
		act_announcer.queue_free()


func is_campaign_story_phase_active() -> bool:
	return story != null and announcer == null


func is_campaign_act_announcement_active() -> bool:
	return announcer != null


func get_campaign_act_announcement_text() -> String:
	var announcer := get_node_or_null("Announcer")
	if announcer == null:
		return ""
	return str(announcer.call("get_announcement_text"))


func is_campaign_control_available() -> bool:
	return is_inside_tree() and not get_tree().paused and player.controls_enabled


func is_campaign_hud_visible() -> bool:
	return is_inside_tree() and hud.visible


func is_campaign_health_full() -> bool:
	var maximum_health: int = player.get_maximum_health()
	return (
		player.get_current_health() == maximum_health
		and hud.is_presenting_health(maximum_health, maximum_health)
	)


func get_campaign_camera_role() -> StringName:
	if story_camera != null and story_camera.is_current():
		return CAMERA_OPENING_STORY
	if player_camera.is_current():
		return CAMERA_PLAYER
	return CAMERA_NONE


func has_campaign_music() -> bool:
	return get_node_or_null("Background") != null


func is_campaign_music_playing() -> bool:
	var background := get_node_or_null("Background")
	return background != null and bool(background.call("is_music_playing"))


func has_campaign_music_started() -> bool:
	var background := get_node_or_null("Background")
	return background != null and bool(background.call("has_music_started"))


func get_campaign_music_playback_position() -> float:
	var background := get_node_or_null("Background")
	if background == null:
		return 0.0
	return float(background.call("get_music_playback_position"))


func set_campaign_controls_enabled(enabled: bool) -> void:
	player.set_controls_enabled(enabled)


func start_campaign_victory_story() -> bool:
	if story != null or _campaign_victory_story_path.is_empty():
		return false

	set_campaign_controls_enabled(false)
	var story_scene := load("res://ui/story.tscn") as PackedScene
	story = story_scene.instantiate() as CanvasLayer
	story.name = "VictoryStory"
	story.set("story_path", _campaign_victory_story_path)
	story.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	story.connect("story_finished", _on_victory_story_finished, CONNECT_ONE_SHOT)
	add_child(story)
	get_tree().paused = true
	return true


func suspend_from_campaign() -> void:
	var background := get_node_or_null("Background")
	if background != null:
		background.call("stop_music")


func restore_to_campaign() -> void:
	var background := get_node_or_null("Background")
	if background != null:
		background.call("start_music")


func _ready() -> void:
	hud.present_health(player.get_current_health(), player.get_maximum_health())
	player.health_changed.connect(hud.present_health)
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
		story.process_mode = (
			Node.PROCESS_MODE_DISABLED
			if announcer != null
			else Node.PROCESS_MODE_WHEN_PAUSED
		)
		story.set_process_input(announcer == null)
		story.connect("story_finished", _on_story_finished)
		if announcer != null:
			announcer.connect(
				"announcement_finished",
				_on_act_announcement_finished,
				CONNECT_ONE_SHOT
			)
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
	campaign_story_phase_finished.emit()


func _on_act_announcement_finished() -> void:
	var finished_announcer := announcer
	announcer = null

	story.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	story.set_process_input(true)
	var background := get_node_or_null("Background")
	if background != null:
		background.call("start_music")
	finished_announcer.queue_free()


func _on_victory_story_finished() -> void:
	var finished_story := story
	story = null

	get_tree().paused = false
	finished_story.queue_free()
	campaign_story_phase_finished.emit()


func _on_campaign_defeated() -> void:
	campaign_outcome_reached.emit(OUTCOME_DEFEAT)


func _on_campaign_completed() -> void:
	campaign_outcome_reached.emit(OUTCOME_COMPLETION)
