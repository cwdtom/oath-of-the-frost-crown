extends SceneTree


const MAIN_SCENE := "res://main.tscn"
const LEVEL_00_STORY := "res://levels/level_00_story.json"
const LEVEL_01_STORY := "res://levels/level_01_story.json"
const LEVEL_01_VICTORY_STORY := "res://levels/level_01_a_story.json"
const LEVEL_02_STORY := "res://levels/level_02_story.json"
const LEVEL_02_VICTORY_STORY := "res://levels/level_02_a_story.json"
const MUSIC_RESUME_POSITION := 5.0

var failures: Array[String] = []
var observed_campaign_outcomes: Dictionary[StringName, Array] = {}


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

	var full_player_health: int = player.get("health")
	expect(hud.visible, "Level01 HUD is visible after returning from Level00")
	expect(player_camera.is_current(), "Level01 Player camera is current after returning from Level00")
	expect(player.get("controls_enabled") == true, "Player controls start enabled")

	var popup := main.get_node("GameResultPopup") as CanvasLayer
	var defeated_level := level
	observe_campaign_outcomes(level as CampaignLevel, &"defeated_level_01")
	player.emit_signal("died")
	expect(popup.visible, "Player death shows the result popup")
	expect(player.get("controls_enabled") == false, "Player death disables controls")
	expect(
		has_campaign_outcome(&"defeated_level_01", &"defeat"),
		"Level01 publishes player death as campaign defeat"
	)
	main.call("_on_retry_pressed")
	await process_frame

	var restarted_level := main.get("level") as Node2D
	expect(restarted_level != null, "Retry creates a replacement level")
	expect(not is_instance_valid(defeated_level), "Retry frees the defeated level")
	expect(not popup.visible, "Retry hides the result popup")
	expect(
		restarted_level != null and restarted_level.get_node_or_null("Story") == null,
		"Retry returns to Level01 after its stories"
	)
	expect(not paused, "Retry returns to an unpaused Level01")
	if restarted_level == null:
		finish()
		return

	level = restarted_level
	player = level.get_node_or_null("Player")
	wolf_king = level.get_node_or_null("Enemies/WolfKing")
	hud = level.get_node_or_null("HUD")
	player_camera = level.get_node_or_null("Player/Camera2D") as Camera2D
	expect(player != null and player.get("controls_enabled") == true, "Retry enables controls")
	expect(
		player != null and player.get("health") == full_player_health,
		"Level01 Retry restores full player health"
	)
	expect(hud != null and hud.visible, "Retry shows the Level01 HUD")
	expect(player_camera != null and player_camera.is_current(), "Retry restores the Player camera")
	if player == null or wolf_king == null:
		finish()
		return

	observe_campaign_outcomes(level as CampaignLevel, &"level_01")
	player.set("health", 1)
	player.emit_signal("died")
	wolf_king.call("die")
	await process_frame
	expect(has_campaign_outcome(&"level_01", &"defeat"), "Level01 publishes campaign defeat")
	expect(
		has_campaign_outcome(&"level_01", &"completion"),
		"Level01 publishes campaign completion"
	)

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
	expect(main.get("level") == level, "Level01 remains current while its victory Story is active")

	for _story_node in victory_story_nodes:
		victory_story.call("show_next_node")

	await process_frame
	var level_02 := main.get("level") as Node2D
	expect(level_02 != null and level_02.name == "Level02", "Victory Story completion starts Level02")
	expect(not is_instance_valid(level), "Level01 is freed after starting Level02")
	expect(not popup.visible, "Level02 starts without a result popup")
	expect(paused, "Level02 opening Story pauses gameplay")
	if level_02 == null:
		finish()
		return

	var level_02_player := level_02.get_node_or_null("Player")
	expect(level_02_player != null, "Level02 contains Player")
	expect(
		level_02_player != null and level_02_player.get("health") == full_player_health,
		"Entering Level02 restores full player health"
	)
	var level_02_story := level_02.get_node_or_null("Story") as CanvasLayer
	expect(level_02_story != null, "Level02 starts with its opening Story")
	if level_02_story == null:
		finish()
		return

	expect(
		level_02_story.get("story_path") == LEVEL_02_STORY,
		"Level02 uses its configured story JSON"
	)
	var level_02_story_nodes: Array = level_02_story.get("story_nodes")
	expect(not level_02_story_nodes.is_empty(), "Level02 opening Story JSON is loaded")
	for _story_node in level_02_story_nodes:
		level_02_story.call("show_next_node")

	await process_frame
	expect(not paused, "Level02 opening Story completion resumes gameplay")
	expect(level_02.get_node_or_null("Story") == null, "Finished Level02 Story is removed")
	if level_02_player == null:
		finish()
		return

	var bear_king := level_02.get_node_or_null("Enemies/BearKing")
	expect(bear_king != null, "Level02 contains BearKing")
	if bear_king == null:
		finish()
		return

	observe_campaign_outcomes(level_02 as CampaignLevel, &"level_02")
	bear_king.call("die")
	await process_frame
	expect(
		has_campaign_outcome(&"level_02", &"completion"),
		"Level02 publishes campaign completion"
	)

	var level_02_victory_story := level_02.get_node_or_null("VictoryStory") as CanvasLayer
	expect(level_02_victory_story != null, "BearKing death starts the Level02 victory Story")
	expect(
		bear_king.process_mode == Node.PROCESS_MODE_ALWAYS,
		"BearKing death animation continues during the Level02 victory Story"
	)
	expect(paused, "Level02 victory Story pauses gameplay")
	expect(
		level_02_player.get("controls_enabled") == false,
		"Level02 victory Story disables player controls"
	)
	if level_02_victory_story == null:
		finish()
		return

	expect(
		level_02_victory_story.get("story_path") == LEVEL_02_VICTORY_STORY,
		"Level02 victory Story uses its configured story JSON"
	)
	var level_02_victory_story_nodes: Array = level_02_victory_story.get("story_nodes")
	expect(not level_02_victory_story_nodes.is_empty(), "Level02 victory Story JSON is loaded")
	for _story_node in level_02_victory_story_nodes:
		level_02_victory_story.call("show_next_node")

	await process_frame
	expect(not paused, "Level02 victory Story completion resumes gameplay")
	expect(
		level_02.get_node_or_null("VictoryStory") == null,
		"Finished Level02 victory Story is removed"
	)
	expect(
		level_02_player.get("controls_enabled") == true,
		"Level02 victory Story completion restores player controls"
	)

	level_02_player.set("health", 0)
	level_02_player.emit_signal("died")
	expect(has_campaign_outcome(&"level_02", &"defeat"), "Level02 publishes campaign defeat")
	expect(popup.visible, "Level02 player death shows the result popup")
	main.call("_on_retry_pressed")
	await process_frame

	var restarted_level_02 := main.get("level") as Node2D
	expect(
		restarted_level_02 != null and restarted_level_02.name == "Level02",
		"Level02 Retry restarts Level02"
	)
	expect(not is_instance_valid(level_02), "Level02 Retry frees the defeated level")
	expect(not popup.visible, "Level02 Retry hides the result popup")
	expect(not paused, "Level02 Retry skips the opening Story")
	if restarted_level_02 != null:
		expect(
			restarted_level_02.get_node_or_null("Story") == null,
			"Level02 Retry returns after its opening Story"
		)
		var restarted_level_02_player := restarted_level_02.get_node_or_null("Player")
		var restarted_level_02_hud := restarted_level_02.get_node_or_null("HUD")
		var restarted_level_02_camera := (
			restarted_level_02.get_node_or_null("Player/Camera2D") as Camera2D
		)
		expect(
			restarted_level_02_player != null
			and restarted_level_02_player.get("health") == full_player_health,
			"Level02 Retry restores full player health"
		)
		expect(
			restarted_level_02_player != null
			and restarted_level_02_player.get("controls_enabled") == true,
			"Level02 Retry enables player controls"
		)
		expect(restarted_level_02_hud != null and restarted_level_02_hud.visible, "Level02 Retry shows HUD")
		expect(
			restarted_level_02_camera != null and restarted_level_02_camera.is_current(),
			"Level02 Retry restores the Player camera"
		)

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


func observe_campaign_outcomes(level: CampaignLevel, observation_id: StringName) -> void:
	observed_campaign_outcomes[observation_id] = []
	level.campaign_outcome_reached.connect(
		_on_campaign_outcome_reached.bind(observation_id)
	)


func _on_campaign_outcome_reached(outcome: StringName, observation_id: StringName) -> void:
	observed_campaign_outcomes[observation_id].append(outcome)


func has_campaign_outcome(observation_id: StringName, outcome: StringName) -> bool:
	return observed_campaign_outcomes.get(observation_id, []).has(outcome)


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
