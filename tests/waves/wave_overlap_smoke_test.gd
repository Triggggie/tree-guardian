extends Node


const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")


var failures: Array[String] = []
var started_waves: Array[int] = []
var completed_waves: Array[int] = []
var enemies_per_side_by_wave: Dictionary = {}


func _ready() -> void:
	await run_overlap_test()
	if failures.is_empty():
		print("WAVE OVERLAP SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("WAVE OVERLAP SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func run_overlap_test() -> void:
	var world: Node = MAIN_WORLD_SCENE.instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var manager: Node = world.get_node("WaveManager")
	var director := world.get_node("WaveDirector") as WaveDirector
	var tracker := world.get_node("EnemyTracker") as EnemyTracker
	var tree_node: Node = world.get_node("Entities/Tree")
	director.wave_changed.connect(_on_wave_started)
	director.new_highest_wave_completed.connect(_on_wave_completed)
	director.current_wave = 10
	director.highest_completed_wave = 10
	var age_before: int = int(tree_node.get("age"))
	expect(manager.continue_from_preparation(), "Overlap fixture could not leave Preparation.")
	expect(await wait_for_wave_spawn(tracker, 11, 5.0), "Wave 11 did not finish spawning.")
	var wave_11_enemies: Array[Node] = get_wave_enemies(tracker, 11)
	for enemy in wave_11_enemies:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var wave_11_survivor: Node = wave_11_enemies[0]
	for enemy_index in range(1, wave_11_enemies.size()):
		wave_11_enemies[enemy_index].queue_free()
	expect(await wait_for_wave_spawn(tracker, 12, 5.0), "Wave 12 did not overlap after Wave 11 reached 20% survivors.")
	expect(
		director.current_wave == 12
		and tracker.has_active_enemies_for_wave(11)
		and tracker.has_active_enemies_for_wave(12)
		and tracker.get_tracked_global_waves() == [11, 12],
		"Adjacent Wave cohorts or current_wave newest-launched semantics are wrong."
	)
	var wave_12_enemies: Array[Node] = get_wave_enemies(tracker, 12)
	for enemy in wave_12_enemies:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	var origin_enemy: Node = wave_11_survivor
	expect(
		int(origin_enemy.get("reward_global_wave")) == 11,
		"Overlapped enemy lost its origin reward Wave."
	)
	for enemy in wave_12_enemies:
		enemy.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	expect(
		director.current_wave == 12
		and completed_waves.is_empty()
		and 13 not in started_waves,
		"Wave 12 finalized out of order or a third cohort started."
	)

	wave_11_survivor.queue_free()
	expect(await wait_for_completion_count(2, 5.0), "Ordered Wave 11/12 completion did not occur.")
	expect(
		completed_waves == [11, 12]
		and int(tree_node.get("age")) == age_before + 2,
		"Wave completion or Age order is wrong."
	)
	director.cancel_cycle(true)
	manager.remove_remaining_enemies()
	await get_tree().process_frame
	await get_tree().process_frame
	expect(
		tracker.get_total_active_enemy_count() == 0
		and tracker.get_tracked_global_waves().is_empty(),
		"Overlap cleanup retained ghost Wave cohorts."
	)
	expect(
		director.prepare_current_substage_restart()
		and director.active_wave_cohorts.is_empty(),
		"Retry preparation retained Wave cohort runtime state."
	)

	var forced_enemy: EnemyDefinition = GameContent.get_enemy(&"bark_beetle").duplicate(true)
	forced_enemy.equipment_drop_chance = 1.0
	EquipmentLoot.set_random_seed_for_testing(71)
	var origin_item: ItemInstance = EquipmentLoot.process_enemy_defeat(
		forced_enemy,
		GameContent.get_stage(&"guardian_grove"),
		20,
		Vector2.ZERO
	)
	expect(
		origin_item != null and origin_item.item_level == 2,
		"Origin Wave 20 reward context used a later Wave for Item Level."
	)
	if origin_item != null:
		Inventory.remove_item(origin_item.instance_id)
	EquipmentLoot.clear_runtime_state_for_testing()
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func wait_for_wave_spawn(
	tracker: EnemyTracker,
	global_wave: int,
	timeout_seconds: float
) -> bool:
	var started_at: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_at < int(timeout_seconds * 1000.0):
		var expected_count: int = int(enemies_per_side_by_wave.get(global_wave, 0)) * 2
		if expected_count > 0 and tracker.get_active_enemy_count_for_wave(global_wave) == expected_count:
			return true
		await get_tree().process_frame
	return false


func wait_for_completion_count(expected_count: int, timeout_seconds: float) -> bool:
	var started_at: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started_at < int(timeout_seconds * 1000.0):
		if completed_waves.size() >= expected_count:
			return true
		await get_tree().process_frame
	return false


func get_wave_enemies(tracker: EnemyTracker, global_wave: int) -> Array[Node]:
	var result: Array[Node] = []
	for enemy in tracker.get_enemies():
		if int(enemy.get("reward_global_wave")) == global_wave:
			result.append(enemy)
	return result


func _on_wave_started(global_wave: int, enemies_per_side: int) -> void:
	started_waves.append(global_wave)
	enemies_per_side_by_wave[global_wave] = enemies_per_side


func _on_wave_completed(global_wave: int) -> void:
	completed_waves.append(global_wave)


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
