extends Node


class MockTree:
	extends Node2D

	var damage_events: Array[float] = []

	func _ready() -> void:
		add_to_group("tree")

	func take_damage(amount: float) -> void:
		damage_events.append(amount)


const COLOSSUS: EnemyDefinition = preload(
	"res://resources/enemies/ancient_bark_colossus_definition.tres"
)


var failures: Array[String] = []


func _ready() -> void:
	await test_phase_one_quake()
	await test_phase_two_double_pulse()
	await test_death_between_pulses()
	await test_wave_cleanup_during_telegraph()

	if failures.is_empty():
		print("ANCIENT BARK COLOSSUS QUAKE SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print(
		"ANCIENT BARK COLOSSUS QUAKE SMOKE TEST FAIL: %d failure(s)"
		% failures.size()
	)
	get_tree().quit(1)


func test_phase_one_quake() -> void:
	var definition: EnemyDefinition = create_test_definition(0.30, 0.12, 0.09, 0.08)
	var fixture: Dictionary = await create_fixture("PhaseOneQuake", definition)
	var tree_node: MockTree = fixture.tree
	var runtime: BossAbilityRuntime = fixture.runtime
	expect(runtime.get_current_phase() == 1, "Colossus did not start in Phase 1.")
	await runtime.telegraph_started
	expect(runtime.is_ability_running(), "Phase 1 Quake did not telegraph.")
	expect(runtime.has_active_telegraph(), "Phase 1 telegraph visual is missing.")
	expect(count_damage(tree_node.damage_events, 12.0) == 0, "Phase 1 Quake dealt premature damage.")
	await runtime.pulse_executed
	await get_tree().process_frame
	expect(count_damage(tree_node.damage_events, 12.0) == 1, "Phase 1 Quake did not deal one 12 damage pulse.")
	expect(not runtime.has_active_telegraph(), "Phase 1 telegraph survived execution.")
	expect(not get_tree().paused, "Phase 1 Quake paused SceneTree.")
	await cleanup_fixture(fixture.root)


func test_phase_two_double_pulse() -> void:
	var definition: EnemyDefinition = create_test_definition(0.30, 0.12, 0.07, 0.08)
	var fixture: Dictionary = await create_fixture("PhaseTwoQuake", definition)
	var tree_node: MockTree = fixture.tree
	var enemy: CharacterBody2D = fixture.enemy
	var runtime: BossAbilityRuntime = fixture.runtime
	var phase_events: Array[int] = []
	runtime.phase_changed.connect(
		func(new_phase: int) -> void: phase_events.append(new_phase)
	)
	enemy.call("take_damage", 149.0)
	expect(runtime.get_current_phase() == 1, "Colossus entered Phase 2 above 50% HP.")
	enemy.call("take_damage", 1.0)
	expect(runtime.get_current_phase() == 2, "Colossus did not enter Phase 2 at 50% HP.")
	enemy.call("take_damage", 1.0)
	expect(phase_events == [2], "Phase 2 transition occurred more than once.")

	await runtime.telegraph_started
	expect(runtime.is_ability_running(), "Phase 2 Quake did not start.")
	expect(count_damage(tree_node.damage_events, 10.0) == 0, "Phase 2 Quake dealt premature damage.")
	await runtime.pulse_executed
	expect(count_damage(tree_node.damage_events, 10.0) == 1, "Phase 2 Pulse 1 is wrong.")
	expect(runtime.is_ability_running(), "Phase 2 cast ended before Pulse 2.")
	await runtime.pulse_executed
	await get_tree().process_frame
	expect(count_damage(tree_node.damage_events, 10.0) == 2, "Phase 2 Pulse 2 is wrong.")
	expect(not runtime.is_ability_running(), "Phase 2 cast remained active after Pulse 2.")
	expect(runtime.get_executed_pulse_count() == 2, "Double pulses were not one cast.")
	expect(not get_tree().paused, "Phase 2 Quake paused SceneTree.")
	await cleanup_fixture(fixture.root)


func test_death_between_pulses() -> void:
	var definition: EnemyDefinition = create_test_definition(0.30, 0.12, 0.05, 0.16)
	var fixture: Dictionary = await create_fixture("QuakeDeath", definition)
	var tree_node: MockTree = fixture.tree
	var enemy: CharacterBody2D = fixture.enemy
	var runtime: BossAbilityRuntime = fixture.runtime
	enemy.call("take_damage", 150.0)
	await runtime.telegraph_started
	expect(runtime.is_ability_running(), "Death fixture did not start Phase 2 Quake.")
	await runtime.pulse_executed
	expect(count_damage(tree_node.damage_events, 10.0) == 1, "Death fixture did not execute Pulse 1.")
	enemy.call("take_damage", 100000.0)
	await get_tree().process_frame
	expect(not runtime.is_ability_running(), "Death between pulses did not cancel Quake.")
	expect(
		runtime.cooldown_timer.is_stopped()
		and runtime.telegraph_timer.is_stopped()
		and runtime.pulse_timer.is_stopped(),
		"Death between pulses left an ability Timer active."
	)
	await wait_seconds(0.20)
	expect(count_damage(tree_node.damage_events, 10.0) == 1, "Dead Colossus executed Pulse 2.")
	await cleanup_fixture(fixture.root)


func test_wave_cleanup_during_telegraph() -> void:
	var definition: EnemyDefinition = create_test_definition(0.30, 0.12, 0.18, 0.08)
	var fixture: Dictionary = await create_fixture("QuakeCleanup", definition)
	var tree_node: MockTree = fixture.tree
	var enemy: CharacterBody2D = fixture.enemy
	var runtime: BossAbilityRuntime = fixture.runtime
	await runtime.telegraph_started
	expect(runtime.is_ability_running(), "Cleanup fixture did not enter telegraph.")
	enemy.call("stop_combat")
	enemy.queue_free()
	await wait_seconds(0.24)
	expect(count_damage(tree_node.damage_events, 12.0) == 0, "Wave/Retry-style cleanup dealt delayed Quake damage.")
	expect(not is_instance_valid(runtime), "Wave/Retry-style cleanup retained ability runtime.")
	await cleanup_fixture(fixture.root)


func create_test_definition(
	initial_delay: float,
	cooldown: float,
	telegraph_duration: float,
	pulse_delay: float
) -> EnemyDefinition:
	var definition: EnemyDefinition = COLOSSUS.duplicate(true)
	var ability: BossAbilityDefinition = (
		COLOSSUS.boss_ability_definition.duplicate(true)
	)
	ability.initial_delay = initial_delay
	ability.cooldown = cooldown
	ability.telegraph_duration = telegraph_duration
	ability.phase_two_cooldown = cooldown
	ability.phase_two_telegraph_duration = telegraph_duration
	ability.phase_two_pulse_delay = pulse_delay
	definition.boss_ability_definition = ability
	return definition


func create_fixture(fixture_name: String, definition: EnemyDefinition) -> Dictionary:
	var root := Node2D.new()
	root.name = fixture_name
	add_child(root)
	var tracker := EnemyTracker.new()
	root.add_child(tracker)
	var lane_registry := LaneRegistry.new()
	root.add_child(lane_registry)
	var tree_node := MockTree.new()
	root.add_child(tree_node)
	var enemy := definition.enemy_scene.instantiate() as CharacterBody2D
	expect(
		bool(enemy.call("configure_from_definition", definition)),
		"Ancient Bark Colossus rejected its test definition."
	)
	root.add_child(enemy)
	enemy.call("setup_crowd_formation", 1.0, 0, 0.0, 0, 1.0, 0.0, 1.0)
	enemy.global_position = Vector2(definition.attack_range, 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	return {
		"root": root,
		"tree": tree_node,
		"enemy": enemy,
		"runtime": enemy.get_node("BossAbilityRuntime") as BossAbilityRuntime
	}


func cleanup_fixture(root: Node) -> void:
	if is_instance_valid(root):
		root.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func wait_seconds(duration: float) -> void:
	await get_tree().create_timer(duration).timeout


func count_damage(events: Array[float], amount: float) -> int:
	return events.count(amount)


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
