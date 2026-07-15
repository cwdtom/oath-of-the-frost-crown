class_name CampaignLevel
extends Node2D


signal campaign_outcome_reached(outcome: StringName)
signal campaign_story_phase_finished

const OUTCOME_DEFEAT := &"defeat"
const OUTCOME_COMPLETION := &"completion"
const CAMERA_NONE := &"none"
const CAMERA_PLAYER := &"player"
const CAMERA_OPENING_STORY := &"opening_story"

@export var campaign_id: StringName
@export var supported_campaign_outcomes: Array[StringName] = []


func get_campaign_id() -> StringName:
	return campaign_id


func get_supported_campaign_outcomes() -> Array[StringName]:
	return supported_campaign_outcomes.duplicate()


func is_campaign_story_phase_active() -> bool:
	return false


func is_campaign_control_available() -> bool:
	return false


func is_campaign_hud_visible() -> bool:
	return false


func is_campaign_health_full() -> bool:
	return false


func get_campaign_camera_role() -> StringName:
	return CAMERA_NONE


func has_campaign_music() -> bool:
	return false


func is_campaign_music_playing() -> bool:
	return false


func get_campaign_music_playback_position() -> float:
	return 0.0


func prepare_for_campaign(_play_opening_story: bool) -> void:
	pass


func set_campaign_controls_enabled(_enabled: bool) -> void:
	pass


func start_campaign_victory_story() -> bool:
	return false


func suspend_from_campaign() -> void:
	pass


func restore_to_campaign() -> void:
	pass
