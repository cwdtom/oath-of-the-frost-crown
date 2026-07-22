extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const LEVEL_SPECS := [
	{
		"scene": "res://levels/level_00.tscn",
		"campaign_id": &"level_00",
		"outcomes": [],
		"has_music": false,
		"has_opening_story": true,
	},
	{
		"scene": "res://levels/level_01.tscn",
		"campaign_id": &"level_01",
		"outcomes": [&"defeat", &"completion"],
		"has_music": true,
		"has_opening_story": true,
		"act_announcement_text": "第一幕\n王座之命",
	},
	{
		"scene": "res://levels/level_02.tscn",
		"campaign_id": &"level_02",
		"outcomes": [&"defeat", &"completion"],
		"has_music": true,
		"has_opening_story": true,
		"act_announcement_text": "第二幕\n林中疑影",
	},
	{
		"scene": "res://levels/level_03.tscn",
		"campaign_id": &"level_03",
		"outcomes": [&"defeat", &"completion"],
		"has_music": true,
		"has_opening_story": true,
		"act_announcement_text": "第三幕\n白鹿悲歌",
	},
	{
		"scene": "res://levels/level_04.tscn",
		"campaign_id": &"level_04",
		"outcomes": [&"defeat", &"completion"],
		"has_music": true,
		"has_opening_story": true,
		"opening_story_path": "res://levels/level_04_story.json",
		"act_announcement_text": "第四幕\n寒冠之誓",
	},
]
const MAX_STORY_ADVANCE_INPUTS := 64

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	for spec in LEVEL_SPECS:
		verify_level_contract(spec)
	await verify_act_announcement_start_contract()
	await verify_story_phase_contract()
	await verify_lifecycle_contract()

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func verify_level_contract(spec: Dictionary) -> void:
	var scene_path := str(spec["scene"])
	var scene := load(scene_path) as PackedScene
	fixture.expect(scene != null, "%s can be loaded" % scene_path)
	if scene == null:
		return

	var level := scene.instantiate() as CampaignLevel
	fixture.expect(level != null, "%s implements CampaignLevel" % scene_path)
	if level == null:
		return
	fixture.expect(
		level.get_campaign_id() == spec["campaign_id"],
		"%s has campaign identity %s" % [scene_path, spec["campaign_id"]]
	)
	fixture.expect(
		level.get_supported_campaign_outcomes() == spec["outcomes"],
		"%s declares only its supported outcomes" % scene_path
	)
	fixture.expect(
		level.has_campaign_music() == spec["has_music"],
		"%s declares its campaign music capability" % scene_path
	)
	if spec.has("act_announcement_text"):
		fixture.expect(
			level.get_campaign_act_announcement_text()
			== spec["act_announcement_text"],
			"%s declares its configured Act Announcement" % scene_path
		)
	if spec.has("opening_story_path"):
		var opening_story := level.get_node_or_null("Story")
		fixture.expect(
			opening_story != null
			and opening_story.get("story_path") == spec["opening_story_path"],
			"%s uses its configured Opening Story" % scene_path
		)
	level.free()


func verify_act_announcement_start_contract() -> void:
	for spec in LEVEL_SPECS:
		if not spec.has("act_announcement_text"):
			continue

		var scene_path := str(spec["scene"])
		var level := (load(scene_path) as PackedScene).instantiate() as CampaignLevel
		var observed := {"story_phase_finished": false}
		level.campaign_story_phase_finished.connect(
			func() -> void: observed["story_phase_finished"] = true
		)
		level.prepare_for_campaign(true)
		fixture.add_node(level)
		fixture.set_current_scene(level)
		await fixture.process_frames(1)

		fixture.expect(
			level.is_campaign_act_announcement_active(),
			"%s starts its Act Announcement" % scene_path
		)
		fixture.expect(
			not level.is_campaign_story_phase_active(),
			"%s does not start its Opening Story during the Act Announcement"
			% scene_path
		)
		fixture.expect(
			not level.is_campaign_control_available(),
			"%s keeps controls unavailable during the Act Announcement" % scene_path
		)
		fixture.expect(
			not level.is_campaign_hud_visible(),
			"%s hides the HUD during the Act Announcement" % scene_path
		)
		fixture.expect(paused, "%s pauses for its Act Announcement" % scene_path)

		for _input_index in MAX_STORY_ADVANCE_INPUTS:
			var input := InputEventKey.new()
			input.keycode = KEY_ENTER
			input.pressed = true
			Input.parse_input_event(input)
			await fixture.process_frames(1)

		fixture.expect(
			level.is_campaign_act_announcement_active(),
			"%s cannot skip its Act Announcement through input" % scene_path
		)
		fixture.expect(
			not observed["story_phase_finished"],
			"%s ignores Story input during its Act Announcement" % scene_path
		)
		fixture.expect(
			not level.has_campaign_music_started(),
			"%s keeps campaign music stopped during its Act Announcement"
			% scene_path
		)

		await fixture.wait_seconds(3.1)
		fixture.expect(
			not level.is_campaign_act_announcement_active(),
			"%s finishes its Act Announcement after three seconds" % scene_path
		)
		fixture.expect(
			level.is_campaign_story_phase_active(),
			"%s starts its Opening Story after the Act Announcement" % scene_path
		)
		fixture.expect(
			level.has_campaign_music_started(),
			"%s starts campaign music with its Opening Story" % scene_path
		)
		fixture.expect(
			not observed["story_phase_finished"],
			"%s retains its Opening Story after ignored announcement input"
			% scene_path
		)
		fixture.expect(paused, "%s remains paused for its Opening Story" % scene_path)

		fixture.set_current_scene(null)
		root.remove_child(level)
		fixture.set_paused(false)
		await fixture.process_frames(1)


func verify_story_phase_contract() -> void:
	for spec in LEVEL_SPECS:
		var scene_path := str(spec["scene"])
		var has_gameplay := not (spec["outcomes"] as Array).is_empty()
		var has_opening_story := bool(spec["has_opening_story"])
		var level := (load(scene_path) as PackedScene).instantiate() as CampaignLevel
		fixture.expect(level != null, "%s implements the Story-phase seam" % scene_path)
		if level == null:
			continue

		var observed := {"story_phase_finished": false}
		level.campaign_story_phase_finished.connect(
			func() -> void: observed["story_phase_finished"] = true
		)
		level.prepare_for_campaign(true)
		fixture.add_node(level)
		fixture.set_current_scene(level)
		await fixture.process_frames(1)
		if spec.has("act_announcement_text"):
			await fixture.wait_seconds(3.1)
		if has_gameplay and has_opening_story:
			fixture.expect(
				level.is_campaign_story_phase_active(),
				"%s starts its opening Story phase" % scene_path
			)
			fixture.expect(
				not level.is_campaign_control_available(),
				"%s opening Story keeps controls unavailable" % scene_path
			)
			fixture.expect(
				level.get_campaign_camera_role() == CampaignLevel.CAMERA_OPENING_STORY,
				"%s opening Story uses the Story Camera" % scene_path
			)

		if has_opening_story:
			for _input_index in MAX_STORY_ADVANCE_INPUTS:
				if observed["story_phase_finished"]:
					break
				var input := InputEventKey.new()
				input.keycode = KEY_ENTER
				input.pressed = true
				Input.parse_input_event(input)
				await fixture.process_frames(1)

			fixture.expect(
				observed["story_phase_finished"],
				"%s finishes its Story phase through input" % scene_path
			)
		else:
			fixture.expect(
				not level.is_campaign_story_phase_active(),
				"%s starts without an Opening Story" % scene_path
			)
		if has_gameplay and has_opening_story:
			fixture.expect(
				not level.is_campaign_story_phase_active(),
				"%s leaves its opening Story phase" % scene_path
			)
			fixture.expect(
				level.is_campaign_control_available(),
				"%s enables controls after its opening Story" % scene_path
			)
			fixture.expect(
				level.get_campaign_camera_role() == CampaignLevel.CAMERA_PLAYER,
				"%s restores the Player Camera after its opening Story" % scene_path
			)
		elif has_gameplay:
			fixture.expect(
				level.is_campaign_control_available(),
				"%s starts with controls available" % scene_path
			)
			fixture.expect(
				level.get_campaign_camera_role() == CampaignLevel.CAMERA_PLAYER,
				"%s starts with the Player Camera" % scene_path
			)
		fixture.set_current_scene(null)
		root.remove_child(level)
		fixture.set_paused(false)
		await fixture.process_frames(1)


func verify_lifecycle_contract() -> void:
	for spec in LEVEL_SPECS:
		var scene_path := str(spec["scene"])
		var has_gameplay := not (spec["outcomes"] as Array).is_empty()
		var level := (load(scene_path) as PackedScene).instantiate() as CampaignLevel
		fixture.expect(level != null, "%s implements the lifecycle seam" % scene_path)
		if level == null:
			continue

		level.prepare_for_campaign(false)
		fixture.add_node(level)
		fixture.set_current_scene(level)
		await fixture.process_frames(1)
		fixture.expect(
			not level.is_campaign_story_phase_active(),
			"%s can start without replaying its Story phase" % scene_path
		)
		fixture.expect(
			not level.is_campaign_act_announcement_active(),
			"%s can start without replaying its Act Announcement" % scene_path
		)
		if has_gameplay:
			fixture.expect(
				level.is_campaign_control_available(),
				"%s starts with controls available" % scene_path
			)
			fixture.expect(
				level.is_campaign_health_full(),
				"%s starts at full campaign health" % scene_path
			)
			fixture.expect(
				level.get_campaign_camera_role() == CampaignLevel.CAMERA_PLAYER,
				"%s starts with the Player Camera" % scene_path
			)
		level.set_campaign_controls_enabled(false)
		if has_gameplay:
			fixture.expect(
				not level.is_campaign_control_available(),
				"%s can disable campaign controls" % scene_path
			)
		level.set_campaign_controls_enabled(true)
		if has_gameplay:
			fixture.expect(
				level.is_campaign_control_available(),
				"%s can enable campaign controls" % scene_path
			)
		var music_position_before_suspension := level.get_campaign_music_playback_position()
		level.suspend_from_campaign()
		fixture.expect(
			not level.is_campaign_music_playing(),
			"%s stops campaign music when suspended" % scene_path
		)
		root.remove_child(level)
		root.add_child(level)
		level.restore_to_campaign()
		await fixture.process_frames(1)
		if has_gameplay:
			fixture.expect(
				level.is_campaign_control_available(),
				"%s restores with controls available" % scene_path
			)
			fixture.expect(
				level.is_campaign_health_full(),
				"%s restores with full campaign health" % scene_path
			)
			fixture.expect(
				level.get_campaign_camera_role() == CampaignLevel.CAMERA_PLAYER,
				"%s restores the Player Camera" % scene_path
			)
		if bool(spec["has_music"]):
			fixture.expect(
				level.get_campaign_music_playback_position()
				>= music_position_before_suspension,
				"%s retains campaign music position across restoration" % scene_path
			)
			if DisplayServer.get_name() != "headless":
				fixture.expect(
					level.is_campaign_music_playing(),
					"%s resumes campaign music after restoration" % scene_path
				)

		fixture.set_current_scene(null)
		root.remove_child(level)
		fixture.set_paused(false)
		await fixture.process_frames(1)
