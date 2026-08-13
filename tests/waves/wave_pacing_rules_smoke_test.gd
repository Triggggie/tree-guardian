extends Node


const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")


var failures: Array[String] = []


func _ready() -> void:
	test_thresholds()
	await test_boundaries_and_tracker()
	if failures.is_empty():
		print("WAVE PACING RULES SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("WAVE PACING RULES SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func test_thresholds() -> void:
	expect(
		not WavePacingRules.is_overlap_enabled(10)
		and is_zero_approx(WavePacingRules.get_overlap_threshold(10))
		and is_equal_approx(WavePacingRules.get_overlap_threshold(11), 0.20)
		and is_equal_approx(WavePacingRules.get_overlap_threshold(25), 0.20)
		and is_equal_approx(WavePacingRules.get_overlap_threshold(26), 0.30)
		and is_equal_approx(WavePacingRules.get_overlap_threshold(49), 0.30)
		and is_equal_approx(WavePacingRules.get_overlap_threshold(51), 0.35),
		"Wave overlap thresholds are wrong."
	)
	expect(
		WavePacingRules.is_survivor_ratio_eligible(11, 2, 10)
		and not WavePacingRules.is_survivor_ratio_eligible(11, 3, 10)
		and WavePacingRules.MAXIMUM_ACTIVE_COHORTS == 2,
		"Wave survivor threshold or maximum cohort rule is wrong."
	)


func test_boundaries_and_tracker() -> void:
	var world: Node = MAIN_WORLD_SCENE.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await get_tree().process_frame
	var director := world.get_node("WaveDirector") as WaveDirector
	var tracker := world.get_node("EnemyTracker") as EnemyTracker
	var first := Node.new()
	var second := Node.new()
	world.add_child(first)
	world.add_child(second)
	tracker.register_enemy(first, 48)
	tracker.register_enemy(second, 48)
	expect(
		tracker.get_total_active_enemy_count() == 2
		and tracker.get_active_enemy_count_for_wave(48) == 2
		and tracker.has_active_enemies_for_wave(48)
		and tracker.get_tracked_global_waves() == [48],
		"EnemyTracker per-Wave index is wrong."
	)
	director.active_wave_cohorts = [{
		"global_wave": 48,
		"wave_definition": director.get_wave_definition_for_global_wave(48),
		"initial_enemy_count": 10,
		"spawn_completed": true
	}]
	expect(director.call("_can_launch_overlapped_wave"), "Eligible normal Wave 48 could not overlap into Wave 49.")
	director.active_wave_cohorts[0]["global_wave"] = 49
	director.active_wave_cohorts[0]["wave_definition"] = director.get_wave_definition_for_global_wave(49)
	expect(not director.call("_can_launch_overlapped_wave"), "Incoming miniboss Wave 50 was allowed to overlap.")
	director.active_wave_cohorts[0]["global_wave"] = 50
	director.active_wave_cohorts[0]["wave_definition"] = director.get_wave_definition_for_global_wave(50)
	expect(not director.call("_can_launch_overlapped_wave"), "Outgoing miniboss Wave 50 was allowed to overlap.")
	expect(
		director.call("_is_substage_end_wave", 100)
		and not director.call("_is_substage_end_wave", 99),
		"Preparation boundary detection is wrong."
	)
	director.active_wave_cohorts.append({
		"global_wave": 51,
		"wave_definition": director.get_wave_definition_for_global_wave(51),
		"initial_enemy_count": 10,
		"spawn_completed": true
	})
	expect(not director.call("_can_launch_overlapped_wave"), "A third Wave cohort was allowed.")
	tracker.unregister_enemy(first)
	tracker.unregister_enemy(second)
	expect(
		tracker.get_total_active_enemy_count() == 0
		and tracker.get_tracked_global_waves().is_empty(),
		"EnemyTracker retained stale per-Wave state."
	)
	world.queue_free()
	await get_tree().process_frame


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
