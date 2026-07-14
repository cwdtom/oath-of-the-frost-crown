class_name EnemySceneHarness
extends RefCounted


const ENEMY_COLLISION_LAYER := 1 << 2
const PLAYER_COLLISION_LAYER := 1 << 1

var world := Node2D.new()


func _init(test_scene_tree: SceneTree) -> void:
	test_scene_tree.root.add_child(world)


func instantiate_enemy(
	scene: PackedScene,
	position: Vector2,
	properties: Dictionary = {}
) -> CharacterBody2D:
	var enemy := scene.instantiate() as CharacterBody2D
	enemy.position = position
	for property in properties:
		enemy.set(property, properties[property])
	world.add_child(enemy)
	return enemy


func instantiate_actor(scene: PackedScene, position: Vector2) -> CharacterBody2D:
	var actor := scene.instantiate() as CharacterBody2D
	actor.position = position
	world.add_child(actor)
	return actor


func add_body(position: Vector2, size := Vector2(20.0, 20.0)) -> CharacterBody2D:
	var body := CharacterBody2D.new()
	body.collision_layer = PLAYER_COLLISION_LAYER
	body.collision_mask = 0
	body.position = position
	body.add_child(_create_collision_shape(size))
	world.add_child(body)
	return body


func add_weapon(position: Vector2, size := Vector2(32.0, 32.0)) -> Area2D:
	var weapon := Area2D.new()
	weapon.collision_layer = PLAYER_COLLISION_LAYER
	weapon.collision_mask = ENEMY_COLLISION_LAYER
	weapon.position = position
	weapon.add_to_group("weapons")
	weapon.add_child(_create_collision_shape(size))
	world.add_child(weapon)
	return weapon


func add_environment_wall(position: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = position
	wall.add_child(_create_collision_shape(size))
	world.add_child(wall)
	return wall


func enemy_has_body_collision(enemy: CharacterBody2D) -> bool:
	return _enemy_has_collision(enemy, false, true)


func enemy_has_hurt_collision(enemy: CharacterBody2D) -> bool:
	return _enemy_has_collision(enemy, true, false)


func remove_actor(actor: Node) -> void:
	if is_instance_valid(actor):
		actor.queue_free()


func cleanup() -> void:
	if is_instance_valid(world):
		world.queue_free()


func _create_collision_shape(size: Vector2) -> CollisionShape2D:
	var collision_shape := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision_shape.shape = shape
	return collision_shape


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
