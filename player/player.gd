extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const ATTACK_TO_IDLE = "parameters/conditions/attack_to_idle"
const ATTACK_TO_JUMP = "parameters/conditions/attack_to_jump"
const ATTACK_TO_RUNNING = "parameters/conditions/attack_to_running"
const HURT_ANIMATION = "hurt"
const HURT_KNOCKBACK_DISTANCE = 100.0

enum {IDLE, RUN, JUMP, HURT, DEAD, ATTACK}
var state = -1
var is_hurting := false

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_state: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
@onready var visual_root: Node2D = $VisualRoot
@onready var weapon_collision_shape: CollisionShape2D = $VisualRoot/WeaponMount/Area2D/CollisionShape2D


func change_state(new_state: int) -> void:
	if state == new_state:
		return

	state = new_state
	set_weapon_collision_enabled(state == ATTACK)
	match state:
		IDLE:
			animation_state.travel("idle")
		RUN:
			animation_state.travel("running")
		JUMP:
			animation_state.travel("jump")
		ATTACK:
			animation_state.travel("attack")
		HURT:
			animation_state.travel(HURT_ANIMATION)
		DEAD:
			hide()


func set_weapon_collision_enabled(enabled: bool) -> void:
	weapon_collision_shape.set_deferred("disabled", not enabled)


func set_attack_return_conditions(direction: float) -> void:
	var should_jump := not is_on_floor()
	var should_run := not should_jump and not is_zero_approx(direction)

	animation_tree.set(ATTACK_TO_JUMP, should_jump)
	animation_tree.set(ATTACK_TO_RUNNING, should_run)
	animation_tree.set(ATTACK_TO_IDLE, not should_jump and not should_run)


func _ready() -> void:
	animation_tree.active = true
	set_weapon_collision_enabled(false)
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
		visual_root.scale.x = -1.0 if direction < 0.0 else 1.0
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	if is_hurting:
		return

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

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		if collision.get_collider().is_in_group("enemies"):
			hurt(collision.get_normal())


func hurt(knockback_direction: Vector2 = Vector2.ZERO) -> void:
	if is_hurting:
		return

	is_hurting = true
	if not knockback_direction.is_zero_approx():
		global_position += knockback_direction.normalized() * HURT_KNOCKBACK_DISTANCE
	change_state(HURT)
	await get_tree().create_timer(animation_player.get_animation(HURT_ANIMATION).length).timeout
	is_hurting = false
