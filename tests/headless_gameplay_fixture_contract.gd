extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	test_scene_ownership_and_current_scene_restoration()
	await test_frame_advancement_and_bounded_wait()
	test_scoped_setting_and_pause_restoration()
	await test_spawned_node_and_physics_resource_ownership()
	test_assertion_failure_completion()
	test_expected_early_completion()
	test_setup_failure_completion()
	finish()


func test_scene_ownership_and_current_scene_restoration() -> void:
	var previous_scene := Node.new()
	root.add_child(previous_scene)
	current_scene = previous_scene

	var fixture := HeadlessGameplayFixture.new(self)
	var scene := PackedScene.new()
	var scene_root := Node.new()
	scene.pack(scene_root)
	scene_root.free()

	var instance := fixture.instantiate_scene(scene)
	fixture.set_current_scene(instance)
	expect(instance != null and instance.is_inside_tree(), "Fixture instantiates owned scenes in the tree")
	expect(current_scene == instance, "Fixture manages the current scene")

	var exit_code := fixture.complete(false)
	expect(exit_code == 0, "Passing fixture completion returns a zero exit code")
	expect(not is_instance_valid(instance), "Fixture completion frees its owned scene")
	expect(current_scene == previous_scene, "Fixture completion restores the previous current scene")

	current_scene = null
	previous_scene.free()


func test_frame_advancement_and_bounded_wait() -> void:
	var fixture := HeadlessGameplayFixture.new(self)
	var process_count := [0]
	var physics_count := [0]
	var count_process_frame := func() -> void: process_count[0] += 1
	var count_physics_frame := func() -> void: physics_count[0] += 1
	process_frame.connect(count_process_frame)
	physics_frame.connect(count_physics_frame)

	await fixture.process_frames(2)
	await fixture.physics_frames(3)
	var process_count_before_wait: int = process_count[0]
	await fixture.wait_seconds(0.01)

	expect(process_count[0] >= 2, "Fixture advances the requested process frames")
	expect(physics_count[0] >= 3, "Fixture advances the requested physics frames")
	var waited_process_frames: int = process_count[0] - process_count_before_wait
	expect(waited_process_frames >= 1, "Fixture timer waits yield process advancement")
	expect(waited_process_frames <= 10, "Fixture timer waits complete within a bounded frame count")
	process_frame.disconnect(count_process_frame)
	physics_frame.disconnect(count_physics_frame)
	fixture.complete(false)


func test_scoped_setting_and_pause_restoration() -> void:
	const SETTING := "testing/headless_gameplay_fixture_contract"
	var setting_existed := ProjectSettings.has_setting(SETTING)
	var original_value: Variant = ProjectSettings.get_setting(SETTING) if setting_existed else null
	var previous_paused := paused
	paused = true

	var fixture := HeadlessGameplayFixture.new(self)
	fixture.set_project_setting(SETTING, "outer")
	fixture.set_project_setting(SETTING, "inner")
	fixture.set_paused(false)
	expect(ProjectSettings.get_setting(SETTING) == "inner", "Stacked setting changes expose the newest value")
	expect(not paused, "Fixture manages scene-tree pause state")

	fixture.complete(false)
	expect(paused, "Fixture restores the pause state captured at setup")
	if setting_existed:
		expect(
			ProjectSettings.get_setting(SETTING) == original_value,
			"Fixture restores the exact previous project-setting value"
		)
	else:
		expect(
			not ProjectSettings.has_setting(SETTING),
			"Fixture removes a scoped project setting that was previously absent"
		)
	paused = previous_paused


func test_spawned_node_and_physics_resource_ownership() -> void:
	var fixture := HeadlessGameplayFixture.new(self)
	var spawned_node := Node2D.new()
	fixture.add_node(spawned_node)
	await fixture.process_frames(1)
	var active_objects_before := int(
		Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)
	)
	var physics_body := PhysicsServer2D.body_create()
	PhysicsServer2D.body_set_space(physics_body, spawned_node.get_world_2d().space)
	fixture.own_physics_rid(physics_body)
	await fixture.physics_frames(2)

	expect(spawned_node.is_inside_tree(), "Fixture adds and owns spawned nodes")
	expect(
		int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS))
		>= active_objects_before + 1,
		"Fixture-owned manual physics resources enter the active world"
	)
	fixture.complete(false)
	await fixture.physics_frames(2)
	expect(not is_instance_valid(spawned_node), "Fixture deterministically frees spawned nodes")
	expect(
		int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS))
		<= active_objects_before,
		"Fixture deterministically releases manual physics resources"
	)


func test_assertion_failure_completion() -> void:
	var previous_paused := paused
	var fixture := HeadlessGameplayFixture.new(self)
	var spawned_node := fixture.add_node(Node.new())
	fixture.set_paused(not previous_paused)
	fixture.expect(true, "Passing expectations are not diagnostics")
	fixture.expect(false, "Expected assertion diagnostic")

	var exit_code := fixture.complete(false)
	expect(exit_code == 1, "Assertion failure completion returns a nonzero exit code")
	expect(
		fixture.get_failures() == ["Expected assertion diagnostic"],
		"Boolean expectations accumulate useful diagnostics"
	)
	expect(not is_instance_valid(spawned_node), "Assertion failure completion cleans owned nodes")
	expect(paused == previous_paused, "Assertion failure completion restores pause state")


func test_expected_early_completion() -> void:
	var fixture := HeadlessGameplayFixture.new(self)
	var spawned_node := fixture.add_node(Node.new())

	var exit_code := fixture.complete(false)
	expect(exit_code == 0, "Expected early completion returns a zero exit code")
	expect(not is_instance_valid(spawned_node), "Expected early completion cleans owned nodes")


func test_setup_failure_completion() -> void:
	var fixture := HeadlessGameplayFixture.new(self)
	var spawned_node := fixture.add_node(Node.new())
	var missing_instance := fixture.instantiate_scene(PackedScene.new())

	var exit_code := fixture.complete(false)
	expect(missing_instance == null, "Missing scene setup returns no instance")
	expect(exit_code == 1, "Unexpected setup failure returns a nonzero exit code")
	expect(
		fixture.get_failures() == ["Scene instantiation failed"],
		"Unexpected setup failure records a useful diagnostic"
	)
	expect(not is_instance_valid(spawned_node), "Unexpected setup failure cleans owned nodes")


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("Headless gameplay fixture contract test passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
