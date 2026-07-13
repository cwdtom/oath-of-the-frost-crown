extends SceneTree


const BEAR_SCENE := preload("res://enemies/bear.tscn")
const PLAYER_SCENE := preload("res://player/player.tscn")
const SKILL_ANIMATION := &"skill"
const EARTHQUAKE_CAST_ANIMATION := &"cast"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	ProjectSettings.set_setting("physics/2d/default_gravity", 0.0)

	var world := Node2D.new()
	root.add_child(world)

	var bear := BEAR_SCENE.instantiate() as CharacterBody2D
	world.add_child(bear)

	var animation_player := bear.get_node("AnimationPlayer") as AnimationPlayer
	var animation_tree := bear.get_node("AnimationTree") as AnimationTree
	var animation_state: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
	var earthquake_animation_player := bear.get_node("Earthquake/AnimationPlayer") as AnimationPlayer
	var skill_cooldown := bear.get_node("SkillDetect/Cooldown") as Timer
	var start_x := bear.global_position.x
	var return_state: int = bear.get("state")

	bear.call("_on_skill_detect_body_entered", bear)
	await create_timer(0.05).timeout
	var skill_state: int = bear.get("state")
	expect(skill_state != return_state, "Bear enters the skill state when a body is detected")
	expect(
		animation_state.get_current_node() == SKILL_ANIMATION,
		"Bear plays the skill animation when a body is detected"
	)
	expect(
		earthquake_animation_player.current_animation == EARTHQUAKE_CAST_ANIMATION,
		"Bear skill starts the earthquake cast animation"
	)
	expect(
		absf(
			earthquake_animation_player.current_animation_position
			- animation_state.get_current_play_position()
		) < 0.1,
		"Bear skill and earthquake cast animations start in sync"
	)
	expect(bear.velocity.x == 0.0, "Bear skill does not add dash velocity")

	await create_timer(0.2).timeout
	var play_position_before_repeat := animation_state.get_current_play_position()
	var earthquake_position_before_repeat := -1.0
	if earthquake_animation_player.current_animation == EARTHQUAKE_CAST_ANIMATION:
		earthquake_position_before_repeat = earthquake_animation_player.current_animation_position
	var cooldown_before_repeat := skill_cooldown.time_left
	bear.call("_on_skill_detect_body_entered", bear)
	await create_timer(0.05).timeout
	expect(
		animation_state.get_current_play_position() > play_position_before_repeat,
		"Repeated detection does not restart the skill animation"
	)
	expect(
		earthquake_animation_player.current_animation == EARTHQUAKE_CAST_ANIMATION
		and earthquake_animation_player.current_animation_position > earthquake_position_before_repeat,
		"Repeated detection does not restart the earthquake cast animation"
	)
	expect(
		skill_cooldown.time_left < cooldown_before_repeat,
		"Repeated detection does not restart the skill cooldown"
	)

	var skill_length := animation_player.get_animation(SKILL_ANIMATION).length
	await create_timer(skill_length + 0.1).timeout
	expect(bear.get("state") == return_state, "Bear returns to its previous state after one animation")
	expect(bear.global_position.x == start_x, "Bear does not move horizontally while using its skill")

	bear.call("_on_skill_detect_body_entered", bear)
	await process_frame
	expect(bear.get("state") != skill_state, "Bear cannot replay the skill during its cooldown")

	var attackable_bear := BEAR_SCENE.instantiate() as CharacterBody2D
	world.add_child(attackable_bear)
	var attackable_animation_tree := attackable_bear.get_node("AnimationTree") as AnimationTree
	var attackable_animation_state: AnimationNodeStateMachinePlayback = attackable_animation_tree.get(
		"parameters/playback"
	)
	attackable_bear.call("_on_skill_detect_body_entered", attackable_bear)
	await create_timer(0.05).timeout
	var attackable_skill_state: int = attackable_bear.get("state")
	var health_before_hit: int = attackable_bear.get("health")
	var weapon := Area2D.new()
	world.add_child(weapon)
	weapon.add_to_group("weapons")
	attackable_bear.call("_on_hurt_box_area_entered", weapon)
	expect(
		attackable_bear.get("health") == health_before_hit - 1,
		"Bear remains vulnerable while playing its skill animation"
	)
	expect(
		attackable_bear.get("state") != attackable_skill_state,
		"Taking damage interrupts the Bear skill animation"
	)
	await create_timer(0.05).timeout
	expect(
		attackable_animation_state.get_current_node() == &"hurt",
		"Taking damage visibly switches the Bear from skill to hurt"
	)

	var damaging_bear := BEAR_SCENE.instantiate() as CharacterBody2D
	damaging_bear.position = Vector2(1000.0, 0.0)
	world.add_child(damaging_bear)
	var earthquake := damaging_bear.get_node("Earthquake") as Area2D
	var earthquake_collision_shape := earthquake.get_node("CollisionShape2D") as CollisionShape2D
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	world.add_child(player)
	player.global_position = earthquake.global_position
	player.set_physics_process(false)
	var player_health_before: int = player.get("health")
	damaging_bear.call("_on_skill_detect_body_entered", player)
	await create_timer(0.75).timeout
	await physics_frame
	expect(not earthquake_collision_shape.disabled, "Earthquake activates its collision at impact")
	expect(
		earthquake.get_overlapping_bodies().has(player),
		"Earthquake detects an overlapping player at impact"
	)
	expect(
		player.get("health") == player_health_before - 1,
		"Earthquake damages an overlapping player when its collision becomes active"
	)
	await create_timer(0.2).timeout
	expect(
		player.get("health") == player_health_before - 1,
		"One earthquake cast damages the same player only once"
	)

	var dying_bear := BEAR_SCENE.instantiate() as CharacterBody2D
	dying_bear.position = Vector2(2000.0, 0.0)
	world.add_child(dying_bear)
	var dying_animation_player := dying_bear.get_node("AnimationPlayer") as AnimationPlayer
	var dying_animation_tree := dying_bear.get_node("AnimationTree") as AnimationTree
	var dying_animation_state: AnimationNodeStateMachinePlayback = dying_animation_tree.get(
		"parameters/playback"
	)
	var dead_animation_length := dying_animation_player.get_animation(&"dead").length
	await create_timer(0.1).timeout
	dying_bear.call("die")
	await create_timer(0.05).timeout
	expect(
		dying_animation_state.get_current_node() == &"dead",
		"Bear enters the dead animation immediately when it dies"
	)
	await create_timer(dead_animation_length - 0.1).timeout
	expect(is_instance_valid(dying_bear), "Bear remains alive until the dead animation finishes")
	expect(
		dying_animation_state.get_current_play_position() >= dead_animation_length - 0.1,
		"Bear plays the dead animation through its final frames before being freed"
	)
	await create_timer(0.15).timeout
	expect(not is_instance_valid(dying_bear), "Bear is freed after the dead animation finishes")

	ProjectSettings.set_setting("physics/2d/default_gravity", original_gravity)
	world.queue_free()
	await process_frame
	finish()


func expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("Bear skill animation test passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
