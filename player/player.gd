extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const ATTACK_TO_IDLE = "parameters/conditions/attack_to_idle"
const ATTACK_TO_JUMP = "parameters/conditions/attack_to_jump"
const ATTACK_TO_RUNNING = "parameters/conditions/attack_to_running"

enum {IDLE, RUN, JUMP, HURT, DEAD, ATTACK}
var state = -1

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_state: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")


func change_state(new_state: int) -> void:
	if state == new_state:
		return

	state = new_state
	match state:
		IDLE:
			animation_state.travel("idle")
		RUN:
			animation_state.travel("running")
		JUMP:
			animation_state.travel("jump")
		ATTACK:
			animation_state.travel("attack")
		DEAD:
			hide()


func set_attack_return_conditions(direction: float) -> void:
	var should_jump := not is_on_floor()
	var should_run := not should_jump and not is_zero_approx(direction)

	animation_tree.set(ATTACK_TO_JUMP, should_jump)
	animation_tree.set(ATTACK_TO_RUNNING, should_run)
	animation_tree.set(ATTACK_TO_IDLE, not should_jump and not should_run)


func _ready() -> void:
	animation_tree.active = true
	change_state(IDLE)


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# Handle attack.
	var wants_attack := Input.is_action_just_pressed("attack")

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("left", "right")
	if direction:
		$Sprite2D.flip_h = (direction < 0)
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	if wants_attack:
		change_state(ATTACK)
		set_attack_return_conditions(direction)
		return

	if state == ATTACK and animation_state.get_current_node() == "attack":
		set_attack_return_conditions(direction)
		return

	if not is_on_floor():
		change_state(JUMP)
	elif direction:
		change_state(RUN)
	else:
		change_state(IDLE)
