extends Node2D


const LEVEL_00_SCENE := preload("res://levels/level_00.tscn")
const LEVEL_01_SCENE := preload("res://levels/level_01.tscn")
const LEVEL_02_SCENE := preload("res://levels/level_02.tscn")
const LEVEL_03_SCENE := preload("res://levels/level_03.tscn")
const RESULT_DEAD := "DEAD"
const CAMPAIGN_PHASE_TITLE := &"title"
const CAMPAIGN_PHASE_GUIDE := &"guide"
const CAMPAIGN_PHASE_LEVEL := &"level"

var _active_level: CampaignLevel = null
var _suspended_level: CampaignLevel = null
var _victory_story_active := false
var _level_completion_handled := false
var _active_level_scene: PackedScene = null

@onready var _title: Control = $Title
@onready var _guide: Control = $Guide
@onready var _game_result_popup := $GameResultPopup


func _ready() -> void:
	_game_result_popup.hide_result()
	_title.connect("start_requested", _on_title_start_requested)
	_game_result_popup.retry_requested.connect(_on_retry_pressed)
	_game_result_popup.quit_requested.connect(_on_quit_pressed)


func _input(event: InputEvent) -> void:
	if not _guide.visible:
		return
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
	if not event.is_pressed() or event.is_echo():
		return

	get_viewport().set_input_as_handled()
	_guide.visible = false
	start_level_01()


func get_campaign_phase() -> StringName:
	if _active_level != null:
		return CAMPAIGN_PHASE_LEVEL
	if is_instance_valid(_title) and _title.visible:
		return CAMPAIGN_PHASE_TITLE
	if _guide.visible:
		return CAMPAIGN_PHASE_GUIDE
	return CAMPAIGN_PHASE_TITLE


func get_active_campaign_level() -> CampaignLevel:
	return _active_level


func is_campaign_result_visible() -> bool:
	return _game_result_popup.is_result_visible()


func connect_level_events() -> void:
	_active_level.campaign_outcome_reached.connect(
		_on_campaign_outcome_reached.bind(_active_level)
	)


func set_level_controls_enabled(enabled: bool) -> void:
	if _active_level == null:
		return

	_active_level.set_campaign_controls_enabled(enabled)


func show_result(result_text: String) -> void:
	if _game_result_popup.is_result_visible():
		return

	set_level_controls_enabled(false)
	_game_result_popup.show_result(result_text)


func start_level(scene: PackedScene, play_intro: bool) -> void:
	replace_campaign_session(scene, play_intro)


func replace_campaign_session(scene: PackedScene, play_opening_story: bool) -> void:
	get_tree().paused = false
	if is_instance_valid(_title):
		_title.visible = false
	_guide.visible = false
	_victory_story_active = false

	if _suspended_level != null:
		var old_suspended_level := _suspended_level
		_suspended_level = null
		old_suspended_level.queue_free()

	var next_level := scene.instantiate() as CampaignLevel
	next_level.prepare_for_campaign(play_opening_story)
	replace_level(scene, next_level)
	if scene == LEVEL_01_SCENE and play_opening_story:
		_active_level.campaign_story_phase_finished.connect(
			_on_level_01_story_phase_finished.bind(_active_level),
			CONNECT_ONE_SHOT
		)


func replace_level(scene: PackedScene, next_level: CampaignLevel) -> void:
	_game_result_popup.hide_result()

	if _active_level != null:
		var old_level := _active_level
		_active_level = null
		remove_child(old_level)
		old_level.queue_free()

	_active_level_scene = scene
	_active_level = next_level
	_level_completion_handled = false

	add_child(_active_level)
	move_child(_active_level, 0)
	connect_level_events()


func start_level_01(play_intro: bool = true) -> void:
	replace_campaign_session(LEVEL_01_SCENE, play_intro)


func start_level_02(play_intro: bool = true) -> void:
	start_level(LEVEL_02_SCENE, play_intro)


func start_level_03() -> void:
	start_level(LEVEL_03_SCENE, false)


func play_level_00() -> void:
	if _active_level == null or _active_level.get_campaign_id() != &"level_01":
		return
	if _suspended_level != null:
		return

	_suspended_level = _active_level
	_suspended_level.suspend_from_campaign()
	remove_child(_suspended_level)

	_active_level = LEVEL_00_SCENE.instantiate() as CampaignLevel
	_active_level.name = "Level00"
	_active_level.prepare_for_campaign(true)
	_active_level.campaign_story_phase_finished.connect(
		_on_level_00_story_finished.bind(_active_level),
		CONNECT_ONE_SHOT
	)
	add_child(_active_level)
	move_child(_active_level, 0)


func _on_title_start_requested() -> void:
	_title.visible = false
	_title.queue_free()
	_guide.visible = true


func _on_level_01_story_phase_finished(source: CampaignLevel) -> void:
	if source != _active_level:
		return
	play_level_00()


func _on_level_00_story_finished(source: CampaignLevel) -> void:
	if source != _active_level:
		return
	if _suspended_level == null:
		return

	var finished_level_00 := _active_level
	_active_level = _suspended_level
	_suspended_level = null

	remove_child(finished_level_00)
	finished_level_00.queue_free()
	add_child(_active_level)
	move_child(_active_level, 0)
	_active_level.restore_to_campaign()


func _on_campaign_outcome_reached(outcome: StringName, source: CampaignLevel) -> void:
	if source != _active_level:
		return

	match outcome:
		CampaignLevel.OUTCOME_DEFEAT:
			if not _victory_story_active:
				show_result(RESULT_DEAD)
		CampaignLevel.OUTCOME_COMPLETION:
			play_level_victory_story(source)


func play_level_victory_story(source: CampaignLevel) -> void:
	if _victory_story_active or _level_completion_handled:
		return
	if not source.start_campaign_victory_story():
		return

	_victory_story_active = true
	_level_completion_handled = true
	_game_result_popup.hide_result()
	source.campaign_story_phase_finished.connect(
		_on_level_victory_story_finished.bind(source),
		CONNECT_ONE_SHOT
	)


func _on_level_victory_story_finished(source: CampaignLevel) -> void:
	if source != _active_level:
		return
	_victory_story_active = false

	match source.get_campaign_id():
		&"level_01":
			start_level_02()
		&"level_02":
			start_level_03()


func retry_campaign() -> void:
	if _active_level_scene == null:
		return

	get_tree().paused = false
	start_level(_active_level_scene, false)


func _on_retry_pressed() -> void:
	retry_campaign()


func _on_quit_pressed() -> void:
	get_tree().quit()
