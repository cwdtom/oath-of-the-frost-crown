extends SceneTree


const BEAR_SCENE := preload("res://enemies/bear.tscn")
const WOLF_SCENE := preload("res://enemies/wolf.tscn")
const LEVEL_01_SCENE := preload("res://levels/level_01.tscn")
const LEVEL_02_SCENE := preload("res://levels/level_02.tscn")
const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")

const ACTOR_SPECS := [
	{
		"name": "Player",
		"scene": LEVEL_01_SCENE,
		"actor_path": NodePath("Player"),
		"maximum_health": 5,
		"hurt_recovery": 0.95,
		"death_signal": &"died",
		"campaign_outcome": CampaignLevel.OUTCOME_DEFEAT,
		"presentation": &"hud",
		"test_restoration": true,
	},
	{
		"name": "Bear",
		"scene": BEAR_SCENE,
		"maximum_health": 4,
		"hurt_recovery": 0.45,
		"death_signal": &"",
		"campaign_outcome": &"",
		"presentation": &"",
		"test_restoration": false,
	},
	{
		"name": "Wolf",
		"scene": WOLF_SCENE,
		"maximum_health": 2,
		"hurt_recovery": 0.45,
		"death_signal": &"",
		"campaign_outcome": &"",
		"presentation": &"",
		"test_restoration": false,
	},
	{
		"name": "WolfKing",
		"scene": LEVEL_01_SCENE,
		"actor_path": NodePath("Enemies/WolfKing"),
		"maximum_health": 5,
		"hurt_recovery": 1.1,
		"death_signal": &"died",
		"campaign_outcome": CampaignLevel.OUTCOME_COMPLETION,
		"presentation": &"boss_bar",
		"test_restoration": false,
	},
	{
		"name": "BearKing",
		"scene": LEVEL_02_SCENE,
		"actor_path": NodePath("Enemies/BearKing"),
		"maximum_health": 15,
		"hurt_recovery": 0.5,
		"death_signal": &"died",
		"campaign_outcome": CampaignLevel.OUTCOME_COMPLETION,
		"presentation": &"boss_bar",
		"test_restoration": false,
	},
]

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	fixture.set_project_setting("physics/2d/default_gravity", 0.0)

	for spec in ACTOR_SPECS:
		await verify_actor_contract(spec)

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func verify_actor_contract(spec: Dictionary) -> void:
	var actor_fixture := await instantiate_fixture(spec)
	var actor := actor_fixture["actor"] as DamageableActor
	var level := actor_fixture["level"] as CampaignLevel
	var name := str(spec["name"])
	var maximum_health := int(spec["maximum_health"])
	if actor == null:
		fixture.expect(false, "%s loads through its production actor seam" % name)
		await cleanup_fixture(actor_fixture)
		return

	var health_outcomes: Array[Vector2i] = []
	var death_notifications := [0]
	var campaign_outcomes := [0]
	actor.connect(
		&"health_changed",
		func(current_health: int, observed_maximum: int) -> void:
			health_outcomes.append(Vector2i(current_health, observed_maximum))
	)
	var death_signal := spec["death_signal"] as StringName
	if not death_signal.is_empty():
		actor.connect(death_signal, func() -> void: death_notifications[0] += 1)
	var campaign_outcome := spec["campaign_outcome"] as StringName
	if level != null and not campaign_outcome.is_empty():
		level.campaign_outcome_reached.connect(
			func(outcome: StringName) -> void:
				if outcome == campaign_outcome:
					campaign_outcomes[0] += 1
		)

	fixture.expect(not actor.has_method("hurt"), "%s exposes no legacy damage entry point" % name)
	fixture.expect(
		actor.call("get_maximum_health") == maximum_health,
		"%s exposes its authoritative maximum health" % name
	)
	fixture.expect(
		actor.call("get_current_health") == maximum_health,
		"%s initializes at full authoritative health" % name
	)
	expect_health_presentation(actor_fixture, spec, maximum_health, maximum_health, "initialization")

	actor.take_damage(1, Vector2.ZERO)
	fixture.expect(
		actor.call("get_current_health") == maximum_health - 1,
		"%s accepts one hit through the production damage seam" % name
	)
	fixture.expect(
		health_outcomes == [Vector2i(maximum_health - 1, maximum_health)],
		"%s publishes one authoritative accepted-hit outcome" % name
	)
	expect_health_presentation(
		actor_fixture,
		spec,
		maximum_health - 1,
		maximum_health,
		"accepted damage"
	)

	actor.take_damage(1, Vector2.ZERO)
	fixture.expect(
		actor.call("get_current_health") == maximum_health - 1,
		"%s ignores a repeated hit during hurt immunity" % name
	)
	fixture.expect(
		health_outcomes.size() == 1,
		"%s publishes no outcome for an immune hit" % name
	)

	if bool(spec["test_restoration"]):
		actor.call("restore_full_health")
		fixture.expect(
			actor.call("get_current_health") == maximum_health,
			"%s restoration returns authoritative health to full" % name
		)
		fixture.expect(
			health_outcomes[-1] == Vector2i(maximum_health, maximum_health),
			"%s restoration publishes an authoritative presentation update" % name
		)
		expect_health_presentation(
			actor_fixture,
			spec,
			maximum_health,
			maximum_health,
			"restoration"
		)
		actor.take_damage(1, Vector2.ZERO)
		fixture.expect(
			actor.call("get_current_health") == maximum_health,
			"%s restoration does not bypass active hurt immunity" % name
		)

	await fixture.wait_seconds(float(spec["hurt_recovery"]))
	var health_before_recovered_hit := int(actor.call("get_current_health"))
	actor.take_damage(1, Vector2.ZERO)
	fixture.expect(
		actor.call("get_current_health") == health_before_recovered_hit - 1,
		"%s accepts damage after hurt immunity ends" % name
	)
	expect_health_presentation(
		actor_fixture,
		spec,
		health_before_recovered_hit - 1,
		maximum_health,
		"damage after immunity"
	)

	while int(actor.call("get_current_health")) > 0:
		await fixture.wait_seconds(float(spec["hurt_recovery"]))
		actor.take_damage(1, Vector2.ZERO)

	fixture.expect(
		bool(actor.call("is_health_depleted")),
		"%s reaches terminal health at exactly zero" % name
	)
	fixture.expect(
		health_outcomes[-1] == Vector2i(0, maximum_health),
		"%s publishes exact terminal depletion" % name
	)
	expect_health_presentation(actor_fixture, spec, 0, maximum_health, "terminal depletion")
	if not death_signal.is_empty():
		fixture.expect(death_notifications[0] == 1, "%s publishes one death notification" % name)
	if not campaign_outcome.is_empty():
		fixture.expect(
			campaign_outcomes[0] == 1,
			"%s depletion publishes one owning campaign outcome" % name
		)

	var health_outcome_count := health_outcomes.size()
	actor.take_damage(1, Vector2.ZERO)
	fixture.expect(
		actor.call("get_current_health") == 0,
		"%s ignores damage after terminal state" % name
	)
	fixture.expect(
		health_outcomes.size() == health_outcome_count,
		"%s publishes no health outcome after terminal state" % name
	)
	if not death_signal.is_empty():
		fixture.expect(
			death_notifications[0] == 1,
			"%s cannot repeat its death notification" % name
		)
	if not campaign_outcome.is_empty():
		fixture.expect(
			campaign_outcomes[0] == 1,
			"%s cannot repeat its owning campaign outcome" % name
		)

	await cleanup_fixture(actor_fixture)


func instantiate_fixture(spec: Dictionary) -> Dictionary:
	var scene := spec["scene"] as PackedScene
	var container: Node
	var level: CampaignLevel = null
	var actor: DamageableActor = null
	var scene_instance := scene.instantiate()
	if spec.has("actor_path"):
		level = scene_instance as CampaignLevel
		if level != null:
			level.prepare_for_campaign(false)
			container = fixture.add_node(level)
			fixture.set_current_scene(level)
			actor = level.get_node_or_null(spec["actor_path"] as NodePath) as DamageableActor
		elif scene_instance != null:
			container = fixture.add_node(scene_instance)
			fixture.set_current_scene(container)
	else:
		container = fixture.add_node(Node2D.new())
		fixture.set_current_scene(container)
		actor = scene_instance as DamageableActor
		if scene_instance != null:
			fixture.add_node(scene_instance, container)

	if container != null:
		for body in container.find_children("*", "CharacterBody2D", true, false):
			(body as CharacterBody2D).set_physics_process(false)
		for audio in container.find_children("*", "AudioStreamPlayer2D", true, false):
			(audio as AudioStreamPlayer2D).stop()
	await fixture.process_frames(1)
	return {"container": container, "level": level, "actor": actor}


func expect_health_presentation(
	actor_fixture: Dictionary,
	spec: Dictionary,
	current_health: int,
	maximum_health: int,
	phase: String
) -> void:
	var presentation := spec["presentation"] as StringName
	var name := str(spec["name"])
	if presentation == &"hud":
		var level := actor_fixture["level"] as CampaignLevel
		var hud := level.get_node("HUD")
		fixture.expect(
			bool(hud.call("is_presenting_health", current_health, maximum_health)),
			"%s HUD reflects authoritative health after %s" % [name, phase]
		)
	elif presentation == &"boss_bar":
		var actor := actor_fixture["actor"] as DamageableActor
		var health_bar := find_health_bar(actor)
		fixture.expect(health_bar != null, "%s exposes its boss health presentation" % name)
		if health_bar != null:
			fixture.expect(
				health_bar.max_value == maximum_health and health_bar.value == current_health,
				"%s boss bar reflects authoritative health after %s" % [name, phase]
			)


func find_health_bar(actor: DamageableActor) -> TextureProgressBar:
	for node in actor.find_children("*", "TextureProgressBar", true, false):
		return node as TextureProgressBar
	return null


func cleanup_fixture(actor_fixture: Dictionary) -> void:
	fixture.set_current_scene(null)
	var container := actor_fixture["container"] as Node
	if is_instance_valid(container):
		container.free()
	fixture.set_paused(false)
	await fixture.process_frames(1)
