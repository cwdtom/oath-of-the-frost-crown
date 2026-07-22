extends "res://levels/level_base.gd"


const PRE_AWAKENING_STORY_PATH := "res://levels/level_04_a_story.json"
const STORY_SCENE := preload("res://ui/story.tscn")
const TERMINAL_OUTCOME_NONE := &"none"
const TERMINAL_OUTCOME_PLAYER_DEFEAT := &"player_defeat"
const TERMINAL_OUTCOME_VALDEMAR_DEFEAT := &"valdemar_defeat"

@onready var valdemar = $Enemies/Valdemar

var _play_pre_awakening_story := true
var _terminal_outcome := TERMINAL_OUTCOME_NONE
var _level_completion_reached := false


func set_pre_awakening_story_enabled(enabled: bool) -> void:
	_play_pre_awakening_story = enabled


func get_terminal_outcome() -> StringName:
	return _terminal_outcome


func set_campaign_controls_enabled(enabled: bool) -> void:
	super.set_campaign_controls_enabled(
		enabled and _terminal_outcome != TERMINAL_OUTCOME_VALDEMAR_DEFEAT
	)


func _ready() -> void:
	super._ready()
	valdemar.awakening_requested.connect(_on_valdemar_awakening_requested)
	valdemar.defeat_started.connect(_on_valdemar_defeat_started)


func _on_campaign_defeated() -> void:
	if _terminal_outcome != TERMINAL_OUTCOME_NONE:
		return

	_terminal_outcome = TERMINAL_OUTCOME_PLAYER_DEFEAT
	super._on_campaign_defeated()


func _on_campaign_completed() -> void:
	if (
		_terminal_outcome != TERMINAL_OUTCOME_VALDEMAR_DEFEAT
		or _level_completion_reached
	):
		return
	_level_completion_reached = true
	super._on_campaign_completed()


func _on_valdemar_defeat_started() -> void:
	if _terminal_outcome != TERMINAL_OUTCOME_NONE:
		return
	if player.is_health_depleted():
		_on_campaign_defeated()
		return

	_terminal_outcome = TERMINAL_OUTCOME_VALDEMAR_DEFEAT
	hud.visible = false
	set_campaign_controls_enabled(false)
	player.set_damage_immune(true)


func _on_valdemar_awakening_requested() -> void:
	if not _play_pre_awakening_story:
		valdemar.begin_awakening()
		return

	set_campaign_controls_enabled(false)
	hud.visible = false
	story = STORY_SCENE.instantiate() as CanvasLayer
	story.name = "PreAwakeningStory"
	story.set("story_path", PRE_AWAKENING_STORY_PATH)
	story.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	story.connect("story_finished", _on_pre_awakening_story_finished, CONNECT_ONE_SHOT)
	add_child(story)
	get_tree().paused = true


func _on_pre_awakening_story_finished() -> void:
	var finished_story := story
	story = null

	hud.visible = true
	get_tree().paused = false
	set_campaign_controls_enabled(true)
	finished_story.queue_free()
	campaign_story_phase_finished.emit()
	valdemar.begin_awakening()
