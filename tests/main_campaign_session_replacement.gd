extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const MAIN_SCENE := preload("res://main.tscn")
const LEVEL_01_SCENE := preload("res://levels/level_01.tscn")
const LEVEL_02_SCENE := preload("res://levels/level_02.tscn")
const MAX_STORY_ADVANCE_INPUTS := 64

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	await verify_active_session_replacement()
	await verify_prologue_session_replacement()
	await verify_result_and_retry_session_replacement()
	await verify_victory_story_session_replacement()

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func verify_active_session_replacement() -> void:
	var main := instantiate_main()
	if main == null:
		return

	await fixture.process_frames(1)
	main.call("replace_campaign_session", LEVEL_01_SCENE, false)
	await fixture.process_frames(1)

	var first_level := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(first_level != null, "Session replacement starts a Campaign Level")
	if first_level == null:
		await retire_main(main)
		return
	fixture.add_node(first_level)
	fixture.expect(first_level.get_campaign_id() == &"level_01", "Session replacement starts Level01")
	fixture.expect(
		not first_level.is_campaign_story_phase_active(),
		"Session replacement honors the opening-Story choice"
	)

	main.call("replace_campaign_session", LEVEL_02_SCENE, false)
	await fixture.process_frames(1)

	var replacement := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(replacement != null, "A second replacement starts a Campaign Level")
	fixture.expect(not is_instance_valid(first_level), "Replacement disposes the previous active Level")
	if replacement != null:
		fixture.add_node(replacement)
		fixture.expect(replacement.get_campaign_id() == &"level_02", "Replacement starts the requested Level")
		fixture.expect(
			not replacement.is_campaign_story_phase_active(),
			"Replacement keeps the requested opening-Story choice"
		)
		fixture.expect(replacement.is_campaign_control_available(), "Replacement Level is ready for gameplay")
	fixture.expect(not paused, "Session replacement leaves the SceneTree unpaused")
	await retire_main(main)


func verify_prologue_session_replacement() -> void:
	var main := instantiate_main()
	if main == null:
		return

	await fixture.process_frames(1)
	main.call("replace_campaign_session", LEVEL_01_SCENE, true)
	await fixture.process_frames(1)

	var suspended_level_01 := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(suspended_level_01 != null, "Complete Level01 replacement starts a Campaign Level")
	if suspended_level_01 == null:
		await retire_main(main)
		return
	fixture.add_node(suspended_level_01)
	await fixture.wait_for_act_announcement(suspended_level_01)
	fixture.expect(
		suspended_level_01.is_campaign_story_phase_active(),
		"Complete Level01 replacement starts its opening Story"
	)

	await advance_story_phase(suspended_level_01)
	var abandoned_prologue := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		abandoned_prologue != null and abandoned_prologue.get_campaign_id() == &"level_00",
		"Complete Level01 replacement enters the Level00 prologue"
	)
	if abandoned_prologue == null or abandoned_prologue == suspended_level_01:
		await retire_main(main)
		return
	fixture.add_node(abandoned_prologue)

	main.call("replace_campaign_session", LEVEL_02_SCENE, false)
	await fixture.process_frames(1)
	fixture.expect(not is_instance_valid(abandoned_prologue), "Replacement disposes active Level00")
	fixture.expect(not is_instance_valid(suspended_level_01), "Replacement disposes suspended Level01")

	main.call("replace_campaign_session", LEVEL_01_SCENE, true)
	await fixture.process_frames(1)
	var replacement_level_01 := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(replacement_level_01 != null, "Replacement can re-enter complete Level01")
	if replacement_level_01 == null:
		await retire_main(main)
		return
	fixture.add_node(replacement_level_01)

	await advance_story_phase(replacement_level_01)
	var replacement_prologue := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		replacement_prologue != null and replacement_prologue.get_campaign_id() == &"level_00",
		"Replacement Level01 can enter a fresh Level00 prologue"
	)
	if replacement_prologue == null or replacement_prologue == replacement_level_01:
		await retire_main(main)
		return
	fixture.add_node(replacement_prologue)

	await advance_story_phase(replacement_prologue)
	fixture.expect(
		main.call("get_active_campaign_level") == replacement_level_01,
		"Fresh Level00 completion restores the replacement Level01"
	)
	fixture.expect(
		replacement_level_01.is_inside_tree(),
		"Replacement Level01 returns to the active SceneTree"
	)
	fixture.expect(
		not replacement_level_01.is_campaign_story_phase_active(),
		"Restored replacement Level01 has completed its opening Story"
	)
	fixture.expect(not paused, "Restored replacement Level01 unpauses the campaign")
	fixture.expect(
		replacement_level_01.is_campaign_control_available(),
		"Restored replacement Level01 enables gameplay controls"
	)
	fixture.expect(
		replacement_level_01.is_campaign_hud_visible(),
		"Restored replacement Level01 presents its HUD"
	)
	await retire_main(main)


func verify_result_and_retry_session_replacement() -> void:
	var main := instantiate_main()
	if main == null:
		return

	await fixture.process_frames(1)
	main.call("replace_campaign_session", LEVEL_01_SCENE, false)
	await fixture.process_frames(1)
	var abandoned_level := main.call("get_active_campaign_level") as CampaignLevel
	if abandoned_level == null:
		fixture.expect(false, "Result replacement starts Level01")
		await retire_main(main)
		return
	fixture.add_node(abandoned_level)

	abandoned_level.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_DEFEAT)
	fixture.expect(
		bool(main.call("is_campaign_result_visible")),
		"Abandoned session can present a defeat result"
	)

	main.call("replace_campaign_session", LEVEL_02_SCENE, false)
	await fixture.process_frames(1)
	var replacement := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		not bool(main.call("is_campaign_result_visible")),
		"Session replacement dismisses stale result UI"
	)
	if replacement == null:
		fixture.expect(false, "Result replacement starts Level02")
		await retire_main(main)
		return
	fixture.add_node(replacement)

	replacement.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_DEFEAT)
	main.call("retry_campaign")
	await fixture.process_frames(1)
	var retry := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(retry != null and retry != replacement, "Retry creates a fresh replacement session")
	fixture.expect(not is_instance_valid(replacement), "Retry disposes the replaced defeat session")
	if retry != null:
		fixture.add_node(retry)
		fixture.expect(retry.get_campaign_id() == &"level_02", "Retry follows the replacement session")
	fixture.expect(not paused, "Retry after replacement leaves the SceneTree unpaused")
	await retire_main(main)


func verify_victory_story_session_replacement() -> void:
	var main := instantiate_main()
	if main == null:
		return

	await fixture.process_frames(1)
	main.call("replace_campaign_session", LEVEL_01_SCENE, false)
	await fixture.process_frames(1)
	var abandoned_level := main.call("get_active_campaign_level") as CampaignLevel
	if abandoned_level == null:
		fixture.expect(false, "Victory replacement starts Level01")
		await retire_main(main)
		return
	fixture.add_node(abandoned_level)

	abandoned_level.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)
	fixture.expect(
		abandoned_level.is_campaign_story_phase_active(),
		"Abandoned session enters its victory Story"
	)

	main.call("replace_campaign_session", LEVEL_01_SCENE, false)
	var replacement := main.call("get_active_campaign_level") as CampaignLevel
	if replacement == null:
		fixture.expect(false, "Victory Story replacement starts a fresh Level01")
		await retire_main(main)
		return
	fixture.add_node(replacement)

	abandoned_level.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)
	fixture.expect(
		main.call("get_active_campaign_level") == replacement,
		"Delayed abandoned outcome cannot transition the replacement session"
	)

	replacement.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_COMPLETION)
	fixture.expect(
		replacement.is_campaign_story_phase_active(),
		"Replacement Level can enter its own victory Story"
	)

	abandoned_level.campaign_story_phase_finished.emit()
	replacement.campaign_outcome_reached.emit(CampaignLevel.OUTCOME_DEFEAT)
	fixture.expect(
		not bool(main.call("is_campaign_result_visible")),
		"Delayed abandoned Story cannot expose result UI during replacement victory"
	)

	await advance_story_phase(replacement)
	var next_level := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(
		next_level != null and next_level.get_campaign_id() == &"level_02",
		"Replacement victory Story completes through normal campaign progression"
	)
	if next_level != null:
		fixture.add_node(next_level)
	await retire_main(main)


func advance_story_phase(level: CampaignLevel) -> void:
	await fixture.wait_for_act_announcement(level)
	var story_phase_finished := [false]
	level.campaign_story_phase_finished.connect(func() -> void: story_phase_finished[0] = true)
	for _input_index in MAX_STORY_ADVANCE_INPUTS:
		if story_phase_finished[0]:
			break
		var story_input := InputEventKey.new()
		story_input.keycode = KEY_ENTER
		story_input.pressed = true
		Input.parse_input_event(story_input)
		await fixture.process_frames(1)
	fixture.expect(story_phase_finished[0], "Campaign Story phase completes through input")


func instantiate_main() -> Node:
	var main := fixture.instantiate_scene(MAIN_SCENE)
	fixture.set_current_scene(main)
	return main


func retire_main(main: Node) -> void:
	fixture.set_current_scene(null)
	if is_instance_valid(main) and main.is_inside_tree():
		root.remove_child(main)
	fixture.set_paused(false)
	await fixture.process_frames(1)
