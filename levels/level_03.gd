extends "res://levels/level_base.gd"


const TERMINAL_OUTCOME_NONE := &"none"
const TERMINAL_OUTCOME_PLAYER_DEFEAT := &"player_defeat"
const TERMINAL_OUTCOME_ELK_KING_DEFEAT := &"elk_king_defeat"

@onready var elk_king = $Enemies/ElkKing

var _terminal_outcome := TERMINAL_OUTCOME_NONE


func get_terminal_outcome() -> StringName:
	return _terminal_outcome


func set_campaign_controls_enabled(enabled: bool) -> void:
	super.set_campaign_controls_enabled(
		enabled and _terminal_outcome != TERMINAL_OUTCOME_ELK_KING_DEFEAT
	)


func _ready() -> void:
	super._ready()
	elk_king.connect("died", _on_elk_king_defeated)


func _on_campaign_defeated() -> void:
	if _terminal_outcome != TERMINAL_OUTCOME_NONE:
		return

	_terminal_outcome = TERMINAL_OUTCOME_PLAYER_DEFEAT
	super._on_campaign_defeated()


func _on_elk_king_defeated() -> void:
	if _terminal_outcome != TERMINAL_OUTCOME_NONE:
		return
	if player.is_health_depleted():
		_on_campaign_defeated()
		return

	_terminal_outcome = TERMINAL_OUTCOME_ELK_KING_DEFEAT
	hud.visible = false
	set_campaign_controls_enabled(false)
	player.set_damage_immune(true)
