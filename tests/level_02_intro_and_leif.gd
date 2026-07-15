extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const LEVEL_02_SCENE := "res://levels/level_02.tscn"
const LEVEL_02_STORY := "res://levels/level_02_story.json"

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	var scene := load(LEVEL_02_SCENE) as PackedScene
	if scene == null:
		fixture.expect(false, "Could not load %s" % LEVEL_02_SCENE)
		fixture.complete()
		return

	var level := fixture.instantiate_scene(scene) as CampaignLevel
	fixture.expect(level != null, "Level02 implements CampaignLevel")
	if level == null:
		fixture.complete()
		return
	fixture.set_current_scene(level)
	await fixture.process_frames(1)

	var story := level.get_node_or_null("Story") as CanvasLayer
	fixture.expect(story != null, "Level02 contains an opening Story")
	if story != null:
		fixture.expect(
			story.get("story_path") == LEVEL_02_STORY,
			"Level02 uses level_02_story.json"
		)
		var story_nodes: Array = story.get("story_nodes")
		fixture.expect(not story_nodes.is_empty(), "Level02 opening Story is loaded")
		for _story_node in story_nodes:
			story.call("show_next_node")

	await fixture.process_frames(1)
	fixture.expect(
		not level.is_campaign_story_phase_active(),
		"Level02 completes its opening Story"
	)
	fixture.expect(
		level.is_campaign_control_available(),
		"Level02 resumes unpaused gameplay after its opening Story"
	)

	var player := level.get_node_or_null("Player") as Node2D
	var leif := level.get_node_or_null("Leif") as Node2D
	var leif_sprite := leif.get_node_or_null("Sprite2D") as Sprite2D if leif != null else null
	fixture.expect(player != null, "Level02 contains Player")
	fixture.expect(leif != null, "Level02 contains Leif")
	fixture.expect(leif_sprite != null, "Leif contains Sprite2D")
	if player != null and leif != null and leif_sprite != null:
		player.global_position.x = leif.global_position.x + 100.0
		await fixture.process_frames(1)
		fixture.expect(not leif_sprite.flip_h, "Leif faces a player on his right")

		player.global_position.x = leif.global_position.x - 100.0
		await fixture.process_frames(1)
		fixture.expect(leif_sprite.flip_h, "Leif faces a player on his left")

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()
