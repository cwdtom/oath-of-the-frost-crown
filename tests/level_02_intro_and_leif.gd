extends SceneTree


const LEVEL_02_SCENE := "res://levels/level_02.tscn"
const LEVEL_02_STORY := "res://levels/level_02_story.json"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load(LEVEL_02_SCENE) as PackedScene
	if scene == null:
		failures.append("Could not load %s" % LEVEL_02_SCENE)
		finish()
		return

	var level := scene.instantiate() as Node2D
	root.add_child(level)
	current_scene = level
	await process_frame

	var story := level.get_node_or_null("Story") as CanvasLayer
	expect(story != null, "Level02 contains an opening Story")
	if story != null:
		expect(
			story.get("story_path") == LEVEL_02_STORY,
			"Level02 uses level_02_story.json"
		)
		var story_nodes: Array = story.get("story_nodes")
		expect(not story_nodes.is_empty(), "Level02 opening Story is loaded")
		for _story_node in story_nodes:
			story.call("show_next_node")

	await process_frame
	expect(not paused, "Level02 resumes after its opening Story")

	var player := level.get_node_or_null("Player") as Node2D
	var leif := level.get_node_or_null("Leif") as Node2D
	var leif_sprite := leif.get_node_or_null("Sprite2D") as Sprite2D if leif != null else null
	expect(player != null, "Level02 contains Player")
	expect(leif != null, "Level02 contains Leif")
	expect(leif_sprite != null, "Leif contains Sprite2D")
	if player != null and leif != null and leif_sprite != null:
		player.global_position.x = leif.global_position.x + 100.0
		await process_frame
		expect(not leif_sprite.flip_h, "Leif faces a player on his right")

		player.global_position.x = leif.global_position.x - 100.0
		await process_frame
		expect(leif_sprite.flip_h, "Leif faces a player on his left")

	current_scene = null
	level.free()
	paused = false
	finish()


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("Level02 intro and Leif test passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
