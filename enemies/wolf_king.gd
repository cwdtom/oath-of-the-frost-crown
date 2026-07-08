extends CharacterBody2D


@export var patrol_range := 300.0
@export var run_speed := 150.0
@export var idle_duration := 1.0

const MAX_HEALTH = 5
const DEAD_ANIMATION = "dead"
const HURT_ANIMATION = "hurt"
const IDLE_ANIMATION = "idle"
const RUN_ANIMATION = "run"
const THUNDER_CAST_ANIMATION = "cast"
const THUNDER_CAST_RANGE = 200.0
const THUNDER_GROUND_RAY_UP_DISTANCE = 800.0
const THUNDER_GROUND_RAY_DOWN_DISTANCE = 1400.0
const SKILL_DISTANCE = 300.0
const SKILL_SPEED = 400.0
const ENVIRONMENT_COLLISION_MASK = 1
const WALL_CHECK_DISTANCE = 72.0
const WALL_CHECK_Y_OFFSETS = [-24.0, 24.0]

enum {IDLE, RUN, HURT, DEAD, SKILL}

var state := -1
var health := MAX_HEALTH
var is_hurting := false
var start_x := 0.0
var move_direction := -1.0
var idle_time_left := 0.0
var skill_distance_left := 0.0
var skill_return_state := IDLE
var skill_detect_offset_x := 0.0
var rng := RandomNumberGenerator.new()

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_state: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
@onready var body_collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hurt_box_collision_shape: CollisionShape2D = $HurtBox/CollisionShape2D
@onready var skill_detect_collision_shape: CollisionShape2D = $SkillDetect/CollisionShape2D
@onready var skill_cooldown_timer: Timer = $SkillDetect/Cooldown
@onready var thunder: Area2D = $Thunder
@onready var thunder_sprite: Sprite2D = $Thunder/Sprite2D
@onready var thunder_collision_shape: CollisionShape2D = $Thunder/CollisionShape2D
@onready var thunder_animation_player: AnimationPlayer = $Thunder/AnimationPlayer
@onready var thunder_particles: CPUParticles2D = $Thunder/CPUParticles2D
@onready var thunder_start_offset: Vector2 = thunder.position


func _ready() -> void:
	rng.randomize()
	animation_tree.active = true
	thunder.top_level = true
	start_x = global_position.x
	skill_detect_offset_x = abs(skill_detect_collision_shape.position.x)
	reset_thunder()
	change_state(IDLE)


func change_state(new_state: int) -> void:
	if state == new_state:
		return

	state = new_state
	match state:
		IDLE:
			idle_time_left = idle_duration
			velocity.x = 0.0
			hurt_box_collision_shape.set_deferred("disabled", false)
			face_move_direction()
			animation_state.travel(IDLE_ANIMATION)
		RUN:
			hurt_box_collision_shape.set_deferred("disabled", false)
			face_move_direction()
			animation_state.travel(RUN_ANIMATION)
		SKILL:
			hurt_box_collision_shape.set_deferred("disabled", true)
			face_move_direction()
			animation_state.travel(RUN_ANIMATION)
		HURT:
			velocity.x = 0.0
			hurt_box_collision_shape.set_deferred("disabled", false)
			animation_state.travel(HURT_ANIMATION)
		DEAD:
			velocity = Vector2.ZERO
			remove_from_group("enemies")
			body_collision_shape.set_deferred("disabled", true)
			hurt_box_collision_shape.set_deferred("disabled", true)
			skill_detect_collision_shape.set_deferred("disabled", true)
			reset_thunder()
			animation_state.travel(DEAD_ANIMATION)


func face_move_direction() -> void:
	sprite.flip_h = move_direction > 0.0
	skill_detect_collision_shape.position.x = skill_detect_offset_x * move_direction


func is_front_blocked() -> bool:
	var space_state := get_world_2d().direct_space_state
	var check_distance: float = WALL_CHECK_DISTANCE * absf(global_transform.get_scale().x)
	for y_offset in WALL_CHECK_Y_OFFSETS:
		var from := global_position + Vector2(0.0, y_offset)
		var to := from + Vector2(move_direction * check_distance, 0.0)
		var query := PhysicsRayQueryParameters2D.create(from, to, ENVIRONMENT_COLLISION_MASK)
		query.exclude = [get_rid()]
		if not space_state.intersect_ray(query).is_empty():
			return true

	return false


func update_idle(delta: float) -> void:
	velocity.x = 0.0
	idle_time_left -= delta
	if idle_time_left <= 0.0:
		change_state(RUN)


func update_run(delta: float) -> void:
	if patrol_range <= 0.0:
		change_state(IDLE)
		return

	var left_edge := start_x - patrol_range
	var right_edge := start_x + patrol_range
	var next_x := global_position.x + move_direction * run_speed * delta

	if is_front_blocked():
		move_direction *= -1.0
		face_move_direction()
		velocity.x = move_direction * run_speed
		return

	if move_direction > 0.0 and next_x >= right_edge:
		global_position.x = right_edge
		move_direction = -1.0
		change_state(IDLE)
		return

	if move_direction < 0.0 and next_x <= left_edge:
		global_position.x = left_edge
		move_direction = 1.0
		change_state(IDLE)
		return

	face_move_direction()
	velocity.x = move_direction * run_speed


func start_skill() -> void:
	skill_return_state = state
	skill_distance_left = SKILL_DISTANCE
	skill_cooldown_timer.start()
	change_state(SKILL)
	cast_thunder()


func update_skill(delta: float) -> void:
	var travel_distance = min(SKILL_SPEED * delta, skill_distance_left)
	velocity.x = move_direction * travel_distance / delta
	skill_distance_left -= travel_distance


func finish_skill() -> void:
	velocity.x = 0.0
	start_x = global_position.x
	change_state(skill_return_state)


func _physics_process(delta: float) -> void:
	if state == DEAD:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if is_hurting:
		velocity.x = 0.0
		move_and_slide()
		return

	var was_using_skill := state == SKILL

	match state:
		IDLE:
			update_idle(delta)
		RUN:
			update_run(delta)
		SKILL:
			update_skill(delta)

	move_and_slide()

	if was_using_skill and state == SKILL and skill_distance_left <= 0.0:
		finish_skill()


func _on_hurt_box_area_entered(area: Area2D) -> void:
	if state == DEAD or state == SKILL:
		return

	if not area.is_in_group("weapons"):
		return

	hurt()


func _on_skill_detect_body_entered(_body: Node2D) -> void:
	if state == DEAD or state == SKILL or is_hurting or not skill_cooldown_timer.is_stopped():
		return

	start_skill()


func cast_thunder() -> void:
	var thunder_x := global_position.x + get_random_thunder_x_offset()
	thunder.global_position = Vector2(thunder_x, get_thunder_ground_y(thunder_x))
	thunder_animation_player.stop()
	thunder_animation_player.play(THUNDER_CAST_ANIMATION)


func get_thunder_ground_y(thunder_x: float) -> float:
	var from := Vector2(thunder_x, global_position.y - THUNDER_GROUND_RAY_UP_DISTANCE)
	var to := Vector2(thunder_x, global_position.y + THUNDER_GROUND_RAY_DOWN_DISTANCE)
	var query := PhysicsRayQueryParameters2D.create(from, to, ENVIRONMENT_COLLISION_MASK)
	query.exclude = [get_rid()]

	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return global_position.y + thunder_start_offset.y

	var hit_position: Vector2 = hit["position"]
	return hit_position.y - get_thunder_bottom_offset()


func get_thunder_bottom_offset() -> float:
	var rectangle_shape := thunder_collision_shape.shape as RectangleShape2D
	if rectangle_shape != null:
		return thunder_collision_shape.position.y + rectangle_shape.size.y * 0.5

	var circle_shape := thunder_collision_shape.shape as CircleShape2D
	if circle_shape != null:
		return thunder_collision_shape.position.y + circle_shape.radius

	return thunder_particles.position.y


func get_random_thunder_x_offset() -> float:
	var side := -1.0 if rng.randi_range(0, 1) == 0 else 1.0
	var excluded_half_width := minf(get_body_half_width(), THUNDER_CAST_RANGE)
	return rng.randf_range(excluded_half_width, THUNDER_CAST_RANGE) * side


func get_body_half_width() -> float:
	var circle_shape := body_collision_shape.shape as CircleShape2D
	if circle_shape != null:
		return absf(body_collision_shape.position.x) + circle_shape.radius

	var rectangle_shape := body_collision_shape.shape as RectangleShape2D
	if rectangle_shape != null:
		return absf(body_collision_shape.position.x) + rectangle_shape.size.x * 0.5

	return 0.0


func reset_thunder() -> void:
	thunder_animation_player.stop()
	thunder_sprite.visible = false
	thunder_collision_shape.set_deferred("disabled", true)
	thunder_particles.emitting = false


func _on_thunder_body_entered(body: Node2D) -> void:
	if state == DEAD or not body.has_method("hurt"):
		return

	body.hurt(body.global_position - thunder.global_position)


func hurt() -> void:
	if is_hurting or state == DEAD:
		return

	health -= 1
	if health <= 0:
		die()
		return

	var return_state := state
	is_hurting = true
	change_state(HURT)
	await get_tree().create_timer(animation_player.get_animation(HURT_ANIMATION).length).timeout
	is_hurting = false
	if state != DEAD:
		change_state(return_state)


func die() -> void:
	change_state(DEAD)
	await get_tree().create_timer(animation_player.get_animation(DEAD_ANIMATION).length).timeout
	queue_free()
