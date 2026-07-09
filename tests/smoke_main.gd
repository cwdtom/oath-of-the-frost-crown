extends SceneTree


const MAIN_SCENE := "res://main.tscn"
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

	var level := main.get("level") as Node2D
	expect(level != null, "Start creates the level")
	if level == null:
		finish()
		return

	var player := level.get_node_or_null("Player")
	var wolf_king := level.get_node_or_null("Enemies/WolfKing")
	var hud := level.get_node_or_null("HUD")
	expect(player != null, "Level contains Player")
	expect(wolf_king != null, "Level contains WolfKing")
	expect(hud != null, "Level contains HUD")
	if player == null or wolf_king == null or hud == null:
		finish()
		return

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
