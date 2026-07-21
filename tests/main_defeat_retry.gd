extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const MAIN_SCENE := "res://main.tscn"
const RESULT_DEAD := "DEAD"
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
	{
		"campaign_id": &"level_04",
		"start_method": &"start_level_04",
		"has_player_shield": true,
	},
]

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	for spec in LEVEL_SPECS:
		await verify_defeat_and_retry(spec)

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func verify_defeat_and_retry(spec: Dictionary) -> void:
	var main := instantiate_main()
	if main == null:
		return

	await fixture.process_frames(1)
	main.call(str(spec["start_method"]), false)
	await fixture.process_frames(1)

	var defeated_level := main.call("get_active_campaign_level") as CampaignLevel
	var campaign_id := spec["campaign_id"] as StringName
	fixture.expect(defeated_level != null, "%s starts a campaign Level" % campaign_id)
	if defeated_level == null:
		await retire_main(main)
		return
	fixture.add_node(defeated_level)

	fixture.expect(defeated_level.get_campaign_id() == campaign_id, "%s is active" % campaign_id)
	fixture.expect(
		defeated_level.is_campaign_control_available(),
		"%s starts with controls available" % campaign_id
	)
	fixture.expect(
		defeated_level.is_campaign_health_full(),
		"%s entry restores Player and HUD health together" % campaign_id
	)

	var player := find_player_event_source(defeated_level)
	fixture.expect(player != null, "%s exposes its production Player damage seam" % campaign_id)
	if player == null:
		await retire_main(main)
		return

	var defeat_outcomes := [0]
	defeated_level.campaign_outcome_reached.connect(
		func(outcome: StringName) -> void:
			if outcome == CampaignLevel.OUTCOME_DEFEAT:
				defeat_outcomes[0] += 1
	)
	if bool(spec.get("has_player_shield", false)):
		await player.call("take_damage", player.call("get_maximum_health"), Vector2.ZERO)
		player.call("take_damage", player.call("get_maximum_health"), Vector2.ZERO)
	else:
		player.call("take_damage", player.call("get_maximum_health"), Vector2.ZERO)
	fixture.expect(player.call("get_current_health") == 0, "%s Player depletes through its actor seam" % campaign_id)
	fixture.expect(
		not defeated_level.is_campaign_health_full(),
		"%s depletion updates Player and HUD together" % campaign_id
	)

	var result_interface := main.get_node("GameResultPopup")
	fixture.expect(
		bool(result_interface.call("is_result_visible")),
		"%s defeat presents a result" % campaign_id
	)
	fixture.expect(
		str(result_interface.call("get_result_text")) == RESULT_DEAD,
		"%s defeat presents DEAD" % campaign_id
	)
	fixture.expect(
		not defeated_level.is_campaign_control_available(),
		"%s defeat disables controls through the Level seam" % campaign_id
	)
	fixture.expect(defeat_outcomes[0] == 1, "%s Player depletion emits one campaign defeat" % campaign_id)

	player.call("take_damage", 1, Vector2.ZERO)
	fixture.expect(
		bool(result_interface.call("is_result_visible")),
		"%s damage after depletion keeps one result visible" % campaign_id
	)
	fixture.expect(
		main.call("get_active_campaign_level") == defeated_level,
		"%s damage after depletion does not transition the campaign" % campaign_id
	)
	fixture.expect(defeat_outcomes[0] == 1, "%s damage after depletion cannot repeat campaign defeat" % campaign_id)

	var defeated_instance_id := defeated_level.get_instance_id()
	result_interface.emit_signal("retry_requested")
	await fixture.process_frames(1)

	var replacement := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(replacement != null, "%s retry creates a replacement Level" % campaign_id)
	fixture.expect(not is_instance_valid(defeated_level), "%s retry disposes the defeated Level" % campaign_id)
	if replacement != null:
		fixture.add_node(replacement)
		fixture.expect(
			replacement.get_instance_id() != defeated_instance_id,
			"%s retry uses a fresh Level instance" % campaign_id
		)
		fixture.expect(replacement.get_campaign_id() == campaign_id, "%s retry keeps campaign identity" % campaign_id)
		fixture.expect(
			not replacement.is_campaign_story_phase_active(),
			"%s retry skips its opening Story" % campaign_id
		)
		fixture.expect(
			replacement.is_campaign_control_available(),
			"%s retry enables controls" % campaign_id
		)
		fixture.expect(
			replacement.is_campaign_health_full(),
			"%s retry restores full campaign health" % campaign_id
		)
		fixture.expect(replacement.is_campaign_hud_visible(), "%s retry shows the HUD" % campaign_id)
		fixture.expect(
			replacement.get_campaign_camera_role() == CAMERA_PLAYER,
			"%s retry restores the Player Camera" % campaign_id
		)
	fixture.expect(
		not bool(result_interface.call("is_result_visible")),
		"%s retry hides the result" % campaign_id
	)
	fixture.expect(not paused, "%s retry leaves the scene tree unpaused" % campaign_id)

	await retire_main(main)


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
	fixture.expect(scene != null, "Main scene can be loaded")
	if scene == null:
		return null

	var main := fixture.instantiate_scene(scene)
	fixture.set_current_scene(main)
	return main


func retire_main(main: Node) -> void:
	fixture.set_current_scene(null)
	if is_instance_valid(main) and main.is_inside_tree():
		root.remove_child(main)
	fixture.set_paused(false)
	await fixture.process_frames(1)
