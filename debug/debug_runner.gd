extends "res://main.gd"


class CheckpointInputGuard:
	extends Node

	var checkpoint_input: Callable

	func _input(event: InputEvent) -> void:
		checkpoint_input.call(event)


const DEBUG_PLAYER_HEALTH := 999
const DEBUG_ENEMY_HEALTH := 1
const CHECKPOINTS := [
	{"scene": LEVEL_01_SCENE, "play_opening_story": true},
	{"scene": LEVEL_01_SCENE, "play_opening_story": false},
	{"scene": LEVEL_02_SCENE, "play_opening_story": true},
	{"scene": LEVEL_02_SCENE, "play_opening_story": false},
	{"scene": LEVEL_03_SCENE, "play_opening_story": true},
	{"scene": LEVEL_03_SCENE, "play_opening_story": false},
	null,
	null,
]

var _replacing_level := false
var _checkpoint_input_guard: CheckpointInputGuard


func _ready() -> void:
	super._ready()
	get_tree().node_added.connect(_on_node_added)
	start_level_01()
	_checkpoint_input_guard = CheckpointInputGuard.new()
	_checkpoint_input_guard.name = "CheckpointInputGuard"
	_checkpoint_input_guard.process_mode = Node.PROCESS_MODE_ALWAYS
	_checkpoint_input_guard.checkpoint_input = _on_checkpoint_input
	add_child(_checkpoint_input_guard)


func _on_checkpoint_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or not key_event.ctrl_pressed:
		return

	if key_event.keycode < KEY_1 or key_event.keycode > KEY_8:
		return

	get_viewport().set_input_as_handled()
	var checkpoint_number := key_event.keycode - KEY_1 + 1
	var checkpoint: Variant = CHECKPOINTS[checkpoint_number - 1]
	if checkpoint == null:
		print("Debug Runner: checkpoint %d is unassigned." % checkpoint_number)
		return

	var checkpoint_config := checkpoint as Dictionary
	replace_campaign_session(
		checkpoint_config["scene"] as PackedScene,
		bool(checkpoint_config["play_opening_story"])
	)


func replace_level(scene: PackedScene, next_level: CampaignLevel) -> void:
	_replacing_level = true
	super.replace_level(scene, next_level)
	_replacing_level = false
	_apply_debug_health_overrides(next_level)


func _apply_debug_health_overrides(level: CampaignLevel) -> void:
	var player := level.get_node_or_null("Player")
	if player != null and player.has_method("apply_debug_health_override"):
		player.call("apply_debug_health_override", DEBUG_PLAYER_HEALTH)

	for node in get_tree().get_nodes_in_group("enemies"):
		if node is Node and _is_compatible_enemy(level, node):
			node.call("apply_debug_health_override", DEBUG_ENEMY_HEALTH)


func _on_node_added(node: Node) -> void:
	if _replacing_level:
		return

	var level := get_active_campaign_level()
	if level == null or not _is_compatible_enemy(level, node):
		return

	if node.is_node_ready():
		_apply_late_enemy_health_override(node)
	else:
		node.ready.connect(_apply_late_enemy_health_override.bind(node), CONNECT_ONE_SHOT)


func _apply_late_enemy_health_override(enemy: Node) -> void:
	var level := get_active_campaign_level()
	if level == null or not _is_compatible_enemy(level, enemy):
		return
	enemy.call("apply_debug_health_override", DEBUG_ENEMY_HEALTH)


func _is_compatible_enemy(level: CampaignLevel, node: Node) -> bool:
	return (
		level.is_ancestor_of(node)
		and node.is_in_group("enemies")
		and node.has_method("apply_debug_health_override")
	)
