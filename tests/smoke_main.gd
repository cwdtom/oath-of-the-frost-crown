extends SceneTree


const MAIN_SCENE := "res://main.tscn"
const LEVEL_00_STORY := "res://levels/level_00_story.json"
const LEVEL_01_STORY := "res://levels/level_01_story.json"
const RESULT_VICTORY := "VICTORY"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := instantiate_main()
	if main == null:
		finish()
		return

	await process_frame
	var title := main.get_node_or_null("Title")
	expect(title != null, "Main starts with a Title node")
	expect(main.get_node_or_null("GameResultPopup") != null, "Main starts with a result popup")
	if title == null:
		finish()
		return

	title.emit_signal("start_requested")
	await process_frame

	var level_01 := main.get("level") as Node2D
	expect(level_01 != null, "Start creates Level01")
	if level_01 == null:
		finish()
		return

	expect(level_01.name == "Level01", "Start enters Level01 before Level00")
	var level_01_story := level_01.get_node_or_null("Story")
	expect(level_01_story != null, "Level01 contains Story")
	if level_01_story == null:
		finish()
		return

	expect(
		level_01_story.get("story_path") == LEVEL_01_STORY,
		"Level01 uses its configured story JSON"
	)
	var level_01_story_nodes: Array = level_01_story.get("story_nodes")
	expect(not level_01_story_nodes.is_empty(), "Level01 story JSON is loaded")
	if level_01_story_nodes.is_empty():
		finish()
		return

	for _story_node in level_01_story_nodes:
		level_01_story.call("show_next_node")

	await process_frame
	var level := main.get("level") as Node2D
	expect(level != null and level.name == "Level00", "Level01 Story completion starts Level00")
	expect(is_instance_valid(level_01), "Level01 remains alive while Level00 plays")
	if is_instance_valid(level_01):
		expect(not level_01.is_inside_tree(), "Level01 is suspended while Level00 plays")
	if level == null:
		finish()
		return

	var prologue_story := level.get_node_or_null("Story")
	expect(prologue_story != null, "Level00 contains Story")
	if prologue_story == null:
		finish()
		return

	expect(prologue_story.visible, "Level00 Story is visible")
	expect(
		prologue_story.get("story_path") == LEVEL_00_STORY,
		"Level00 uses its configured story JSON"
	)
	var prologue_nodes: Array = prologue_story.get("story_nodes")
	expect(not prologue_nodes.is_empty(), "Level00 story JSON is loaded")
	if prologue_nodes.is_empty():
		finish()
		return

	var first_prologue_node: Dictionary = prologue_nodes[0]
	var prologue_name := prologue_story.get_node("Control/Chat/VBoxContainer/Name") as Label
	var prologue_content := prologue_story.get_node("Control/Chat/VBoxContainer/Content") as Label
	expect(
		prologue_name.text == str(first_prologue_node.get("name", "")),
		"Level00 renders the configured story name"
	)
	expect(
		prologue_content.text == str(first_prologue_node.get("content", "")),
		"Level00 renders the configured story content"
	)
	for _story_node in prologue_nodes:
		prologue_story.call("show_next_node")

	await process_frame
	level = main.get("level") as Node2D
	expect(level == level_01, "Level00 completion restores the original Level01 instance")
	expect(level != null and level.is_inside_tree(), "Level01 returns to the scene tree")
	if level == null:
		finish()
		return
	expect(level.get_node_or_null("Story") == null, "Level01 Story remains finished after returning")

	var player := level.get_node_or_null("Player")
	var wolf_king := level.get_node_or_null("Enemies/WolfKing")
	var hud := level.get_node_or_null("HUD")
	var player_camera := level.get_node_or_null("Player/Camera2D") as Camera2D
	expect(player != null, "Level contains Player")
	expect(wolf_king != null, "Level contains WolfKing")
	expect(hud != null, "Level contains HUD")
	expect(player_camera != null, "Level contains Player camera")
	if player == null or wolf_king == null or hud == null or player_camera == null:
		finish()
		return

	expect(hud.visible, "Level01 HUD is visible after returning from Level00")
	expect(player_camera.is_current(), "Level01 Player camera is current after returning from Level00")
	expect(player.get("controls_enabled") == true, "Player controls start enabled")

	wolf_king.emit_signal("died")
	await process_frame

	var popup := main.get_node("GameResultPopup") as CanvasLayer
	var result_label := main.get_node("GameResultPopup/Control/NinePatchRect/VBoxContainer/Label") as Label
	expect(popup.visible, "Victory shows the result popup")
	expect(result_label.text == RESULT_VICTORY, "Victory result text is shown")
	expect(player.get("controls_enabled") == false, "Victory disables player controls")

	main.call("_on_retry_pressed")
	await process_frame

	var restarted_level := main.get("level") as Node2D
	expect(restarted_level != null, "Retry creates a replacement level")
	expect(restarted_level != level, "Retry replaces the old level instance")
	expect(not popup.visible, "Retry hides the result popup")

	var restarted_player := restarted_level.get_node_or_null("Player") if restarted_level != null else null
	if restarted_player != null:
		expect(restarted_player.get("controls_enabled") == true, "Retry starts with controls enabled")
	else:
		failures.append("Retry level is missing Player")

	finish()


func instantiate_main() -> Node:
	var scene := load(MAIN_SCENE) as PackedScene
	if scene == null:
		failures.append("Could not load %s" % MAIN_SCENE)
		return null

	var main := scene.instantiate()
	root.add_child(main)
	current_scene = main
	return main


func expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("Smoke test passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
