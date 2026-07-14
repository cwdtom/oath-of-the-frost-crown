extends CharacterBody2D


@export var patrol_range := 160.0
@export var run_speed := 80.0
@export var idle_duration := 1.0

const DEAD_ANIMATION := &"dead"
const HURT_ANIMATION := &"hurt"
const IDLE_ANIMATION := &"idle"
const RUN_ANIMATION := &"run"
const SKILL_ANIMATION := &"skill"
const HURT_KNOCKBACK_DISTANCE := 100.0
const ENVIRONMENT_COLLISION_MASK := 1
const WALL_CHECK_DISTANCE := 72.0
const WALL_CHECK_Y_OFFSETS := [-24.0, 24.0]

enum {IDLE, RUN, HURT, DEAD, SKILL}

var state := -1
var _health := 0
var is_hurting := false
var start_x := 0.0
var move_direction := -1.0
var idle_time_left := 0.0
var skill_return_state: int = IDLE
var skill_detect_offset_x := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_state: AnimationNodeStateMachinePlayback = animation_tree.get(
	"parameters/playback"
)
@onready var body_collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hurt_box_collision_shape: CollisionShape2D = $HurtBox/CollisionShape2D
@onready var skill_detect_collision_shape: CollisionShape2D = $SkillDetect/CollisionShape2D
@onready var skill_cooldown_timer: Timer = $SkillDetect/Cooldown


func _ready() -> void:
	animation_tree.active = true
	start_x = global_position.x
	skill_detect_offset_x = absf(skill_detect_collision_shape.position.x)
	change_state(IDLE)


func change_state(new_state: int) -> void:
	if state == new_state:
		return

	var previous_state := state
	state = new_state
	if previous_state == SKILL and state != SKILL:
		_stop_species_skill_presentation()

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
		HURT:
			velocity.x = 0.0
			hurt_box_collision_shape.set_deferred("disabled", false)
			animation_state.travel(HURT_ANIMATION)
		SKILL:
			velocity.x = 0.0
			hurt_box_collision_shape.set_deferred("disabled", false)
			face_move_direction()
			call_deferred("_play_skill_presentations")
		DEAD:
			velocity = Vector2.ZERO
			remove_from_group("enemies")
			body_collision_shape.set_deferred("disabled", true)
			hurt_box_collision_shape.set_deferred("disabled", true)
			animation_state.travel(DEAD_ANIMATION)


func face_move_direction() -> void:
	sprite.flip_h = move_direction > 0.0
	skill_detect_collision_shape.position.x = skill_detect_offset_x * move_direction


func _is_playing_animation(animation_name: StringName) -> bool:
	return animation_state.get_current_node() == animation_name


func _get_animation_position(animation_name: StringName) -> float:
	if not _is_playing_animation(animation_name):
		return -1.0

	return animation_state.get_current_play_position()


func _get_animation_length(animation_name: StringName) -> float:
	return animation_player.get_animation(animation_name).length


func _is_facing_right() -> bool:
	return sprite.flip_h


func _play_skill_presentations() -> void:
	if state != SKILL:
		return

	animation_state.travel(SKILL_ANIMATION)
	_play_species_skill_presentation()


func _play_species_skill_presentation() -> void:
	pass


func _stop_species_skill_presentation() -> void:
	pass


func turn_around() -> void:
	move_direction *= -1.0
	face_move_direction()
	velocity.x = move_direction * run_speed


func is_front_blocked() -> bool:
	var space_state := get_world_2d().direct_space_state
	var world_scale := global_transform.get_scale()
	var check_distance: float = WALL_CHECK_DISTANCE * absf(world_scale.x)
	for y_offset in WALL_CHECK_Y_OFFSETS:
		var from := global_position + Vector2(0.0, y_offset * absf(world_scale.y))
		var to := from + Vector2(move_direction * check_distance, 0.0)
		var query := PhysicsRayQueryParameters2D.create(from, to, ENVIRONMENT_COLLISION_MASK)
		query.exclude = [get_rid()]
		if not space_state.intersect_ray(query).is_empty():
			return true

	return false


func apply_knockback(knockback_direction: Vector2) -> void:
	if knockback_direction.is_zero_approx():
		return

	move_and_collide(knockback_direction.normalized() * HURT_KNOCKBACK_DISTANCE)


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
		turn_around()
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


func turn_around_from_environment_collision() -> void:
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		if (
			PhysicsServer2D.body_get_collision_layer(collision.get_collider_rid())
			& ENVIRONMENT_COLLISION_MASK
			!= 0
			and collision.get_normal().x * move_direction < -0.5
		):
			turn_around()
			return


func start_skill() -> void:
	skill_return_state = state
	skill_cooldown_timer.start()
	change_state(SKILL)
	await get_tree().create_timer(_get_animation_length(SKILL_ANIMATION)).timeout
	if state == SKILL:
		finish_skill()


func finish_skill() -> void:
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

	match state:
		IDLE:
			update_idle(delta)
		RUN:
			update_run(delta)

	move_and_slide()
	if state == RUN:
		turn_around_from_environment_collision()


func _on_hurt_box_area_entered(area: Area2D) -> void:
	if state == DEAD or not area.is_in_group("weapons"):
		return

	hurt(global_position - area.global_position)


func _on_skill_detect_body_entered(_body: Node2D) -> void:
	if state == DEAD or state == SKILL or is_hurting or not skill_cooldown_timer.is_stopped():
		return

	start_skill()


func hurt(knockback_direction: Vector2 = Vector2.ZERO) -> void:
	if is_hurting or state == DEAD:
		return

	_health -= 1
	if _health <= 0:
		die()
		return

	var return_state := skill_return_state if state == SKILL else state
	is_hurting = true
	apply_knockback(knockback_direction)
	change_state(HURT)
	await get_tree().create_timer(_get_animation_length(HURT_ANIMATION)).timeout
	is_hurting = false
	change_state(return_state)


func die() -> void:
	change_state(DEAD)
	await get_tree().create_timer(_get_animation_length(DEAD_ANIMATION)).timeout
	queue_free()
