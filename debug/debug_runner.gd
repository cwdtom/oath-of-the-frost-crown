extends "res://main.gd"


const DEBUG_PLAYER_HEALTH := 999
const DEBUG_ENEMY_HEALTH := 1

var _replacing_level := false


func _ready() -> void:
	super._ready()
	get_tree().node_added.connect(_on_node_added)
	start_level_01()


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
