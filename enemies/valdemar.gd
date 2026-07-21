extends "res://combat/damageable_actor.gd"


signal health_changed(current_health: int, maximum_health: int)
@warning_ignore("unused_signal")
signal black_water_requested
@warning_ignore("unused_signal")
signal died

const MAXIMUM_HEALTH := 15
const PLAYER_COLLISION_LAYER := 1 << 1
const TRANSFORMATION_ANIMATION := &"transformation"
const ATTACK_ANIMATION := &"attack"
const DEAD_ANIMATION := &"dead"
const HURT_ANIMATION := &"hurt"
const IDLE_ANIMATION := &"idle"
const RUN_ANIMATION := &"run"
const SKILL_ANIMATION := &"skill"
const SWORD_GLEAM_CAST_ANIMATION := &"cast"
const DamageAndHealthModule := preload("res://combat/damage_and_health.gd")

enum Phase { NORMAL_FORM, AWAKENING, DARK_MODE, DEFEATED }
enum DarkAction { PURSUIT, SWORD_GLEAM, HURT, BLACK_WATER_CAST }

@export var awakening_distance := 600.0
@export var pursuit_speed := 150.0

var _phase := Phase.NORMAL_FORM
var _dark_action := DarkAction.PURSUIT
var _health := DamageAndHealthModule.new(MAXIMUM_HEALTH)
var _player: Node2D
var _black_water_pending := false

@onready var _normal: Sprite2D = $Normal
@onready var _dark_mode: Sprite2D = $DarkMode
@onready var _dying: Sprite2D = $Dying
@onready var _body_collision: CollisionShape2D = $CollisionShape2D
@onready var _health_bar_root: Node2D = $HealthBar
@onready var _health_bar: TextureProgressBar = $HealthBar/TextureProgressBar
@onready var _hurt_box_collision: CollisionShape2D = $HurtBox/CollisionShape2D
@onready var _awakening_boundary: Area2D = $AwakeningBoundary
@onready var _awakening_shape: CollisionShape2D = $AwakeningBoundary/CollisionShape2D
@onready var _sword_gleam: Area2D = $SwordGleam
@onready var _sword_gleam_collision: CollisionShape2D = $SwordGleam/CollisionShape2D
@onready var _sword_gleam_animation_player: AnimationPlayer = $SwordGleam/AnimationPlayer
@onready var _sword_gleam_offset_x := absf(_sword_gleam.position.x)
@onready var _sword_gleam_scale_x := absf(_sword_gleam.scale.x)
@onready var _sword_gleam_cooldown: Timer = $SwordGleamCooldown
@onready var _black_water_cooldown: Timer = $BlackWaterCooldown
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _animation_tree: AnimationTree = $AnimationTree
@onready var _animation_state: AnimationNodeStateMachinePlayback = _animation_tree.get(
	"parameters/playback"
)


func _init() -> void:
	_health.health_changed.connect(_on_health_changed)


func _ready() -> void:
	var boundary_shape := _awakening_shape.shape as RectangleShape2D
	boundary_shape.size.x = awakening_distance * 2.0
	_normal.show()
	_dark_mode.hide()
	_health_bar_root.hide()
	_update_health_presentation(
		_health.get_current_health(),
		_health.get_maximum_health()
	)
	_hurt_box_collision.disabled = true
	_sword_gleam_cooldown.stop()
	_black_water_cooldown.stop()
	velocity = Vector2.ZERO
	set_physics_process(false)
	_animation_tree.active = false
	_awakening_boundary.body_entered.connect(_on_awakening_boundary_body_entered)
	_black_water_cooldown.timeout.connect(_on_black_water_cooldown_timeout)


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


func restore_full_health() -> void:
	_health.restore_full_health()


func take_damage(amount: int, _knockback_direction: Vector2) -> void:
	if _phase != Phase.DARK_MODE:
		return

	if (
		amount > 0
		and amount >= _health.get_current_health()
		and _health.is_hurt_immune()
	):
		_health.end_hurt_immunity()
	if not _health.accept_damage(amount):
		return
	if _health.is_depleted():
		_begin_defeat()
		return

	if _dark_action == DarkAction.PURSUIT:
		_dark_action = DarkAction.HURT
		velocity = Vector2.ZERO
		_animation_state.start(HURT_ANIMATION)

	await get_tree().create_timer(
		_animation_player.get_animation(HURT_ANIMATION).length
	).timeout
	_health.end_hurt_immunity()
	if _phase == Phase.DARK_MODE and _dark_action == DarkAction.HURT:
		_finish_dark_action()


func _on_hurt_box_area_entered(area: Area2D) -> void:
	if not area.is_in_group("weapons"):
		return

	take_damage(1, global_position - area.global_position)


func _on_awakening_boundary_body_entered(body: Node2D) -> void:
	var collision_body := body as CollisionObject2D
	if (
		_phase != Phase.NORMAL_FORM
		or collision_body == null
		or collision_body.collision_layer & PLAYER_COLLISION_LAYER == 0
	):
		return

	_phase = Phase.AWAKENING
	_player = body
	_awakening_boundary.set_deferred("monitoring", false)
	_animation_tree.active = true
	_animation_state.start(TRANSFORMATION_ANIMATION)
	await get_tree().create_timer(
		_animation_player.get_animation(TRANSFORMATION_ANIMATION).length
	).timeout
	if _phase == Phase.AWAKENING:
		_enter_dark_mode()


func _enter_dark_mode() -> void:
	_phase = Phase.DARK_MODE
	_animation_state.start(IDLE_ANIMATION)
	_animation_tree.advance(0.0)
	_normal.hide()
	_dark_mode.show()
	_update_health_presentation(
		_health.get_current_health(),
		_health.get_maximum_health()
	)
	_health_bar_root.show()
	_hurt_box_collision.disabled = false
	_black_water_cooldown.start()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _dark_action == DarkAction.PURSUIT:
		if _black_water_pending:
			_start_black_water_cast()
		elif (
			not _black_water_cooldown.is_stopped()
			and _black_water_cooldown.time_left <= delta
		):
			velocity = Vector2.ZERO
		else:
			if not is_on_floor():
				velocity += get_gravity() * delta
			_update_sword_pursuit(delta)
	else:
		velocity = Vector2.ZERO
	move_and_slide()


func _update_sword_pursuit(delta: float) -> void:
	if not is_instance_valid(_player):
		velocity.x = 0.0
		_play_movement_animation(IDLE_ANIMATION)
		return

	_face_player()
	var target_x := _player.global_position.x - _sword_gleam.position.x
	var distance_to_target := target_x - global_position.x
	var maximum_step := pursuit_speed * delta
	if absf(distance_to_target) <= maximum_step:
		global_position.x = target_x
		velocity.x = 0.0
		if _sword_gleam_cooldown.is_stopped():
			_start_sword_gleam()
		else:
			_play_movement_animation(IDLE_ANIMATION)
		return

	velocity.x = signf(distance_to_target) * pursuit_speed
	_play_movement_animation(RUN_ANIMATION)


func _face_player() -> void:
	var direction := signf(_player.global_position.x - global_position.x)
	if is_zero_approx(direction):
		return

	_dark_mode.flip_h = direction > 0.0
	_sword_gleam.position.x = _sword_gleam_offset_x * direction
	_sword_gleam.scale.x = -_sword_gleam_scale_x * direction


func _play_movement_animation(animation_name: StringName) -> void:
	if _animation_state.get_current_node() != animation_name:
		_animation_state.travel(animation_name)


func _start_sword_gleam() -> void:
	_dark_action = DarkAction.SWORD_GLEAM
	velocity = Vector2.ZERO
	_sword_gleam_cooldown.start()
	_animation_state.start(ATTACK_ANIMATION)
	_sword_gleam_animation_player.play(SWORD_GLEAM_CAST_ANIMATION)
	await get_tree().create_timer(
		_animation_player.get_animation(ATTACK_ANIMATION).length
	).timeout
	if _phase == Phase.DARK_MODE and _dark_action == DarkAction.SWORD_GLEAM:
		_finish_dark_action()


func _on_black_water_cooldown_timeout() -> void:
	if _phase != Phase.DARK_MODE:
		return

	_black_water_pending = true
	if _dark_action == DarkAction.PURSUIT:
		_start_black_water_cast()


func _start_black_water_cast() -> void:
	_black_water_pending = false
	_dark_action = DarkAction.BLACK_WATER_CAST
	velocity = Vector2.ZERO
	if is_instance_valid(_player):
		_face_player()
	_black_water_cooldown.start()
	_animation_state.start(SKILL_ANIMATION)
	black_water_requested.emit()
	await get_tree().create_timer(
		_animation_player.get_animation(SKILL_ANIMATION).length
	).timeout
	if _phase == Phase.DARK_MODE and _dark_action == DarkAction.BLACK_WATER_CAST:
		_finish_dark_action()


func _finish_dark_action() -> void:
	if _black_water_pending:
		_start_black_water_cast()
	else:
		_dark_action = DarkAction.PURSUIT
		_animation_state.start(IDLE_ANIMATION)


func _begin_defeat() -> void:
	if _phase == Phase.DEFEATED:
		return

	_phase = Phase.DEFEATED
	_dark_action = DarkAction.PURSUIT
	_black_water_pending = false
	velocity = Vector2.ZERO
	set_physics_process(false)
	remove_from_group("enemies")
	_health_bar_root.hide()
	_sword_gleam_cooldown.stop()
	_black_water_cooldown.stop()
	_sword_gleam.call("cancel_cast")
	_sword_gleam_animation_player.stop()
	_sword_gleam.hide()
	_dying.flip_h = _dark_mode.flip_h

	collision_layer = 0
	collision_mask = 0
	$HurtBox.collision_layer = 0
	$HurtBox.collision_mask = 0
	_sword_gleam.collision_layer = 0
	_sword_gleam.collision_mask = 0
	_awakening_boundary.collision_layer = 0
	_awakening_boundary.collision_mask = 0
	_body_collision.set_deferred("disabled", true)
	_hurt_box_collision.set_deferred("disabled", true)
	_sword_gleam_collision.set_deferred("disabled", true)
	_awakening_boundary.set_deferred("monitoring", false)
	_sword_gleam.set_deferred("monitoring", false)

	_animation_state.start(DEAD_ANIMATION)
	_animation_tree.advance(0.0)
	var finished_animation: StringName = await _animation_tree.animation_finished
	if _phase != Phase.DEFEATED or finished_animation != DEAD_ANIMATION:
		return

	_animation_tree.active = false
	died.emit()


func _on_health_changed(current_health: int, maximum_health: int) -> void:
	_update_health_presentation(current_health, maximum_health)
	health_changed.emit(current_health, maximum_health)


func _update_health_presentation(current_health: int, maximum_health: int) -> void:
	_health_bar.max_value = maximum_health
	_health_bar.value = current_health
