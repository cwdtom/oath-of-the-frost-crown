extends CharacterBody2D


@export var patrol_range := 160.0
@export var run_speed := 80.0
@export var idle_duration := 1.0

const HURT_ANIMATION = "hurt"
const HURT_KNOCKBACK_DISTANCE = 100.0

enum {IDLE, RUN, HURT}

var state := -1
var is_hurting := false
var start_x := 0.0
var move_direction := 1.0
var idle_time_left := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_state: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")


func _ready() -> void:
	animation_tree.active = true
	start_x = global_position.x
	change_state(IDLE)


func change_state(new_state: int) -> void:
	if state == new_state:
		return

	state = new_state
	match state:
		IDLE:
			idle_time_left = idle_duration
			velocity.x = 0.0
			animation_state.travel("idle")
		RUN:
			face_move_direction()
			animation_state.travel("running")
		HURT:
			velocity.x = 0.0
			animation_state.travel(HURT_ANIMATION)


func face_move_direction() -> void:
	sprite.flip_h = move_direction < 0.0


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


func _physics_process(delta: float) -> void:
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


func _on_hurt_box_area_entered(area: Area2D) -> void:
	if not area.is_in_group("weapons"):
		return

	hurt(global_position - area.global_position)


func hurt(knockback_direction: Vector2 = Vector2.ZERO) -> void:
	if is_hurting:
		return

	var return_state := state
	is_hurting = true
	if not knockback_direction.is_zero_approx():
		global_position += knockback_direction.normalized() * HURT_KNOCKBACK_DISTANCE
	change_state(HURT)
	await get_tree().create_timer(animation_player.get_animation(HURT_ANIMATION).length).timeout
	is_hurting = false
	change_state(return_state)
