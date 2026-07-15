class_name HeadlessGameplayFixture
extends RefCounted


var _scene_tree: SceneTree
var _previous_current_scene: Node
var _previous_paused: bool
var _owned_nodes: Array[Node] = []
var _owned_physics_rids: Array[RID] = []
var _setting_changes: Array[Dictionary] = []
var _failures: Array[String] = []
var _completed := false


func _init(scene_tree: SceneTree) -> void:
	_scene_tree = scene_tree
	_previous_current_scene = scene_tree.current_scene
	_previous_paused = scene_tree.paused


func instantiate_scene(scene: PackedScene) -> Node:
	if scene == null:
		expect(false, "Cannot instantiate a missing scene")
		return null
	var instance := scene.instantiate()
	if instance == null:
		expect(false, "Scene instantiation failed")
		return null
	add_node(instance)
	return instance


func add_node(node: Node, parent: Node = null) -> Node:
	if node.get_parent() == null:
		var target_parent := parent if parent != null else _scene_tree.root
		target_parent.add_child(node)
	_owned_nodes.append(node)
	return node


func own_physics_rid(rid: RID) -> RID:
	_owned_physics_rids.append(rid)
	return rid


func set_current_scene(scene: Node) -> void:
	_scene_tree.current_scene = scene


func set_paused(value: bool) -> void:
	_scene_tree.paused = value


func set_project_setting(name: String, value: Variant) -> void:
	var existed := ProjectSettings.has_setting(name)
	_setting_changes.append(
		{
			"name": name,
			"existed": existed,
			"value": ProjectSettings.get_setting(name) if existed else null,
		}
	)
	ProjectSettings.set_setting(name, value)


func process_frames(count: int) -> void:
	for _frame in count:
		await _scene_tree.process_frame


func physics_frames(count: int) -> void:
	for _frame in count:
		await _scene_tree.physics_frame


func wait_seconds(duration: float) -> void:
	await _scene_tree.create_timer(duration).timeout


func expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func get_failures() -> Array[String]:
	return _failures.duplicate()


func complete(quit_process := true) -> int:
	if not _completed:
		_completed = true
		_cleanup()

	var exit_code := 0 if _failures.is_empty() else 1
	if quit_process:
		for failure in _failures:
			push_error(failure)
		_scene_tree.quit(exit_code)
	return exit_code


func _cleanup() -> void:
	_scene_tree.paused = _previous_paused
	_scene_tree.current_scene = (
		_previous_current_scene if is_instance_valid(_previous_current_scene) else null
	)
	for index in range(_owned_nodes.size() - 1, -1, -1):
		var node := _owned_nodes[index]
		if is_instance_valid(node):
			node.free()
	_owned_nodes.clear()
	for index in range(_owned_physics_rids.size() - 1, -1, -1):
		PhysicsServer2D.free_rid(_owned_physics_rids[index])
	_owned_physics_rids.clear()
	for index in range(_setting_changes.size() - 1, -1, -1):
		var change := _setting_changes[index]
		ProjectSettings.set_setting(change["name"], change["value"] if change["existed"] else null)
	_setting_changes.clear()
