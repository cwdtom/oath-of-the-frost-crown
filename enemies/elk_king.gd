extends "res://enemies/elk.gd"


signal died

const ELK_KING_MAX_HEALTH := 10
const EARTHQUAKE_CAST_ANIMATION := &"cast"

@onready var _health_bar: TextureProgressBar = $HealthBar/TextureProgressBar
@onready var _earthquake: Area2D = $SkillDetect/EarthquakeSkill/Earthquake
@onready var _earthquake_animation_player: AnimationPlayer = (
	$SkillDetect/EarthquakeSkill/Earthquake/AnimationPlayer
)
@onready var _earthquake_cooldown_timer: Timer = $SkillDetect/EarthquakeSkill/Cooldown
@onready var _earthquake_cast_offset_x := absf(_earthquake.position.x)

var _thunder_cast_active := false
var _earthquake_cast_active := false
var _earthquake_presentation_active := false


func _ready() -> void:
	super._ready()
	_earthquake_cooldown_timer.timeout.connect(_try_start_skill)
	_earthquake_animation_player.animation_finished.connect(
		_on_earthquake_animation_finished
	)
	_thunder_animation_player.animation_finished.connect(_on_thunder_animation_finished)


func _get_max_health() -> int:
	return ELK_KING_MAX_HEALTH


func _update_health_presentation(current_health: int, maximum_health: int) -> void:
	_health_bar.max_value = maximum_health
	_health_bar.value = current_health


func _prepare_death_presentation() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	died.emit()


func _play_skill_presentations() -> void:
	if state == SKILL:
		_update_casting_presentation()


func _try_start_skill() -> void:
	if (
		state == DEAD
		or state == HURT
		or is_hurt_immune()
		or not skill_detect.has_overlapping_bodies()
	):
		return

	var should_start_thunder := (
		not _thunder_cast_active and skill_cooldown_timer.is_stopped()
	)
	var should_start_earthquake := (
		not _earthquake_cast_active and _earthquake_cooldown_timer.is_stopped()
	)
	if not should_start_thunder and not should_start_earthquake:
		return

	if state != SKILL:
		skill_return_state = state
		change_state(SKILL)
	if should_start_thunder:
		_start_thunder_cast()
	if should_start_earthquake:
		_start_earthquake_cast()
	_update_casting_presentation()


func _start_thunder_cast() -> void:
	_thunder_cast_active = true
	skill_cooldown_timer.start()
	_cast_thunder()


func _start_earthquake_cast() -> void:
	_earthquake_cast_active = true
	_earthquake_presentation_active = true
	_earthquake_cooldown_timer.start()
	_earthquake.global_position.x = (
		global_position.x + move_direction * _earthquake_cast_offset_x
	)
	_earthquake_animation_player.stop()
	_earthquake_animation_player.play(EARTHQUAKE_CAST_ANIMATION)
	_finish_earthquake_presentation()


func _finish_earthquake_presentation() -> void:
	await get_tree().create_timer(_get_animation_length(SKILL_ANIMATION)).timeout
	_earthquake_presentation_active = false
	_update_casting_presentation()


func _update_casting_presentation() -> void:
	if state != SKILL:
		return

	animation_state.travel(
		SKILL_ANIMATION if _earthquake_presentation_active else IDLE_ANIMATION
	)


func _on_thunder_animation_finished(animation_name: StringName) -> void:
	if animation_name != THUNDER_CAST_ANIMATION:
		return

	_thunder_cast_active = false
	_finish_casting_window_if_complete()


func _on_earthquake_animation_finished(animation_name: StringName) -> void:
	if animation_name != EARTHQUAKE_CAST_ANIMATION:
		return

	_earthquake_cast_active = false
	_earthquake_presentation_active = false
	_update_casting_presentation()
	_finish_casting_window_if_complete()


func _finish_casting_window_if_complete() -> void:
	if state == SKILL and not _thunder_cast_active and not _earthquake_cast_active:
		finish_skill()


func _get_skill_cooldown_timer() -> Timer:
	return $SkillDetect/ThunderSkill/Cooldown


func _get_thunder() -> Area2D:
	return $SkillDetect/ThunderSkill/Thunder
