extends SceneTree


const PLAYER_SCENE := preload("res://player/player.tscn")
const HUD_SCENE := preload("res://ui/HUD.tscn")
const HURT_IMMUNITY_WAIT_SECONDS := 0.95

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	var hud := HUD_SCENE.instantiate() as CanvasLayer
	root.add_child(player)
	root.add_child(hud)
	current_scene = player
	await process_frame

	expect(player.has_method("get_current_health"), "Player exposes authoritative current health")
	expect(player.has_method("get_maximum_health"), "Player exposes authoritative maximum health")
	expect(player.has_method("is_hurt_immune"), "Player exposes authoritative hurt immunity")
	expect(player.has_method("is_health_depleted"), "Player exposes authoritative terminal health")
	expect(player.has_signal("health_changed"), "Player publishes authoritative health outcomes")
	expect(hud.has_method("present_health"), "HUD consumes authoritative health outcomes")
	expect(hud.has_method("is_presenting_health"), "HUD exposes its health presentation")
	if failures.is_empty():
		var observed_health: Array[Vector2i] = []
		var hurt_reactions := [0]
		var death_notifications := [0]
		player.connect(
			"health_changed",
			func(current_health: int, maximum_health: int) -> void:
				observed_health.append(Vector2i(current_health, maximum_health))
		)
		player.connect("hurt_taken", func() -> void: hurt_reactions[0] += 1)
		player.connect("died", func() -> void: death_notifications[0] += 1)
		player.connect(
			"health_changed",
			func(current_health: int, maximum_health: int) -> void:
				hud.call("present_health", current_health, maximum_health)
		)
		hud.call(
			"present_health",
			player.call("get_current_health"),
			player.call("get_maximum_health")
		)

		expect(player.call("get_current_health") == 5, "Player starts with five current health")
		expect(player.call("get_maximum_health") == 5, "Player keeps its five-health maximum")
		expect(hud.call("is_presenting_health", 5, 5), "HUD initializes from authoritative health")
		player.hurt()
		expect(player.call("get_current_health") == 4, "One production hit removes one health")
		expect(hud.call("is_presenting_health", 4, 5), "HUD updates immediately after accepted damage")
		expect(
			observed_health == [Vector2i(4, 5)],
			"Accepted damage publishes the authoritative current and maximum health"
		)
		expect(player.call("is_hurt_immune"), "Accepted damage starts Player hurt immunity")
		player.hurt()
		expect(player.call("get_current_health") == 4, "Damage during hurt immunity is ignored")
		expect(observed_health.size() == 1, "Ignored damage publishes no health outcome")
		expect(hurt_reactions[0] == 1, "Ignored damage does not repeat the hurt reaction")

		player.restore_full_health()
		expect(player.call("get_current_health") == 5, "Restoration returns Player to full health")
		expect(player.call("is_hurt_immune"), "Restoration preserves an active hurt-immunity window")
		expect(
			observed_health[-1] == Vector2i(5, 5),
			"Restoration publishes the same authoritative health outcome"
		)
		expect(hud.call("is_presenting_health", 5, 5), "HUD updates immediately after restoration")
		player.hurt()
		expect(player.call("get_current_health") == 5, "Restored health remains immune to the repeated hit")
		expect(hurt_reactions[0] == 1, "Restoration does not permit a repeated hurt reaction")
		await create_timer(HURT_IMMUNITY_WAIT_SECONDS).timeout
		expect(not player.call("is_hurt_immune"), "Player immunity keeps its existing duration")

		for expected_health in [4, 3, 2, 1, 0]:
			player.hurt()
			expect(
				player.call("get_current_health") == expected_health,
				"Accepted damage reaches exactly %d health" % expected_health
			)
			if expected_health > 0:
				await create_timer(HURT_IMMUNITY_WAIT_SECONDS).timeout

		expect(player.call("is_health_depleted"), "Exact depletion makes health terminal")
		expect(death_notifications[0] == 1, "Exact depletion emits one death notification")
		var outcome_count_at_death: int = observed_health.size()
		var hurt_count_at_death: int = hurt_reactions[0]
		player.hurt()
		expect(player.call("get_current_health") == 0, "Damage after depletion leaves health at zero")
		expect(observed_health.size() == outcome_count_at_death, "Damage after depletion emits no health outcome")
		expect(hurt_reactions[0] == hurt_count_at_death, "Damage after depletion emits no hurt reaction")
		expect(death_notifications[0] == 1, "Damage after depletion cannot repeat death")

		player.restore_full_health()
		expect(not player.call("is_health_depleted"), "Restoration clears authoritative terminal health")
		expect(hud.call("is_presenting_health", 5, 5), "HUD presents restoration after depletion")
		player.hurt()
		expect(
			player.call("get_current_health") == 4,
			"Restored Player damage acceptance is authoritative in the health module"
		)
		expect(death_notifications[0] == 1, "Damage after restoration does not repeat the prior death")
		await create_timer(HURT_IMMUNITY_WAIT_SECONDS).timeout

	current_scene = null
	player.free()
	hud.free()
	await process_frame
	finish()


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func finish() -> void:
	if failures.is_empty():
		print("Player health test passed")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
