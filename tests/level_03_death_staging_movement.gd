extends SceneTree


const HeadlessGameplayFixture := preload("res://tests/headless_gameplay_fixture.gd")
const LEVEL_03_SCENE := preload("res://levels/level_03.tscn")
const MAIN_SCENE := preload("res://main.tscn")
const PLAYER_RUN_SPEED := 300.0
const STAGING_SEPARATION := 470.0

var fixture: HeadlessGameplayFixture


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	fixture = HeadlessGameplayFixture.new(self)
	await test_grounded_player_runs_to_elk_king_death_staging()
	await test_airborne_player_lands_before_elk_king_death_staging()
	await test_player_crosses_defeated_elk_king_from_the_right()
	await test_aligned_player_finishes_death_staging_without_running()

	fixture.complete(false)
	await fixture.process_frames(3)
	fixture.complete()


func test_grounded_player_runs_to_elk_king_death_staging() -> void:
	var main := await start_level_03()
	var level := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(level != null, "Main starts Level 03 for grounded death staging")
	if level == null:
		return
	fixture.add_node(level)

	var player := level.get_node("Player") as CharacterBody2D
	var elk_king := level.get_node("Enemies/ElkKing") as CharacterBody2D
	var player_camera := player.get_node("Camera2D") as Camera2D
	player.global_position.x = elk_king.global_position.x - STAGING_SEPARATION - 300.0
	await wait_until_grounded(player)
	fixture.expect(player.is_on_floor(), "Grounded death staging starts on Level 03 terrain")
	await fixture.wait_seconds(0.5)
	var pre_lock_x := player.global_position.x
	var pre_lock_camera_x := player_camera.get_screen_center_position().x
	player.get_node("VisualRoot").scale.x = -1.0
	await fixture.physics_frames(6)
	fixture.expect(
		is_equal_approx(player.global_position.x, pre_lock_x)
		and is_equal_approx(player.get_node("VisualRoot").scale.x, -1.0),
		"Elk King Death Staging does not control Player movement before Defeat locks"
	)

	var target_x := elk_king.global_position.x - STAGING_SEPARATION
	defeat_elk_king(elk_king)
	var run_start_x := player.global_position.x
	await fixture.physics_frames(6)
	var animation_state := player.get_node("AnimationTree").get(
		"parameters/playback"
	) as AnimationNodeStateMachinePlayback
	fixture.expect(
		absf(player.global_position.x - run_start_x - 30.0) <= 1.0,
		"Grounded Player runs right at the normal 300-pixel-per-second speed"
	)
	fixture.expect(
		animation_state.get_current_node() == &"running",
		"Grounded Player uses the existing running presentation"
	)
	fixture.expect(
		player_camera.get_screen_center_position().x > pre_lock_camera_x,
		"The existing Player Camera follows the scripted run"
	)

	await wait_for_staged_position(player, target_x)
	fixture.expect(
		is_equal_approx(player.global_position.x, target_x),
		"Grounded Player stops at the exact Elk King Death Staging destination"
	)
	fixture.expect(
		is_equal_approx(elk_king.global_position.x - player.global_position.x, STAGING_SEPARATION),
		"Grounded Player has an actual 470-pixel world-space separation from the Elk King"
	)
	fixture.expect(
		is_zero_approx(player.velocity.x),
		"Grounded Player has no horizontal velocity after staging"
	)
	fixture.expect(
		is_equal_approx(player.get_node("VisualRoot").scale.x, 1.0),
		"Grounded Player finishes facing right toward the Elk King"
	)
	fixture.expect(
		not level.is_campaign_control_available(),
		"Player input remains disabled throughout grounded death staging"
	)
	await retire_main(main)


func test_airborne_player_lands_before_elk_king_death_staging() -> void:
	var main := await start_level_03()
	var level := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(level != null, "Main starts Level 03 for airborne death staging")
	if level == null:
		return
	fixture.add_node(level)

	var player := level.get_node("Player") as CharacterBody2D
	var elk_king := level.get_node("Enemies/ElkKing") as CharacterBody2D
	var player_camera := player.get_node("Camera2D") as Camera2D
	await wait_until_grounded(player)
	player.global_position = Vector2(
		elk_king.global_position.x - STAGING_SEPARATION - 240.0,
		player.global_position.y - 220.0
	)
	player.velocity = Vector2(180.0, 0.0)
	await fixture.physics_frames(1)
	fixture.expect(not player.is_on_floor(), "Airborne death staging starts above Level 03 terrain")

	var target_x := elk_king.global_position.x - STAGING_SEPARATION
	var locked_health: int = player.call("get_current_health")
	defeat_elk_king(elk_king)
	var airborne_x := player.global_position.x
	var airborne_y := player.global_position.y
	await fixture.physics_frames(8)
	fixture.expect(
		absf(player.global_position.x - airborne_x) <= 0.1,
		"Airborne Player stops horizontal travel before landing"
	)
	fixture.expect(
		player.global_position.y > airborne_y and player.velocity.y > 0.0,
		"Airborne Player continues falling through normal gravity"
	)
	player.call("take_damage", 1, Vector2.ZERO)
	fixture.expect(
		player.call("get_current_health") == locked_health,
		"Player damage immunity remains active during airborne staging"
	)

	await wait_until_grounded(player)
	var landing_x := player.global_position.x
	await fixture.physics_frames(6)
	fixture.expect(
		player.global_position.x > landing_x + 20.0,
		"Airborne Player begins running only after terrain collision lands them"
	)
	await wait_for_staged_position(player, target_x)
	await fixture.wait_seconds(1.5)
	fixture.expect(
		is_equal_approx(player.global_position.x, target_x)
		and is_equal_approx(
			elk_king.global_position.x - player.global_position.x,
			STAGING_SEPARATION
		),
		"Airborne Player finishes at the unscaled 470-pixel staging separation"
	)
	fixture.expect(
		is_equal_approx(elk_king.scale.x, 1.5),
		"Airborne staging verifies the production Level 03 Elk King scale"
	)
	fixture.expect(
		level.get_campaign_camera_role() == CampaignLevel.CAMERA_PLAYER
		and player_camera.is_current()
		and absf(player_camera.get_screen_center_position().x - target_x) <= 1.0,
		"The existing Player Camera follows and settles on death staging"
	)
	var elk_animation_state := elk_king.get_node("AnimationTree").get(
		"parameters/playback"
	) as AnimationNodeStateMachinePlayback
	fixture.expect(
		elk_animation_state.get_current_node() != &"dead"
		and not elk_king.get_node("DeadAnimation/Aila").visible,
		"Elk King dead presentation remains deferred at the staged endpoint"
	)
	fixture.expect(
		player.is_visible_in_tree(),
		"Player remains visible at the staged endpoint"
	)
	player.call("take_damage", 1, Vector2.ZERO)
	fixture.expect(
		player.call("get_current_health") == locked_health,
		"Player damage immunity remains active at the staged endpoint"
	)
	await retire_main(main)


func test_player_crosses_defeated_elk_king_from_the_right() -> void:
	var main := await start_level_03()
	var level := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(level != null, "Main starts Level 03 for right-side death staging")
	if level == null:
		return
	fixture.add_node(level)

	var player := level.get_node("Player") as CharacterBody2D
	var elk_king := level.get_node("Enemies/ElkKing") as CharacterBody2D
	await wait_until_grounded(player)
	player.global_position = Vector2(
		elk_king.global_position.x + 220.0,
		elk_king.global_position.y - 100.0
	)
	await wait_until_grounded(player)
	var target_x := elk_king.global_position.x - STAGING_SEPARATION
	defeat_elk_king(elk_king)
	var run_start_x := player.global_position.x
	await fixture.physics_frames(6)
	fixture.expect(
		absf(player.global_position.x - run_start_x + 30.0) <= 1.0,
		"Player starting right of the destination runs left at normal speed"
	)
	fixture.expect(
		is_equal_approx(player.get_node("VisualRoot").scale.x, -1.0),
		"Player faces left while running from the right"
	)

	await wait_for_staged_position(player, target_x)
	fixture.expect(
		player.global_position.x < elk_king.global_position.x
		and is_equal_approx(player.global_position.x, target_x),
		"Player crosses the defeated Elk King's disabled body and reaches the destination"
	)
	fixture.expect(
		is_equal_approx(player.get_node("VisualRoot").scale.x, 1.0),
		"Player turns right toward the Elk King after crossing it"
	)
	await retire_main(main)


func test_aligned_player_finishes_death_staging_without_running() -> void:
	var main := await start_level_03()
	var level := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(level != null, "Main starts Level 03 for aligned death staging")
	if level == null:
		return
	fixture.add_node(level)

	var player := level.get_node("Player") as CharacterBody2D
	var elk_king := level.get_node("Enemies/ElkKing") as CharacterBody2D
	await wait_until_grounded(player)
	player.global_position.x = elk_king.global_position.x - STAGING_SEPARATION
	await wait_until_grounded(player)
	var target_x := elk_king.global_position.x - STAGING_SEPARATION
	player.global_position.x = target_x
	player.velocity.x = -PLAYER_RUN_SPEED
	player.get_node("VisualRoot").scale.x = -1.0
	defeat_elk_king(elk_king)
	await fixture.physics_frames(2)

	var animation_state := player.get_node("AnimationTree").get(
		"parameters/playback"
	) as AnimationNodeStateMachinePlayback
	fixture.expect(
		is_equal_approx(player.global_position.x, target_x)
		and is_zero_approx(player.velocity.x),
		"Already-aligned Player remains precisely stopped at the destination"
	)
	fixture.expect(
		is_equal_approx(player.get_node("VisualRoot").scale.x, 1.0)
		and animation_state.get_current_node() == &"idle",
		"Already-aligned Player finishes idle and facing right without running"
	)
	await retire_main(main)


func defeat_elk_king(elk_king: CharacterBody2D) -> void:
	elk_king.call("take_damage", 1, Vector2.ZERO)
	elk_king.call("take_damage", elk_king.call("get_maximum_health"), Vector2.ZERO)


func wait_for_staged_position(player: CharacterBody2D, target_x: float) -> void:
	for _frame in 180:
		if is_equal_approx(player.global_position.x, target_x) and is_zero_approx(player.velocity.x):
			return
		await physics_frame
	fixture.expect(
		false,
		"Player reaches the Elk King Death Staging destination within three seconds "
		+ "(x=%.2f, target=%.2f, velocity=%s, grounded=%s)" % [
			player.global_position.x,
			target_x,
			player.velocity,
			player.is_on_floor(),
		]
	)


func wait_until_grounded(player: CharacterBody2D) -> void:
	for _frame in 120:
		await physics_frame
		if player.is_on_floor():
			return
	fixture.expect(false, "Player lands on Level 03 terrain within two seconds")


func start_level_03() -> Node:
	var main := fixture.instantiate_scene(MAIN_SCENE)
	fixture.set_current_scene(main)
	await fixture.process_frames(1)
	main.call("start_level", LEVEL_03_SCENE, false)
	await fixture.process_frames(2)
	return main


func retire_main(main: Node) -> void:
	fixture.set_current_scene(null)
	main.queue_free()
	fixture.set_paused(false)
	await fixture.process_frames(2)
