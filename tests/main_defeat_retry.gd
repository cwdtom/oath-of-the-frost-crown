extends SceneTree


const MAIN_SCENE := "res://main.tscn"
const RESULT_DEAD := "DEAD"
const FULL_PLAYER_HEALTH := 5
const CAMERA_PLAYER := &"player"
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

	defeated_level.campaign_outcome_reached.emit(&"defeat")

	var popup := main.get_node("GameResultPopup") as CanvasLayer
	var result_label := (
		main.get_node("GameResultPopup/Control/NinePatchRect/VBoxContainer/Label") as Label
	)
	expect(popup.visible, "%s defeat presents a result" % campaign_id)
	expect(result_label.text == RESULT_DEAD, "%s defeat presents DEAD" % campaign_id)
	expect(
		not defeated_level.is_campaign_control_available(),
		"%s defeat disables controls through the Level seam" % campaign_id
	)

	defeated_level.campaign_outcome_reached.emit(&"defeat")
	expect(popup.visible, "%s duplicate defeat keeps one result visible" % campaign_id)
	expect(
		main.call("get_active_campaign_level") == defeated_level,
		"%s duplicate defeat does not transition the campaign" % campaign_id
	)

	var defeated_instance_id := defeated_level.get_instance_id()
	var retry_button := (
		main.get_node(
			"GameResultPopup/Control/NinePatchRect/VBoxContainer/HBoxContainer/Retry"
		) as Button
	)
	retry_button.pressed.emit()
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
			get_displayed_health(replacement) == FULL_PLAYER_HEALTH,
			"%s retry displays full Player health" % campaign_id
		)
		expect(replacement.is_campaign_hud_visible(), "%s retry shows the HUD" % campaign_id)
		expect(
			replacement.get_campaign_camera_role() == CAMERA_PLAYER,
			"%s retry restores the Player Camera" % campaign_id
		)
	expect(not popup.visible, "%s retry hides the result" % campaign_id)
	expect(not paused, "%s retry leaves the scene tree unpaused" % campaign_id)

	await cleanup(main)


func get_displayed_health(level: CampaignLevel) -> int:
	var hud := level.get_node_or_null("HUD")
	if hud == null:
		return -1
	return int(hud.get("current_health"))


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
