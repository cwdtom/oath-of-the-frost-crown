extends SceneTree


const LEVEL_SPECS := [
	{
		"scene": "res://levels/level_00.tscn",
		"campaign_id": &"level_00",
		"outcomes": [],
		"has_music": false,
	},
	{
		"scene": "res://levels/level_01.tscn",
		"campaign_id": &"level_01",
		"outcomes": [&"defeat", &"completion"],
		"has_music": true,
	},
	{
		"scene": "res://levels/level_02.tscn",
		"campaign_id": &"level_02",
		"outcomes": [&"defeat", &"completion"],
		"has_music": true,
	},
]
const MAX_STORY_ADVANCE_INPUTS := 64

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for spec in LEVEL_SPECS:
		verify_level_contract(spec)
	await verify_story_phase_contract()
	await verify_lifecycle_contract()

	finish()


func verify_level_contract(spec: Dictionary) -> void:
	var scene_path := str(spec["scene"])
	var scene := load(scene_path) as PackedScene
	expect(scene != null, "%s can be loaded" % scene_path)
	if scene == null:
		return

	var level := scene.instantiate() as CampaignLevel
	expect(level != null, "%s implements CampaignLevel" % scene_path)
	if level == null:
		return
	expect(
		level.get_campaign_id() == spec["campaign_id"],
		"%s has campaign identity %s" % [scene_path, spec["campaign_id"]]
	)
	expect(
		level.get_supported_campaign_outcomes() == spec["outcomes"],
		"%s declares only its supported outcomes" % scene_path
	)
	expect(
		level.has_campaign_music() == spec["has_music"],
		"%s declares its campaign music capability" % scene_path
	)
	level.free()


func verify_story_phase_contract() -> void:
	for spec in LEVEL_SPECS:
		var scene_path := str(spec["scene"])
		var level := (load(scene_path) as PackedScene).instantiate() as CampaignLevel
		expect(level != null, "%s implements the Story-phase seam" % scene_path)
		if level == null:
			continue

		var observed := {"story_phase_finished": false}
		level.campaign_story_phase_finished.connect(
			func() -> void: observed["story_phase_finished"] = true
		)
		level.prepare_for_campaign(true)
		root.add_child(level)
		current_scene = level
		await process_frame

		for _input_index in MAX_STORY_ADVANCE_INPUTS:
			if observed["story_phase_finished"]:
				break
			var input := InputEventKey.new()
			input.keycode = KEY_ENTER
			input.pressed = true
			Input.parse_input_event(input)
			await process_frame

		expect(
			observed["story_phase_finished"],
			"%s finishes its Story phase through input" % scene_path
		)
		current_scene = null
		level.free()
		paused = false
		await process_frame


func verify_lifecycle_contract() -> void:
	for spec in LEVEL_SPECS:
		var scene_path := str(spec["scene"])
		var level := (load(scene_path) as PackedScene).instantiate() as CampaignLevel
		expect(level != null, "%s implements the lifecycle seam" % scene_path)
		if level == null:
			continue

		level.prepare_for_campaign(false)
		root.add_child(level)
		current_scene = level
		await process_frame
		expect(
			not paused,
			"%s can start without replaying its Story phase" % scene_path
		)
		if (spec["outcomes"] as Array).has(CampaignLevel.OUTCOME_DEFEAT):
			expect(level.is_campaign_health_full(), "%s starts at full campaign health" % scene_path)
		level.set_campaign_controls_enabled(false)
		level.set_campaign_controls_enabled(true)
		level.suspend_from_campaign()
		root.remove_child(level)
		root.add_child(level)
		level.restore_to_campaign()
		await process_frame

		current_scene = null
		level.free()
		paused = false
		await process_frame


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("Campaign Level contract test passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
