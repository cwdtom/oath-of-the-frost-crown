extends CharacterBody2D


@export var patrol_range := 160.0
@export var run_speed := 80.0
@export var idle_duration := 1.0

enum {IDLE, RUN}

var state := -1
var start_x := 0.0
var move_direction := 1.0
var idle_time_left := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
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
			animation_player.play("idle")
		RUN:
			face_move_direction()
			animation_player.play("running")


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

	match state:
		IDLE:
			update_idle(delta)
		RUN:
			update_run(delta)

	move_and_slide()
