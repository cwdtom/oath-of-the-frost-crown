extends SceneTree


const PLAYER_SCENE := preload("res://player/player.tscn")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	fixture.set_project_setting("physics/2d/default_gravity", 0.0)

	await test_attack_input_is_rejected_during_player_attack_cooldown()

	fixture.complete(false)
	await fixture.process_frames(3)
	await fixture.physics_frames(3)
	fixture.complete()


func test_attack_input_is_rejected_during_player_attack_cooldown() -> void:
	var player := fixture.instantiate_scene(PLAYER_SCENE) as CharacterBody2D
	fixture.expect(player != null, "Player loads through its production input seam")
	if player == null:
		return

	fixture.set_current_scene(player)
	await fixture.process_frames(1)
	Input.action_release(&"attack")
	await fixture.physics_frames(2)
	var animation_tree := player.get_node("AnimationTree") as AnimationTree
	var animation_state := animation_tree.get(
		"parameters/playback"
	) as AnimationNodeStateMachinePlayback
	var attack_start_count := [0]
	animation_tree.animation_started.connect(
		func(animation_name: StringName) -> void:
			if animation_name == &"attack":
				attack_start_count[0] += 1
	)

	await press_attack()
	fixture.expect(
		attack_start_count[0] == 1,
		"Player accepts the first attack input"
	)

	await fixture.physics_frames(40)
	fixture.expect(
		animation_state.get_current_node() != &"attack",
		"Player finishes its attack presentation before Player Attack Cooldown ends"
	)
	var locomotion_animation := animation_state.get_current_node()
	Input.action_press(&"attack")
	await fixture.physics_frames(2)
	fixture.expect(
		attack_start_count[0] == 1
		and animation_state.get_current_node() == locomotion_animation,
		"Player rejects attack input during Player Attack Cooldown"
	)

	await fixture.physics_frames(25)
	fixture.expect(
		attack_start_count[0] == 1
		and animation_state.get_current_node() == locomotion_animation,
		"Held attack input is not buffered when Player Attack Cooldown ends"
	)
	Input.action_release(&"attack")
	await fixture.physics_frames(2)
	await press_attack()
	fixture.expect(
		attack_start_count[0] == 2,
		"Player accepts a new attack press after Player Attack Cooldown"
	)


func press_attack() -> void:
	Input.action_press(&"attack")
	await fixture.physics_frames(2)
	Input.action_release(&"attack")
	await fixture.physics_frames(1)
