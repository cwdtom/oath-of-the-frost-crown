extends SceneTree


const LEVEL_04_SCENE := preload("res://levels/level_04.tscn")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const PLAYER_HURT_IMMUNITY_WAIT := 1.55

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	var level := fixture.instantiate_scene(LEVEL_04_SCENE) as CampaignLevel
	level.call("set_pre_awakening_story_enabled", false)
	fixture.set_current_scene(level)
	await fixture.process_frames(2)
	fixture.set_paused(false)

	await test_request_restarts_field_cast(level)
	await test_field_persists_player_contact_damage(level)

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func test_request_restarts_field_cast(level: CampaignLevel) -> void:
	var valdemar := level.get_node("Enemies/Valdemar") as DamageableActor
	var black_water := level.get_node("BlackWater") as Area2D
	var animation_player := black_water.get_node("AnimationPlayer") as AnimationPlayer
	var sprite := black_water.get_node("Sprite2D") as Sprite2D
	var collision_shape := black_water.get_node("CollisionShape2D") as CollisionShape2D
	var rest_field_y := black_water.global_position.y
	var sprite_offset_y := sprite.global_position.y - rest_field_y
	var collision_offset_y := collision_shape.global_position.y - rest_field_y

	fixture.expect(
		black_water.visible
		and not animation_player.is_playing()
		and is_equal_approx(black_water.position.y, 571.0),
		"Black Water Field rests below playable ground between casts"
	)
	valdemar.emit_signal(&"black_water_requested")
	await fixture.process_frames(1)
	fixture.expect(
		animation_player.current_animation == &"cast"
		and animation_player.is_playing()
		and animation_player.current_animation_position < 0.1,
		"Valdemar request starts the existing Black Water Field cast"
	)

	animation_player.advance(2.0)
	fixture.expect(
		animation_player.current_animation_position >= 2.0
		and black_water.global_position.y < rest_field_y
		and is_equal_approx(
			sprite.global_position.y - black_water.global_position.y,
			sprite_offset_y
		)
		and is_equal_approx(
			collision_shape.global_position.y - black_water.global_position.y,
			collision_offset_y
		),
		"Black Water Field cast moves its presentation and collision range together"
	)
	valdemar.emit_signal(&"black_water_requested")
	fixture.expect(
		animation_player.current_animation == &"cast"
		and animation_player.current_animation_position < 0.1,
		"Each Valdemar request restarts exactly one Black Water Field cast"
	)


func test_field_persists_player_contact_damage(level: CampaignLevel) -> void:
	var player := level.get_node("Player") as DamageableActor
	var valdemar := level.get_node("Enemies/Valdemar") as DamageableActor
	var black_water := level.get_node("BlackWater") as Area2D
	var field_animation_player := black_water.get_node("AnimationPlayer") as AnimationPlayer
	var shield_animation_player := player.get_node(
		"VisualRoot/ShieldSkill/Shield/AnimationPlayer"
	) as AnimationPlayer
	var shield_break_duration := shield_animation_player.get_animation(&"break").length
	var hurt_event_count: Array[int] = [0]
	player.connect(&"hurt_taken", func() -> void: hurt_event_count[0] += 1)
	player.set_physics_process(false)
	(level.get_node("TileMapLayer") as TileMapLayer).collision_enabled = false
	await fixture.physics_frames(1)

	valdemar.emit_signal(&"black_water_requested")
	field_animation_player.advance(2.0)
	var overlapping_position := black_water.global_position + Vector2(200.0, -20.0)
	player.global_position = overlapping_position
	var maximum_health := int(player.call("get_maximum_health"))
	var valdemar_health := int(valdemar.call("get_current_health"))
	await fixture.physics_frames(4)
	fixture.expect(
		player.call("get_current_health") == maximum_health
		and hurt_event_count[0] == 0
		and shield_animation_player.current_animation == &"break",
		(
			"Black Water Field contact is absorbed by the available Player Shield; "
			+ "health=%s hurt_events=%s shield_animation=%s"
			% [
				player.call("get_current_health"),
				hurt_event_count[0],
				shield_animation_player.current_animation,
			]
		)
	)

	await fixture.wait_seconds(shield_break_duration + 0.1)
	await fixture.physics_frames(2)
	fixture.expect(
		player.call("get_current_health") == maximum_health - 1
		and hurt_event_count[0] == 1,
		"Uninterrupted field contact damages Player after the Shield Break Window"
	)
	fixture.expect(
		player.global_position.x > overlapping_position.x + 90.0,
		"Black Water Field damage uses ordinary source-relative knockback; player_x=%s"
		% player.global_position.x
	)

	await fixture.wait_seconds(PLAYER_HURT_IMMUNITY_WAIT)
	await fixture.physics_frames(2)
	fixture.expect(
		player.call("get_current_health") == maximum_health - 2
		and hurt_event_count[0] == 2,
		(
			"Uninterrupted field contact damages Player again after hurt immunity; "
			+ "health=%s hurt_events=%s field_time=%s player_position=%s"
			% [
				player.call("get_current_health"),
				hurt_event_count[0],
				field_animation_player.current_animation_position,
				player.global_position,
			]
		)
	)
	fixture.expect(
		valdemar.call("get_current_health") == valdemar_health,
		"Black Water Field collision filtering does not damage Valdemar"
	)

	player.global_position = black_water.global_position + Vector2(2000.0, -20.0)
	var health_after_separation := int(player.call("get_current_health"))
	await fixture.wait_seconds(PLAYER_HURT_IMMUNITY_WAIT)
	await fixture.physics_frames(2)
	fixture.expect(
		player.call("get_current_health") == health_after_separation
		and hurt_event_count[0] == 2,
		(
			"Separating from the Black Water Field stops persistent contact damage; "
			+ "health=%s hurt_events=%s"
			% [player.call("get_current_health"), hurt_event_count[0]]
		)
	)

	player.global_position = black_water.global_position + Vector2(200.0, -20.0)
	await fixture.physics_frames(4)
	fixture.expect(
		player.call("get_current_health") == health_after_separation - 1
		and hurt_event_count[0] == 3,
		"Later Black Water Field contact resumes persistent Player damage"
	)
	await fixture.wait_seconds(PLAYER_HURT_IMMUNITY_WAIT)
