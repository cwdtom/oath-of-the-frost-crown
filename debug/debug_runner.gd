extends "res://main.gd"


const DEBUG_PLAYER_HEALTH := 999
const DEBUG_ENEMY_HEALTH := 1

var _replacing_level := false


func _ready() -> void:
	super._ready()
	get_tree().node_added.connect(_on_node_added)
	get_window().window_input.connect(_on_window_input)
	start_level_01()


func _on_window_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo or not key_event.ctrl_pressed:
		return

	var checkpoint_scene: PackedScene
	var play_opening_story: bool
	match key_event.keycode:
		KEY_1:
			checkpoint_scene = LEVEL_01_SCENE
			play_opening_story = true
		KEY_2:
			checkpoint_scene = LEVEL_01_SCENE
			play_opening_story = false
		KEY_3:
			checkpoint_scene = LEVEL_02_SCENE
			play_opening_story = true
		KEY_4:
			checkpoint_scene = LEVEL_02_SCENE
			play_opening_story = false
		_:
			return

	get_viewport().set_input_as_handled()
	replace_campaign_session(checkpoint_scene, play_opening_story)


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
