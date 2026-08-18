extends Node


const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")
const TIMEOUT_SECONDS: float = 5.0


var failures: Array[String] = []


func _ready() -> void:
	await test_retry_and_director_teardown()
	await test_fresh_world_starts_one_loop()

	if failures.is_empty():
		print("WAVE DIRECTOR TEARDOWN SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print(
		"WAVE DIRECTOR TEARDOWN SMOKE TEST FAIL: %d failure(s)"
		% failures.size()
	)
	get_tree().quit(1)


func test_retry_and_director_teardown() -> void:
	var world: Node = await create_world()
	var manager: Node = world.get_node("WaveManager")
	var director := world.get_node("WaveDirector") as WaveDirector
	var tracker := world.get_node("EnemyTracker") as EnemyTracker
	var started_waves: Array[int] = []
	director.wave_changed.connect(
		func(global_wave: int, _enemy_count: int) -> void:
			started_waves.append(global_wave)
	)

	expect(manager.continue_from_preparation(), "Initial wave cycle did not start.")
	expect(
		await wait_for_spawned_cohort(director, tracker),
		"Initial wave did not finish spawning."
	)
	manager.call("_enter_preparation", &"retry")
	await get_tree().process_frame
	await get_tree().process_frame
	expect(not director.is_cycle_running(), "Retry cleanup left the wave cycle active.")
	expect(
		tracker.get_total_active_enemy_count() == 0,
		"Retry cleanup retained tracked enemies."
	)

	expect(manager.continue_from_preparation(), "Cycle did not restart after retry cleanup.")
	expect(
		await wait_for_spawned_cohort(director, tracker),
		"Restarted wave did not finish spawning."
	)
	expect(
		started_waves == [1, 2],
		"Retry cleanup started a duplicate or skipped wave loop."
	)

	director.queue_free()
	await get_tree().process_frame
	manager.call("remove_remaining_enemies")
	await get_tree().process_frame
	await get_tree().process_frame
	expect(
		tracker.get_total_active_enemy_count() == 0
		and tracker.get_tracked_global_waves().is_empty(),
		"EnemyTracker did not cleanly unregister enemies after director teardown."
	)

	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func test_fresh_world_starts_one_loop() -> void:
	var world: Node = await create_world()
	var manager: Node = world.get_node("WaveManager")
	var director := world.get_node("WaveDirector") as WaveDirector
	var tracker := world.get_node("EnemyTracker") as EnemyTracker
	var started_waves: Array[int] = []
	director.wave_changed.connect(
		func(global_wave: int, _enemy_count: int) -> void:
			started_waves.append(global_wave)
	)
	expect(manager.continue_from_preparation(), "Fresh world did not start.")
	expect(
		await wait_for_spawned_cohort(director, tracker),
		"Fresh world wave did not finish spawning."
	)
	expect(started_waves == [1], "Fresh world started more than one wave loop.")
	director.cancel_cycle(true)
	manager.call("remove_remaining_enemies")
	await get_tree().process_frame
	expect(tracker.get_total_active_enemy_count() == 0, "Fresh world cleanup retained enemies.")
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func create_world() -> Node:
	var world: Node = MAIN_WORLD_SCENE.instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var director := world.get_node("WaveDirector") as WaveDirector
	director.debug_start_global_wave = 0
	return world


func wait_for_spawned_cohort(
	director: WaveDirector,
	tracker: EnemyTracker
) -> bool:
	var started_at: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_at < int(TIMEOUT_SECONDS * 1000.0):
		if (
			director.active_wave_cohorts.size() == 1
			and bool(director.active_wave_cohorts[0].get("spawn_completed", false))
			and tracker.get_total_active_enemy_count() > 0
		):
			return true
		await get_tree().process_frame
	return false


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
