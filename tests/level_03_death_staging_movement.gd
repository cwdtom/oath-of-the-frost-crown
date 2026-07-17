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
	await test_player_handoff_holds_elk_king_death_tableau()

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
		elk_animation_state.get_current_node() == &"dead"
		and elk_king.get_node("DeadAnimation/Aila").visible,
		"Elk King dead presentation starts after the staged handoff"
	)
	fixture.expect(
		not player.visible,
		"Player visuals remain hidden after the staged handoff"
	)
	player.call("take_damage", 1, Vector2.ZERO)
	fixture.expect(
		player.call("get_current_health") == locked_health,
		"Player damage immunity remains active at the staged endpoint"
	)
	await retire_main(main)


func test_player_handoff_holds_elk_king_death_tableau() -> void:
	var main := await start_level_03()
	var level := main.call("get_active_campaign_level") as CampaignLevel
	fixture.expect(level != null, "Main starts Level 03 for the death tableau")
	if level == null:
		return
	fixture.add_node(level)

	var player := level.get_node("Player") as CharacterBody2D
	var elk_king := level.get_node("Enemies/ElkKing") as CharacterBody2D
	var player_visual := player.get_node("VisualRoot") as Node2D
	var player_sprite := player.get_node("VisualRoot/Sprite2D") as Sprite2D
	var player_body_shape := player.get_node("CollisionShape2D") as CollisionShape2D
	var player_weapon_shape := player.get_node(
		"VisualRoot/WeaponMount/Area2D/CollisionShape2D"
	) as CollisionShape2D
	var player_thunder := player.get_node("Player_Thunder") as Area2D
	var player_thunder_shape := player.get_node(
		"Player_Thunder/CollisionShape2D"
	) as CollisionShape2D
	var player_thunder_animation := player.get_node(
		"Player_Thunder/AnimationPlayer"
	) as AnimationPlayer
	var player_camera := player.get_node("Camera2D") as Camera2D
	var aila_proxy := elk_king.get_node("DeadAnimation/Aila") as Node2D
	var aila_sprite := elk_king.get_node("DeadAnimation/Aila/Aila") as Sprite2D
	var elk_animation_state := elk_king.get_node("AnimationTree").get(
		"parameters/playback"
	) as AnimationNodeStateMachinePlayback
	var result_interface := main.get_node("GameResultPopup")
	var campaign_outcomes: Array[StringName] = []
	level.campaign_outcome_reached.connect(
		func(outcome: StringName) -> void: campaign_outcomes.append(outcome)
	)

	await wait_until_grounded(player)
	var target_x := elk_king.global_position.x - STAGING_SEPARATION
	player.global_position.x = target_x
	player_visual.scale.x = 1.0
	await wait_until_grounded(player)
	player.global_position.x = target_x
	var staging_position := player.global_position
	var represented_transform := player_sprite.global_transform
	fixture.expect(
		player.visible and not aila_proxy.visible,
		"Only the real Player is visible before Elk King Defeat"
	)
	fixture.expect(
		elk_animation_state.get_current_node() != &"dead",
		"Elk King death presentation is deferred before handoff"
	)
	player_thunder_animation.play(&"cast")
	player_thunder_animation.seek(0.35, true)
	fixture.expect(
		not player_thunder_shape.disabled,
		"Death handoff begins while the production Player thunder weapon is active"
	)

	defeat_elk_king(elk_king)
	await fixture.physics_frames(2)
	fixture.expect(
		is_equal_approx(player.global_position.x, target_x)
		and is_equal_approx(player_visual.scale.x, 1.0),
		"Handoff begins only after exact staging with the Player facing the Elk King"
	)
	fixture.expect(
		not player.visible and aila_proxy.visible,
		"Aila becomes the only visible Player representation at handoff"
	)
	fixture.expect(
		aila_sprite.global_transform.is_equal_approx(represented_transform),
		"Aila preserves the Player's visible world position, facing, and apparent scale"
	)
	fixture.expect(
		player.collision_layer == 0
		and player.collision_mask == 0
		and player_body_shape.disabled
		and player_weapon_shape.disabled
		and player_thunder.collision_layer == 0
		and player_thunder.collision_mask == 0
		and player_thunder_shape.disabled
		and not player_thunder_animation.is_playing()
		and not player.is_physics_processing(),
		"Handoff disables Player body, melee, and thunder interaction"
	)
	fixture.expect(
		level.get_campaign_camera_role() == CampaignLevel.CAMERA_PLAYER
		and player_camera.is_current()
		and is_equal_approx(player.global_position.x, target_x),
		"The hidden Player remains the current Player Camera anchor at staging"
	)
	fixture.expect(
		elk_animation_state.get_current_node() == &"dead"
		and float(elk_king.call("_get_animation_position", &"dead")) > 0.0,
		"Elk King death presentation starts only after handoff"
	)

	await fixture.wait_seconds(0.2)
	var presentation_position := float(
		elk_king.call("_get_animation_position", &"dead")
	)
	elk_king.call("request_death_presentation")
	await fixture.process_frames(2)
	fixture.expect(
		float(elk_king.call("_get_animation_position", &"dead")) >= presentation_position,
		"Duplicate presentation requests do not restart the Elk King death animation"
	)

	await fixture.wait_seconds(6.0)
	fixture.expect(
		is_instance_valid(elk_king)
		and aila_proxy.visible
		and elk_king.get_node("DeadAnimation/Leif").visible
		and elk_king.get_node("DeadAnimation/Videl").visible
		and not elk_king.get_node("Sprite2D").visible
		and not elk_king.get_node("HealthBar").visible
		and is_equal_approx(aila_sprite.position.x, -400.0),
		"Elk King remains valid with the death presentation held on its final frame "
		+ "(Aila=%s, Leif=%s, Videl=%s, Elk=%s, health=%s, Aila x=%.2f)" % [
			aila_proxy.visible,
			elk_king.get_node("DeadAnimation/Leif").visible,
			elk_king.get_node("DeadAnimation/Videl").visible,
			elk_king.get_node("Sprite2D").visible,
			elk_king.get_node("HealthBar").visible,
			aila_sprite.position.x,
		]
	)
	fixture.expect(
		not level.is_campaign_hud_visible()
		and not level.is_campaign_control_available()
		and not player.visible
		and player.collision_layer == 0
		and player.collision_mask == 0
		and player_body_shape.disabled
		and player_weapon_shape.disabled
		and player_thunder.collision_layer == 0
		and player_thunder.collision_mask == 0
		and player_thunder_shape.disabled
		and not player_thunder_animation.is_playing()
		and not player.is_physics_processing()
		and player.global_position.is_equal_approx(staging_position)
		and player_camera.is_current(),
		"The death tableau retains its hidden HUD, input lock, inactive Player, and Camera"
	)
	fixture.expect(
		campaign_outcomes.is_empty()
		and not bool(result_interface.call("is_result_visible"))
		and level.get_node_or_null("VictoryStory") == null
		and main.call("get_active_campaign_level") == level,
		"The death tableau produces no campaign result, story, or Level replacement"
	)

	fixture.set_current_scene(null)
	main.queue_free()
	fixture.set_paused(false)
	await fixture.process_frames(3)
	fixture.expect(
		not is_instance_valid(level)
		and not is_instance_valid(elk_king)
		and not is_instance_valid(player),
		"External Level 03 disposal owns retained Elk King and hidden Player cleanup"
	)


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
