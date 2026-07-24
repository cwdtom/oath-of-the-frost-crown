extends SceneTree


const PLAYER_SCENE := preload("res://player/player.tscn")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	fixture.set_project_setting("physics/2d/default_gravity", 0.0)

	await test_player_attack_cooldown_presents_player_attack_rejection_feedback()
	await test_each_new_rejection_restarts_player_attack_rejection_feedback()
	await test_player_hurt_prevents_player_attack_rejection_feedback()

	fixture.complete(false)
	await fixture.process_frames(3)
	await fixture.physics_frames(3)
	fixture.complete()


func test_player_attack_cooldown_presents_player_attack_rejection_feedback() -> void:
	var player := await instantiate_player()
	if player == null:
		return

	var animation_tree := player.get_node("AnimationTree") as AnimationTree
	var animation_state := animation_tree.get(
		"parameters/playback"
	) as AnimationNodeStateMachinePlayback
	var rejection_feedback := get_player_attack_rejection_feedback(player)
	var attack_cooldown := player.get_node("AttackCooldown") as Timer
	if rejection_feedback == null:
		return
	var attack_start_count := [0]
	animation_tree.animation_started.connect(
		func(animation_name: StringName) -> void:
			if animation_name == &"attack":
				attack_start_count[0] += 1
	)

	await press_attack()
	fixture.expect(
		attack_start_count[0] == 1 and not rejection_feedback.playing,
		"Player accepts the first attack input without Player Attack Rejection Feedback"
	)

	player.set_controls_enabled(false)
	await press_attack()
	fixture.expect(
		not rejection_feedback.playing,
		"Disabled controls prevent Player Attack Rejection Feedback"
	)
	player.set_controls_enabled(true)

	await fixture.physics_frames(37)
	fixture.expect(
		animation_state.get_current_node() != &"attack",
		"Player finishes its attack presentation before Player Attack Cooldown ends"
	)
	var locomotion_animation := animation_state.get_current_node()
	Input.action_press(&"attack")
	await fixture.physics_frames(2)
	fixture.expect(
		attack_start_count[0] == 1
		and animation_state.get_current_node() == locomotion_animation
		and rejection_feedback.playing,
		"Player Attack Cooldown presents Player Attack Rejection Feedback"
	)

	await fixture.physics_frames(17)
	fixture.expect(
		attack_start_count[0] == 1
		and animation_state.get_current_node() == locomotion_animation
		and attack_cooldown.is_stopped()
		and rejection_feedback.playing,
		"Held attack is not buffered and Player Attack Rejection Feedback outlasts Player Attack Cooldown"
	)
	Input.action_release(&"attack")
	await fixture.physics_frames(2)
	await press_attack()
	fixture.expect(
		attack_start_count[0] == 2 and rejection_feedback.playing,
		"Player accepts a new attack while Player Attack Rejection Feedback finishes"
	)
	player.queue_free()
	await fixture.process_frames(1)


func test_each_new_rejection_restarts_player_attack_rejection_feedback() -> void:
	var player := await instantiate_player()
	if player == null:
		return

	var rejection_feedback := get_player_attack_rejection_feedback(player)
	if rejection_feedback == null:
		return

	await press_attack()
	await press_attack()
	await fixture.wait_seconds(0.2)
	await press_attack()
	await fixture.wait_seconds(0.35)
	fixture.expect(
		rejection_feedback.playing,
		"Each new Player Attack Cooldown rejection restarts Player Attack Rejection Feedback"
	)
	player.queue_free()
	await fixture.process_frames(1)


func test_player_hurt_prevents_player_attack_rejection_feedback() -> void:
	var player := await instantiate_player()
	if player == null:
		return

	var rejection_feedback := get_player_attack_rejection_feedback(player)
	if rejection_feedback == null:
		return

	await press_attack()
	player.take_damage(1, Vector2.RIGHT)
	await press_attack()
	fixture.expect(
		not rejection_feedback.playing,
		"Player Hurt prevents Player Attack Rejection Feedback"
	)
	player.queue_free()
	await fixture.process_frames(1)


func instantiate_player() -> CharacterBody2D:
	var player := fixture.instantiate_scene(PLAYER_SCENE) as CharacterBody2D
	fixture.expect(player != null, "Player loads through its production input seam")
	if player == null:
		return null

	fixture.set_current_scene(player)
	await fixture.process_frames(1)
	Input.action_release(&"attack")
	await fixture.physics_frames(2)
	return player


func get_player_attack_rejection_feedback(
	player: CharacterBody2D
) -> AudioStreamPlayer2D:
	var rejection_feedback := player.get_node_or_null(
		"AttackRejectionFeedback"
	) as AudioStreamPlayer2D
	fixture.expect(
		rejection_feedback != null,
		"Player exposes Player Attack Rejection Feedback"
	)
	return rejection_feedback


func press_attack() -> void:
	Input.action_press(&"attack")
	await fixture.physics_frames(2)
	Input.action_release(&"attack")
	await fixture.physics_frames(1)
