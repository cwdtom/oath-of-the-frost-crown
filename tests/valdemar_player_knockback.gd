extends SceneTree


const LEVEL_04_SCENE := preload("res://levels/level_04.tscn")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	await test_sword_gleam_knocks_player_horizontally_away_from_valdemar()
	await test_contact_knocks_player_horizontally_away_from_valdemar()

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func test_sword_gleam_knocks_player_horizontally_away_from_valdemar() -> void:
	var level := fixture.instantiate_scene(LEVEL_04_SCENE) as CampaignLevel
	fixture.set_current_scene(level)
	await fixture.process_frames(2)
	fixture.set_paused(false)

	var player := level.get_node("Player") as DamageableActor
	(player.get_node("VisualRoot/ShieldSkill/Shield") as CanvasItem).hide()
	player.global_position = Vector2(4800.0, 200.0)
	await wait_until_grounded(player)

	var health_before := int(player.call("get_current_health"))
	var position_before_hit := player.global_position
	for _frame in 300:
		position_before_hit = player.global_position
		await fixture.physics_frames(1)
		if int(player.call("get_current_health")) < health_before:
			break

	var displacement := player.global_position - position_before_hit
	fixture.expect(
		player.call("get_current_health") == health_before - 1,
		"Valdemar Sword Gleam damages the grounded Player"
	)
	fixture.expect(
		displacement.x < -90.0 and absf(displacement.y) < 1.0,
		"Valdemar Sword Gleam knocks Player horizontally away; displacement=%s"
		% displacement
	)

	await fixture.wait_seconds(1.0)
	fixture.set_current_scene(null)
	level.free()
	await fixture.process_frames(1)


func test_contact_knocks_player_horizontally_away_from_valdemar() -> void:
	var level := fixture.instantiate_scene(LEVEL_04_SCENE) as CampaignLevel
	fixture.set_current_scene(level)
	await fixture.process_frames(2)
	fixture.set_paused(false)

	var player := level.get_node("Player") as DamageableActor
	var valdemar := level.get_node("Enemies/Valdemar") as DamageableActor
	var awakening_boundary := valdemar.get_node("AwakeningBoundary") as Area2D
	awakening_boundary.set_deferred("monitoring", false)
	(player.get_node("VisualRoot/ShieldSkill/Shield") as CanvasItem).hide()
	await fixture.physics_frames(2)
	player.global_position = valdemar.global_position + Vector2(-150.0, -200.0)
	await wait_until_grounded(player)

	var health_before := int(player.call("get_current_health"))
	var position_before_hit := player.global_position
	Input.action_press("right")
	for _frame in 60:
		position_before_hit = player.global_position
		await fixture.physics_frames(1)
		if int(player.call("get_current_health")) < health_before:
			break
	Input.action_release("right")

	var displacement := player.global_position - position_before_hit
	fixture.expect(
		player.call("get_current_health") == health_before - 1,
		"Physical Valdemar contact damages the grounded Player"
	)
	fixture.expect(
		displacement.x < -90.0,
		"Physical Valdemar contact knocks Player horizontally away; displacement=%s"
		% displacement
	)

	await fixture.wait_seconds(1.0)
	fixture.set_current_scene(null)
	level.free()
	await fixture.process_frames(1)


func wait_until_grounded(player: CharacterBody2D) -> void:
	for _frame in 120:
		await fixture.physics_frames(1)
		if player.is_on_floor():
			return
	fixture.expect(false, "Player lands on Level 04 terrain before combat")
