extends "res://combat/damageable_actor.gd"


signal health_changed(current_health: int, maximum_health: int)
@warning_ignore("unused_signal")
signal black_water_requested
@warning_ignore("unused_signal")
signal died

const MAXIMUM_HEALTH := 15
const PLAYER_COLLISION_LAYER := 1 << 1
const TRANSFORMATION_ANIMATION := &"transformation"
const IDLE_ANIMATION := &"idle"
const DamageAndHealthModule := preload("res://combat/damage_and_health.gd")

enum Phase { NORMAL_FORM, AWAKENING, DARK_MODE }

@export var awakening_distance := 600.0

var _phase := Phase.NORMAL_FORM
var _health := DamageAndHealthModule.new(MAXIMUM_HEALTH)

@onready var _normal: Sprite2D = $Normal
@onready var _dark_mode: Sprite2D = $DarkMode
@onready var _health_bar_root: Node2D = $HealthBar
@onready var _health_bar: TextureProgressBar = $HealthBar/TextureProgressBar
@onready var _hurt_box_collision: CollisionShape2D = $HurtBox/CollisionShape2D
@onready var _awakening_boundary: Area2D = $AwakeningBoundary
@onready var _awakening_shape: CollisionShape2D = $AwakeningBoundary/CollisionShape2D
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

	_health.accept_damage(amount)


func _on_awakening_boundary_body_entered(body: Node2D) -> void:
	var collision_body := body as CollisionObject2D
	if (
		_phase != Phase.NORMAL_FORM
		or collision_body == null
		or collision_body.collision_layer & PLAYER_COLLISION_LAYER == 0
	):
		return

	_phase = Phase.AWAKENING
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
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()


func _on_health_changed(current_health: int, maximum_health: int) -> void:
	_update_health_presentation(current_health, maximum_health)
	health_changed.emit(current_health, maximum_health)


func _update_health_presentation(current_health: int, maximum_health: int) -> void:
	_health_bar.max_value = maximum_health
	_health_bar.value = current_health
