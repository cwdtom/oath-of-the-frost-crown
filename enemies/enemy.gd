extends "res://combat/damageable_actor.gd"


signal health_changed(current_health: int, maximum_health: int)

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
const DamageAndHealthModule := preload("res://combat/damage_and_health.gd")

enum {IDLE, RUN, HURT, DEAD, SKILL}

var state := -1
var _health: DamageAndHealth
var start_x := 0.0
var move_direction := 0.0
var idle_time_left := 0.0
var skill_return_state: int = IDLE
var skill_detect_offset_x := 0.0
var _moving_skill_distance_left := 0.0
var _has_pending_depletion_outcome := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_state: AnimationNodeStateMachinePlayback = animation_tree.get(
	"parameters/playback"
)
@onready var body_collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hurt_box_collision_shape: CollisionShape2D = $HurtBox/CollisionShape2D
@onready var skill_detect: Area2D = $SkillDetect
@onready var skill_detect_collision_shape: CollisionShape2D = $SkillDetect/CollisionShape2D
@onready var skill_cooldown_timer: Timer = _get_skill_cooldown_timer()


func _ready() -> void:
	_health = DamageAndHealthModule.new(_get_max_health())
	_health.health_changed.connect(_on_health_changed)
	_health.depleted.connect(_on_health_depleted)
	animation_tree.active = true
	start_x = global_position.x
	move_direction = _get_initial_move_direction()
	skill_detect_offset_x = absf(skill_detect_collision_shape.position.x)
	skill_cooldown_timer.timeout.connect(_try_start_skill)
	change_state(IDLE)
	_update_health_presentation(
		_health.get_current_health(),
		_health.get_maximum_health()
	)


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
			animation_state.travel(_get_run_animation())
		HURT:
			velocity.x = 0.0
			hurt_box_collision_shape.set_deferred("disabled", false)
			animation_state.travel(HURT_ANIMATION)
		SKILL:
			velocity.x = 0.0
			hurt_box_collision_shape.set_deferred(
				"disabled",
				_blocks_weapon_damage_during_skill()
			)
			face_move_direction()
			call_deferred("_play_skill_presentations")
		DEAD:
			velocity = Vector2.ZERO
			remove_from_group("enemies")
			body_collision_shape.set_deferred("disabled", true)
			hurt_box_collision_shape.set_deferred("disabled", true)
			if _starts_death_presentation_on_defeat():
				_start_death_presentation()


func face_move_direction() -> void:
	sprite.flip_h = _get_sprite_flip(move_direction)
	skill_detect_collision_shape.position.x = skill_detect_offset_x * move_direction


func _get_initial_move_direction() -> float:
	return -1.0


func _get_max_health() -> int:
	return 0


func _get_sprite_flip(direction: float) -> bool:
	return direction > 0.0


func _get_run_animation() -> StringName:
	return RUN_ANIMATION


func _get_skill_animation() -> StringName:
	return SKILL_ANIMATION


func _get_skill_cooldown_timer() -> Timer:
	return $SkillDetect/Cooldown


func _get_moving_skill_distance() -> float:
	return 0.0


func _get_moving_skill_speed() -> float:
	return 0.0


func _get_wall_check_distance() -> float:
	return WALL_CHECK_DISTANCE


func _is_playing_animation(animation_name: StringName) -> bool:
	return (
		_get_species_animation_position(animation_name) >= 0.0
		or animation_state.get_current_node() == animation_name
	)


func _get_animation_position(animation_name: StringName) -> float:
	var species_position := _get_species_animation_position(animation_name)
	if species_position >= 0.0:
		return species_position

	if animation_state.get_current_node() != animation_name:
		return -1.0

	return animation_state.get_current_play_position()


func _get_species_animation_position(_animation_name: StringName) -> float:
	return -1.0


func _get_animation_length(animation_name: StringName) -> float:
	return animation_player.get_animation(animation_name).length


func _play_skill_presentations() -> void:
	if state != SKILL:
		return

	animation_state.travel(_get_skill_animation())
	_play_species_skill_presentation()


func _play_species_skill_presentation() -> void:
	pass


func _stop_species_skill_presentation() -> void:
	pass


func _start_species_skill() -> void:
	var moving_distance := _get_moving_skill_distance()
	if moving_distance > 0.0:
		_moving_skill_distance_left = moving_distance
		return

	await get_tree().create_timer(_get_animation_length(SKILL_ANIMATION)).timeout
	if state == SKILL:
		finish_skill()


func _update_species_skill(delta: float) -> void:
	if _moving_skill_distance_left <= 0.0:
		return

	var travel_distance := minf(
		_get_moving_skill_speed() * delta,
		_moving_skill_distance_left
	)
	velocity.x = move_direction * travel_distance / delta
	_moving_skill_distance_left -= travel_distance


func _handle_species_skill_collisions() -> void:
	pass


func _is_species_skill_complete() -> bool:
	return _get_moving_skill_distance() > 0.0 and _moving_skill_distance_left <= 0.0


func _blocks_weapon_damage_during_skill() -> bool:
	return false


func _get_hurt_knockback_distance() -> float:
	return HURT_KNOCKBACK_DISTANCE


func _get_hurt_return_state() -> int:
	return skill_return_state if state == SKILL else state


func _prepare_hurt(_knockback_direction: Vector2) -> void:
	pass


func _update_health_presentation(_current_health: int, _maximum_health: int) -> void:
	pass


func _prepare_death_presentation() -> void:
	pass


func _start_death_presentation() -> void:
	animation_state.start(DEAD_ANIMATION)


func _starts_death_presentation_on_defeat() -> bool:
	return true


func turn_around() -> void:
	move_direction *= -1.0
	face_move_direction()
	velocity.x = move_direction * run_speed


func is_front_blocked() -> bool:
	var space_state := get_world_2d().direct_space_state
	var world_scale := global_transform.get_scale()
	var check_distance: float = _get_wall_check_distance() * absf(world_scale.x)
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

	var knockback_distance := _get_hurt_knockback_distance()
	if is_zero_approx(knockback_distance):
		return

	move_and_collide(knockback_direction.normalized() * knockback_distance)


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
	_start_species_skill()


func finish_skill() -> void:
	if _get_moving_skill_distance() > 0.0:
		velocity.x = 0.0
		start_x = global_position.x
	change_state(skill_return_state)
	_try_start_skill()


func _physics_process(delta: float) -> void:
	if state == DEAD:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if _health.is_hurt_immune():
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
			_update_species_skill(delta)

	move_and_slide()
	if state == RUN:
		turn_around_from_environment_collision()
	if was_using_skill and state == SKILL:
		_handle_species_skill_collisions()
	if was_using_skill and state == SKILL and _is_species_skill_complete():
		finish_skill()


func _on_hurt_box_area_entered(area: Area2D) -> void:
	if (
		state == DEAD
		or (state == SKILL and _blocks_weapon_damage_during_skill())
		or not area.is_in_group("weapons")
	):
		return

	take_damage(1, global_position - area.global_position)


func _on_skill_detect_body_entered(_body: Node2D) -> void:
	_try_start_skill()


func _try_start_skill() -> void:
	if (
		state == DEAD
		or state == SKILL
		or _health.is_hurt_immune()
		or not skill_cooldown_timer.is_stopped()
		or not skill_detect.has_overlapping_bodies()
	):
		return

	start_skill()


func take_damage(amount: int, knockback_direction: Vector2) -> void:
	if not _health.accept_damage(amount):
		return

	_prepare_hurt(knockback_direction)
	if _has_pending_depletion_outcome:
		_has_pending_depletion_outcome = false
		die()
		return

	if state == SKILL:
		await get_tree().create_timer(_get_animation_length(HURT_ANIMATION)).timeout
		_health.end_hurt_immunity()
		_try_start_skill()
		return

	var return_state := _get_hurt_return_state()
	apply_knockback(knockback_direction)
	change_state(HURT)
	await get_tree().create_timer(_get_animation_length(HURT_ANIMATION)).timeout
	_health.end_hurt_immunity()
	change_state(return_state)
	_try_start_skill()


func _on_health_changed(current_health: int, maximum_health: int) -> void:
	health_changed.emit(current_health, maximum_health)
	_update_health_presentation(current_health, maximum_health)


func _on_health_depleted() -> void:
	_has_pending_depletion_outcome = true


func die() -> void:
	if state == DEAD:
		return

	change_state(DEAD)
	_prepare_death_presentation()
	await get_tree().create_timer(_get_animation_length(DEAD_ANIMATION)).timeout
	queue_free()
