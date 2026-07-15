extends Area2D


const IMPACT_TIME := 1.0

var cast_id := 0
var damaged_actors: Array[DamageableActor] = []
var is_cast_active := false


func start_cast() -> void:
	cast_id += 1
	damaged_actors.clear()
	is_cast_active = true
	damage_overlaps_at_impact(cast_id)


func cancel_cast() -> void:
	cast_id += 1
	is_cast_active = false


func damage_overlaps_at_impact(expected_cast_id: int) -> void:
	await get_tree().create_timer(IMPACT_TIME).timeout
	await get_tree().physics_frame
	if not is_cast_active or expected_cast_id != cast_id:
		return

	for body in get_overlapping_bodies():
		damage_body(body)


func _on_body_entered(body: Node2D) -> void:
	damage_body(body)


func damage_body(body: Node2D) -> void:
	var actor := body as DamageableActor
	if (
		not is_cast_active
		or actor == null
		or not is_instance_valid(actor)
	):
		return

	if damaged_actors.has(actor):
		return

	damaged_actors.append(actor)
	actor.take_damage(1, actor.global_position - global_position)


func _on_animation_player_animation_finished(animation_name: StringName) -> void:
	if animation_name == &"cast":
		is_cast_active = false
