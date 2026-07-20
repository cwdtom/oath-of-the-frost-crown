extends "res://levels/level_base.gd"


const TERMINAL_OUTCOME_NONE := &"none"
const TERMINAL_OUTCOME_PLAYER_DEFEAT := &"player_defeat"
const TERMINAL_OUTCOME_ELK_KING_DEFEAT := &"elk_king_defeat"
const ELK_KING_DEATH_STAGING_SEPARATION := 470.0

@onready var elk_king = $Enemies/ElkKing

var _terminal_outcome := TERMINAL_OUTCOME_NONE
var _elk_king_death_staging_complete := false
var _elk_king_death_tableau_reached := false


func get_terminal_outcome() -> StringName:
	return _terminal_outcome


func set_campaign_controls_enabled(enabled: bool) -> void:
	super.set_campaign_controls_enabled(
		enabled and _terminal_outcome != TERMINAL_OUTCOME_ELK_KING_DEFEAT
	)


func _ready() -> void:
	super._ready()
	elk_king.connect("died", _on_elk_king_defeated)
	elk_king.death_presentation_finished.connect(
		_on_elk_king_death_presentation_finished
	)


func _physics_process(delta: float) -> void:
	if (
		_terminal_outcome != TERMINAL_OUTCOME_ELK_KING_DEFEAT
		or _elk_king_death_staging_complete
	):
		return

	player.velocity.x = 0.0
	if not player.is_on_floor():
		return

	var target_x: float = (
		elk_king.global_position.x - ELK_KING_DEATH_STAGING_SEPARATION
	)
	var distance_to_target: float = target_x - player.global_position.x
	var maximum_step: float = player.SPEED * delta
	if absf(distance_to_target) <= maximum_step:
		player.global_position.x = target_x
		player.visual_root.scale.x = 1.0
		player.change_state(player.IDLE)
		_elk_king_death_staging_complete = true
		_handoff_to_aila()
		return

	var move_direction: float = signf(distance_to_target)
	player.visual_root.scale.x = move_direction
	player.velocity.x = move_direction * player.SPEED
	player.change_state(player.RUN)


func _handoff_to_aila() -> void:
	var player_sprite := player.get_node("VisualRoot/Sprite2D") as Sprite2D
	var aila_proxy := elk_king.get_node("DeadAnimation/Aila") as Node2D
	var aila_sprite := elk_king.get_node("DeadAnimation/Aila/Aila") as Sprite2D
	var leif_proxy := elk_king.get_node("DeadAnimation/Leif") as Node2D
	var leif_sprite := elk_king.get_node("DeadAnimation/Leif/Leif") as Sprite2D

	aila_sprite.position.x = -ELK_KING_DEATH_STAGING_SEPARATION
	aila_proxy.global_transform = (
		player_sprite.global_transform * aila_sprite.transform.affine_inverse()
	)
	leif_proxy.global_position += (player_sprite.global_position - leif_sprite.global_position + Vector2(100.0, 0.0))
	aila_proxy.visible = true
	player.disable_for_cinematic_handoff()
	elk_king.request_death_presentation()


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


func _on_elk_king_death_presentation_finished() -> void:
	if (
		_terminal_outcome != TERMINAL_OUTCOME_ELK_KING_DEFEAT
		or _elk_king_death_tableau_reached
	):
		return

	_elk_king_death_tableau_reached = true
	super._on_campaign_completed()
