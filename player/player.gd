extends "res://combat/damageable_actor.gd"


signal hurt_taken
signal died
signal health_changed(current_health: int, maximum_health: int)

const SPEED = 300.0
const JUMP_VELOCITY = -500.0
const ATTACK_TO_IDLE = "parameters/conditions/attack_to_idle"
const ATTACK_TO_JUMP = "parameters/conditions/attack_to_jump"
const ATTACK_TO_RUNNING = "parameters/conditions/attack_to_running"
const MAX_HEALTH = 5
const DEAD_ANIMATION = "dead"
const HURT_ANIMATION = "hurt"
const HURT_KNOCKBACK_DISTANCE = 100.0
const DamageAndHealthModule := preload("res://combat/damage_and_health.gd")

enum {IDLE, RUN, JUMP, HURT, DEAD, ATTACK}
@export_range(1, 100, 1) var maximum_health := MAX_HEALTH:
	set(value):
		maximum_health = value
		if _health != null:
			_initialize_health(maximum_health)
var state = -1
var controls_enabled := true
var _health := DamageAndHealthModule.new(MAX_HEALTH)

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_state: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
@onready var visual_root: Node2D = $VisualRoot
@onready var weapon_collision_shape: CollisionShape2D = $VisualRoot/WeaponMount/Area2D/CollisionShape2D
@onready var thunder := get_node_or_null("Player_Thunder") as Area2D
@onready var thunder_animation_player := get_node_or_null("Player_Thunder/AnimationPlayer") as AnimationPlayer


func _init() -> void:
	_connect_health_signals()


func _initialize_health(value: int) -> void:
	_health = DamageAndHealthModule.new(value)
	_connect_health_signals()


func _connect_health_signals() -> void:
	_health.health_changed.connect(_on_health_changed)
	_health.depleted.connect(_on_health_depleted)


func get_current_health() -> int:
	return _health.get_current_health()


func get_maximum_health() -> int:
	return _health.get_maximum_health()


func is_hurt_immune() -> bool:
	return _health.is_hurt_immune()


func is_health_depleted() -> bool:
	return _health.is_depleted()


func apply_debug_health_override(health: int) -> bool:
	return _health.apply_debug_health_override(health)


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
			if thunder:
				thunder.position.x = absf(thunder.position.x) * visual_root.scale.x
			if thunder_animation_player:
				thunder_animation_player.play("cast")
		HURT:
			animation_state.travel(HURT_ANIMATION)
		DEAD:
			velocity = Vector2.ZERO
			animation_state.travel(DEAD_ANIMATION)


func set_weapon_collision_enabled(enabled: bool) -> void:
	weapon_collision_shape.set_deferred("disabled", not enabled)


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if controls_enabled or state == DEAD:
		return

	velocity.x = 0.0
	change_state(IDLE)


func restore_full_health() -> void:
	_health.restore_full_health()


func set_attack_return_conditions(direction: float) -> void:
	var should_jump := not is_on_floor()
	var should_run := not should_jump and not is_zero_approx(direction)

	animation_tree.set(ATTACK_TO_JUMP, should_jump)
	animation_tree.set(ATTACK_TO_RUNNING, should_run)
	animation_tree.set(ATTACK_TO_IDLE, not should_jump and not should_run)


func apply_knockback(knockback_direction: Vector2) -> void:
	if knockback_direction.is_zero_approx():
		return

	move_and_collide(knockback_direction.normalized() * HURT_KNOCKBACK_DISTANCE)


func _ready() -> void:
	animation_tree.active = true
	set_weapon_collision_enabled(false)
	change_state(IDLE)


func _physics_process(delta: float) -> void:
	if state == DEAD:
		return

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if not controls_enabled:
		move_and_slide()
		return

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

	if _health.is_hurt_immune():
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
		if collision.get_collider() is DamageableActor:
			take_damage(1, collision.get_normal())


func take_damage(amount: int, knockback_direction: Vector2) -> void:
	if not _health.accept_damage(amount):
		return

	hurt_taken.emit()
	if _health.is_depleted():
		return

	apply_knockback(knockback_direction)
	change_state(HURT)
	await get_tree().create_timer(animation_player.get_animation(HURT_ANIMATION).length).timeout
	_health.end_hurt_immunity()


func _on_health_changed(current_health: int, observed_maximum_health: int) -> void:
	health_changed.emit(current_health, observed_maximum_health)


func _on_health_depleted() -> void:
	change_state(DEAD)
	died.emit()
