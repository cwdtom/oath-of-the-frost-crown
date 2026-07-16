extends SceneTree


const PLAYER_02_SCENE := preload("res://player/player_02.tscn")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	fixture.set_project_setting("physics/2d/default_gravity", 0.0)

	await expect_thunder_on_facing_side(&"left", -1.0, "left")
	await expect_thunder_on_facing_side(&"right", 1.0, "right")

	fixture.complete()


func expect_thunder_on_facing_side(
	direction_action: StringName,
	expected_side: float,
	description: String
) -> void:
	var player := fixture.instantiate_scene(PLAYER_02_SCENE) as CharacterBody2D
	fixture.set_current_scene(player)
	await fixture.process_frames(1)

	send_action(direction_action, true)
	await fixture.physics_frames(2)
	send_action(direction_action, false)
	await fixture.physics_frames(2)

	send_action(&"attack", true)
	await fixture.physics_frames(2)
	send_action(&"attack", false)

	var thunder := player.get_node("Player_Thunder") as Area2D
	fixture.expect(
		(thunder.global_position.x - player.global_position.x) * expected_side > 0.0,
		"Player thunder appears on the %s-facing side" % description
	)

	fixture.set_current_scene(null)
	player.free()
	await fixture.process_frames(1)


func send_action(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
