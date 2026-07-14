class_name CampaignLevel
extends Node2D


signal campaign_outcome_reached(outcome: StringName)
signal campaign_story_phase_finished

const OUTCOME_DEFEAT := &"defeat"
const OUTCOME_COMPLETION := &"completion"

@export var campaign_id: StringName
@export var supported_campaign_outcomes: Array[StringName] = []


func get_campaign_id() -> StringName:
	return campaign_id


func get_supported_campaign_outcomes() -> Array[StringName]:
	return supported_campaign_outcomes.duplicate()


func prepare_for_campaign(_play_opening_story: bool) -> void:
	pass


func set_campaign_controls_enabled(_enabled: bool) -> void:
	pass


func suspend_from_campaign() -> void:
	pass


func restore_to_campaign() -> void:
	pass
