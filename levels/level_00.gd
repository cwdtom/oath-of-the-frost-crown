extends "res://levels/campaign_level.gd"


func _ready() -> void:
	var opening_story := get_node_or_null("Story")
	if opening_story != null:
		opening_story.connect("story_finished", _on_story_finished)


func prepare_for_campaign(play_opening_story: bool) -> void:
	if play_opening_story:
		return

	var opening_story := get_node_or_null("Story")
	if opening_story != null:
		remove_child(opening_story)
		opening_story.queue_free()


func _on_story_finished() -> void:
	campaign_story_phase_finished.emit()
