extends SceneTree


const MAIN_SCENE := "res://main.tscn"
const LEVEL_00_STORY := "res://levels/level_00_story.json"
const LEVEL_01_STORY := "res://levels/level_01_story.json"
const LEVEL_01_VICTORY_STORY := "res://levels/level_01_a_story.json"
const MUSIC_RESUME_POSITION := 5.0
const RESULT_VICTORY := "VICTORY"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await verify_keyboard_guide_input()

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

	var guide := main.get_node_or_null("Guide") as Control
	expect(guide != null, "Start keeps the Guide node")
	expect(guide != null and guide.visible, "Start shows the Guide")
	expect(main.get("level") == null, "Level01 waits for Guide input")
	if guide == null or main.get("level") != null:
		finish()
		return

	var guide_input := InputEventMouseButton.new()
	guide_input.button_index = MOUSE_BUTTON_LEFT
	guide_input.pressed = true
	Input.parse_input_event(guide_input)
	await process_frame

	expect(not guide.visible, "Guide input hides the Guide")
	var level_01 := main.get("level") as Node2D
	expect(level_01 != null, "Guide input creates Level01")
	if level_01 == null:
		finish()
		return

	Input.parse_input_event(guide_input)
	await process_frame
	expect(main.get("level") == level_01, "Guide input creates Level01 only once")

	expect(level_01.name == "Level01", "Start enters Level01 before Level00")
	var level_01_story := level_01.get_node_or_null("Story")
	var level_01_music := level_01.get_node_or_null("Background/AudioStreamPlayer") as AudioStreamPlayer
	expect(level_01_story != null, "Level01 contains Story")
	expect(level_01_music != null, "Level01 contains background music")
	if level_01_music != null:
		expect(level_01_music.stream.get("loop") == true, "Level01 music loops")
		expect(
			level_01_music.process_mode == Node.PROCESS_MODE_ALWAYS,
			"Level01 music keeps processing while its Story pauses the scene"
		)
		if DisplayServer.get_name() != "headless":
			expect(level_01_music.playing, "Level01 music plays while its Story is active")
			level_01_music.play(MUSIC_RESUME_POSITION)
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

	for story_node_index in level_01_story_nodes.size():
		level_01_story.call("show_next_node")
		if (
			level_01_music != null
			and DisplayServer.get_name() != "headless"
			and story_node_index < level_01_story_nodes.size() - 1
		):
			expect(level_01_music.playing, "Level01 Story does not interrupt its music")

	await process_frame
	var level := main.get("level") as Node2D
	expect(level != null and level.name == "Level00", "Level01 Story completion starts Level00")
	expect(is_instance_valid(level_01), "Level01 remains alive while Level00 plays")
	if is_instance_valid(level_01):
		expect(not level_01.is_inside_tree(), "Level01 is suspended while Level00 plays")
		if level_01_music != null:
			expect(not level_01_music.playing, "Level01 music stops while Level00 plays")
			expect(level_01_music.stream != null, "Level01 keeps its music stream for resuming")
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
	if level_01_music != null:
		expect(level_01_music.stream != null, "Level01 still has its music stream after Level00")
		if DisplayServer.get_name() != "headless":
			expect(level_01_music.playing, "Level01 music resumes after Level00")
			expect(
				level_01_music.get_playback_position() >= MUSIC_RESUME_POSITION,
				"Level01 music resumes from its position before Level00"
			)

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

	var popup := main.get_node("GameResultPopup") as CanvasLayer
	var result_label := main.get_node("GameResultPopup/Control/NinePatchRect/VBoxContainer/Label") as Label
	player.emit_signal("died")
	wolf_king.call("die")
	await process_frame

	var victory_story := level.get_node_or_null("VictoryStory") as CanvasLayer
	expect(victory_story != null, "WolfKing death starts the victory Story")
	expect(
		wolf_king.process_mode == Node.PROCESS_MODE_ALWAYS,
		"WolfKing death animation continues during the victory Story"
	)
	expect(not popup.visible, "Victory Story hides a competing defeat popup")
	expect(paused, "Victory Story pauses gameplay")
	expect(player.get("controls_enabled") == false, "Victory Story disables player controls")
	if victory_story == null:
		finish()
		return

	expect(
		victory_story.get("story_path") == LEVEL_01_VICTORY_STORY,
		"Victory Story uses its configured story JSON"
	)
	var victory_story_nodes: Array = victory_story.get("story_nodes")
	expect(not victory_story_nodes.is_empty(), "Victory Story JSON is loaded")
	if victory_story_nodes.is_empty():
		finish()
		return

	player.emit_signal("died")
	expect(not popup.visible, "Player death cannot interrupt the victory Story")

	for _story_node in victory_story_nodes:
		victory_story.call("show_next_node")

	await process_frame
	expect(not paused, "Victory Story completion resumes the scene tree")
	expect(level.get_node_or_null("VictoryStory") == null, "Finished victory Story is removed")
	expect(popup.visible, "Victory shows the result popup")
	expect(result_label.text == RESULT_VICTORY, "Victory result text is shown")
	expect(player.get("controls_enabled") == false, "Victory disables player controls")

	main.call("_on_retry_pressed")
	await process_frame

	var restarted_level := main.get("level") as Node2D
	expect(restarted_level != null, "Retry creates a replacement level")
	expect(restarted_level != level, "Retry replaces the old level instance")
	expect(not popup.visible, "Retry hides the result popup")
	expect(
		restarted_level != null and restarted_level.get_node_or_null("Story") == null,
		"Retry returns to Level01 after its stories"
	)
	expect(not paused, "Retry returns to an unpaused Level01")

	var restarted_player := restarted_level.get_node_or_null("Player") if restarted_level != null else null
	var restarted_hud := restarted_level.get_node_or_null("HUD") if restarted_level != null else null
	var restarted_camera := (
		restarted_level.get_node_or_null("Player/Camera2D") as Camera2D
		if restarted_level != null
		else null
	)
	if restarted_player != null:
		expect(restarted_player.get("controls_enabled") == true, "Retry starts with controls enabled")
	else:
		failures.append("Retry level is missing Player")
	expect(restarted_hud != null and restarted_hud.visible, "Retry shows the Level01 HUD")
	expect(restarted_camera != null and restarted_camera.is_current(), "Retry restores the Player camera")

	await process_frame
	expect(main.get("level") == restarted_level, "Retry does not start Level00 again")

	finish()


func verify_keyboard_guide_input() -> void:
	var main := instantiate_main()
	if main == null:
		return

	await process_frame
	var title := main.get_node_or_null("Title")
	var guide := main.get_node_or_null("Guide") as Control
	if title == null or guide == null:
		failures.append("Keyboard Guide check is missing Title or Guide")
	else:
		title.emit_signal("start_requested")
		await process_frame

		var guide_input := InputEventKey.new()
		guide_input.keycode = KEY_SPACE
		guide_input.pressed = true
		Input.parse_input_event(guide_input)
		await process_frame

		expect(not guide.visible, "Keyboard input hides the Guide")
		expect(main.get("level") != null, "Keyboard input creates Level01")

	current_scene = null
	main.free()
	await process_frame


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
