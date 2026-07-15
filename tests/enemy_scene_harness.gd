class_name EnemySceneHarness
extends RefCounted


const ENEMY_COLLISION_LAYER := 1 << 2
const PLAYER_COLLISION_LAYER := 1 << 1
const PLAYER_SCENE := preload("res://player/player.tscn")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")

var world: Node2D
var fixture: HeadlessGameplayFixture
var _owns_fixture := false


func _init(owner: Variant, test_world: Node2D = null) -> void:
	if owner is SceneTree:
		fixture = HeadlessGameplayFixture.new(owner as SceneTree)
		_owns_fixture = true
	else:
		fixture = owner as HeadlessGameplayFixture

	if test_world == null:
		world = fixture.add_node(Node2D.new()) as Node2D
		fixture.set_current_scene(world)
	else:
		world = test_world


func instantiate_enemy(
	scene: PackedScene,
	position: Vector2,
	properties: Dictionary = {}
) -> CharacterBody2D:
	var enemy := scene.instantiate() as CharacterBody2D
	enemy.position = position
	for property in properties:
		enemy.set(property, properties[property])
	fixture.add_node(enemy, world)
	return enemy


func instantiate_actor(scene: PackedScene, position: Vector2) -> CharacterBody2D:
	var actor := scene.instantiate() as CharacterBody2D
	actor.position = position
	fixture.add_node(actor, world)
	return actor


func instantiate_passive_player(position: Vector2, hurt_callback: Callable) -> CharacterBody2D:
	var player := instantiate_actor(PLAYER_SCENE, position)
	player.set_physics_process(false)
	player.connect(&"hurt_taken", hurt_callback)
	return player


func add_body(position: Vector2, size := Vector2(20.0, 20.0)) -> CharacterBody2D:
	var body := CharacterBody2D.new()
	body.collision_layer = PLAYER_COLLISION_LAYER
	body.collision_mask = 0
	body.position = position
	body.add_child(_create_collision_shape(size))
	fixture.add_node(body, world)
	return body


func add_weapon(position: Vector2, size := Vector2(32.0, 32.0)) -> Area2D:
	var weapon := Area2D.new()
	weapon.collision_layer = PLAYER_COLLISION_LAYER
	weapon.collision_mask = ENEMY_COLLISION_LAYER
	weapon.position = position
	weapon.add_to_group("weapons")
	weapon.add_child(_create_collision_shape(size))
	fixture.add_node(weapon, world)
	return weapon


func add_environment_wall(position: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = position
	wall.add_child(_create_collision_shape(size))
	fixture.add_node(wall, world)
	return wall


func enemy_has_body_collision(enemy: CharacterBody2D) -> bool:
	return _enemy_has_collision(enemy, false, true)


func enemy_has_hurt_collision(enemy: CharacterBody2D) -> bool:
	return _enemy_has_collision(enemy, true, false)


func enemy_sprite_is_flipped(enemy: CharacterBody2D) -> bool:
	var sprite := _enemy_sprite(enemy)
	return sprite != null and sprite.flip_h


func enemy_sprite_texture(enemy: CharacterBody2D) -> Texture2D:
	var sprite := _enemy_sprite(enemy)
	return sprite.texture if sprite != null else null


func enemy_health_bar(enemy: CharacterBody2D) -> TextureProgressBar:
	for node in enemy.find_children("*", "TextureProgressBar", true, false):
		return node as TextureProgressBar

	return null


func remove_actor(actor: Node) -> void:
	if is_instance_valid(actor):
		actor.queue_free()


func deliver_hit(enemy: CharacterBody2D, offset := Vector2.ZERO) -> void:
	var weapon := add_weapon(enemy.global_position + offset)
	await physics_frames(3)
	await fixture.process_frames(1)
	remove_actor(weapon)
	await physics_frames(2)
	await fixture.process_frames(1)


func reenter_skill_detection(actor: CharacterBody2D, detection_position: Vector2) -> void:
	actor.position = detection_position + Vector2(400.0, 0.0)
	await physics_frames(2)
	actor.position = detection_position
	await physics_frames(2)
	await fixture.wait_seconds(0.05)


func physics_frames(count: int) -> void:
	await fixture.physics_frames(count)


func is_playing(enemy: CharacterBody2D, animation_name: StringName) -> bool:
	return bool(enemy.call("_is_playing_animation", animation_name))


func animation_position(enemy: CharacterBody2D, animation_name: StringName) -> float:
	return float(enemy.call("_get_animation_position", animation_name))


func cleanup() -> void:
	if _owns_fixture:
		fixture.complete(false)


func _create_collision_shape(size: Vector2) -> CollisionShape2D:
	var collision_shape := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision_shape.shape = shape
	return collision_shape


func _enemy_sprite(enemy: CharacterBody2D) -> Sprite2D:
	for child in enemy.get_children():
		var sprite := child as Sprite2D
		if sprite != null:
			return sprite

	return null


func _enemy_has_collision(
	enemy: CharacterBody2D,
	collide_with_areas: bool,
	collide_with_bodies: bool
) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = enemy.global_position
	query.collision_mask = ENEMY_COLLISION_LAYER
	query.collide_with_areas = collide_with_areas
	query.collide_with_bodies = collide_with_bodies
	for result in world.get_world_2d().direct_space_state.intersect_point(query, 32):
		var collider := result["collider"] as Node
		if collider == enemy or (collider != null and enemy.is_ancestor_of(collider)):
			return true

	return false
