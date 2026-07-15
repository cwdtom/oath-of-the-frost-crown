extends SceneTree


const MAIN_SCENE := "res://main.tscn"
const RESULT_DEAD := "DEAD"
const CAMERA_PLAYER := &"player"
const HURT_IMMUNITY_WAIT_SECONDS := 0.95
const LEVEL_SPECS := [
	{
		"campaign_id": &"level_01",
		"start_method": &"start_level_01",
	},
	{
		"campaign_id": &"level_02",
		"start_method": &"start_level_02",
	},
]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for spec in LEVEL_SPECS:
		await verify_defeat_and_retry(spec)

	finish()


func verify_defeat_and_retry(spec: Dictionary) -> void:
	var main := instantiate_main()
	if main == null:
		return

	await process_frame
	main.call(str(spec["start_method"]), false)
	await process_frame

	var defeated_level := main.call("get_active_campaign_level") as CampaignLevel
	var campaign_id := spec["campaign_id"] as StringName
	expect(defeated_level != null, "%s starts a campaign Level" % campaign_id)
	if defeated_level == null:
		await cleanup(main)
		return

	expect(defeated_level.get_campaign_id() == campaign_id, "%s is active" % campaign_id)
	expect(
		defeated_level.is_campaign_control_available(),
		"%s starts with controls available" % campaign_id
	)

	var player := find_player_event_source(defeated_level)
	expect(player != null, "%s exposes its production Player damage seam" % campaign_id)
	if player == null:
		await cleanup(main)
		return

	var defeat_outcomes := [0]
	defeated_level.campaign_outcome_reached.connect(
		func(outcome: StringName) -> void:
			if outcome == CampaignLevel.OUTCOME_DEFEAT:
				defeat_outcomes[0] += 1
	)
	for expected_health in [4, 3, 2, 1, 0]:
		player.call("take_damage", 1, Vector2.ZERO)
		expect(
			player.call("get_current_health") == expected_health,
			"%s Player reaches exactly %d health" % [campaign_id, expected_health]
		)
		if expected_health == 4:
			expect(
				not defeated_level.is_campaign_health_full(),
				"%s accepted damage updates Player and HUD together" % campaign_id
			)
		if expected_health > 0:
			await create_timer(HURT_IMMUNITY_WAIT_SECONDS).timeout

	var result_interface := main.get_node("GameResultPopup")
	expect(
		bool(result_interface.call("is_result_visible")),
		"%s defeat presents a result" % campaign_id
	)
	expect(
		str(result_interface.call("get_result_text")) == RESULT_DEAD,
		"%s defeat presents DEAD" % campaign_id
	)
	expect(
		not defeated_level.is_campaign_control_available(),
		"%s defeat disables controls through the Level seam" % campaign_id
	)
	expect(defeat_outcomes[0] == 1, "%s Player depletion emits one campaign defeat" % campaign_id)

	player.call("take_damage", 1, Vector2.ZERO)
	expect(
		bool(result_interface.call("is_result_visible")),
		"%s damage after depletion keeps one result visible" % campaign_id
	)
	expect(
		main.call("get_active_campaign_level") == defeated_level,
		"%s damage after depletion does not transition the campaign" % campaign_id
	)
	expect(defeat_outcomes[0] == 1, "%s damage after depletion cannot repeat campaign defeat" % campaign_id)

	var defeated_instance_id := defeated_level.get_instance_id()
	result_interface.emit_signal("retry_requested")
	await process_frame

	var replacement := main.call("get_active_campaign_level") as CampaignLevel
	expect(replacement != null, "%s retry creates a replacement Level" % campaign_id)
	expect(not is_instance_valid(defeated_level), "%s retry disposes the defeated Level" % campaign_id)
	if replacement != null:
		expect(
			replacement.get_instance_id() != defeated_instance_id,
			"%s retry uses a fresh Level instance" % campaign_id
		)
		expect(replacement.get_campaign_id() == campaign_id, "%s retry keeps campaign identity" % campaign_id)
		expect(
			not replacement.is_campaign_story_phase_active(),
			"%s retry skips its opening Story" % campaign_id
		)
		expect(
			replacement.is_campaign_control_available(),
			"%s retry enables controls" % campaign_id
		)
		expect(
			replacement.is_campaign_health_full(),
			"%s retry restores full campaign health" % campaign_id
		)
		expect(replacement.is_campaign_hud_visible(), "%s retry shows the HUD" % campaign_id)
		expect(
			replacement.get_campaign_camera_role() == CAMERA_PLAYER,
			"%s retry restores the Player Camera" % campaign_id
		)
	expect(
		not bool(result_interface.call("is_result_visible")),
		"%s retry hides the result" % campaign_id
	)
	expect(not paused, "%s retry leaves the scene tree unpaused" % campaign_id)

	await cleanup(main)


func find_player_event_source(level: CampaignLevel) -> Node:
	for node in level.find_children("*", "", true, false):
		if (
			node is DamageableActor
			and node.has_signal("health_changed")
			and node.has_signal("died")
		):
			return node
	return null


func instantiate_main() -> Node:
	var scene := load(MAIN_SCENE) as PackedScene
	expect(scene != null, "Main scene can be loaded")
	if scene == null:
		return null

	var main := scene.instantiate()
	root.add_child(main)
	current_scene = main
	return main


func cleanup(main: Node) -> void:
	current_scene = null
	if is_instance_valid(main):
		main.free()
	paused = false
	await process_frame


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("Main defeat and retry test passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
