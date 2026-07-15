extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const TEST_SETTING := "testing/headless_gameplay_fixture_status"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var fixture := HeadlessGameplayFixture.new(self)
	fixture.add_node(Node.new())
	fixture.own_physics_rid(PhysicsServer2D.body_create())
	fixture.set_project_setting(TEST_SETTING, true)
	fixture.set_paused(true)

	var arguments := OS.get_cmdline_user_args()
	if arguments.has("--early"):
		fixture.complete()
		return
	if arguments.has("--fail"):
		fixture.expect(false, "Expected standalone assertion diagnostic")
	elif arguments.has("--setup-failure"):
		fixture.instantiate_scene(PackedScene.new())

	fixture.complete()
