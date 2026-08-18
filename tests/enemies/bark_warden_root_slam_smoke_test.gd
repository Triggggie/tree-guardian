extends Node


class MockTree:
	extends Node2D

	var current_health: float = 1000.0
	var damage_events: Array[float] = []

	func _ready() -> void:
		add_to_group("tree")

	func take_damage(amount: float) -> void:
		current_health -= amount
		damage_events.append(amount)


const BARK_WARDEN: EnemyDefinition = preload(
	"res://resources/enemies/bark_warden_definition.tres"
)


var failures: Array[String] = []


func _ready() -> void:
	await test_walk_presentation()
	await test_root_slam_timing_and_cooldown()
	await test_death_during_telegraph()
	await test_independent_instances()

	if failures.is_empty():
		print("BARK WARDEN ROOT SLAM SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("BARK WARDEN ROOT SLAM SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func test_walk_presentation() -> void:
	var fixture: Dictionary = await create_fixture(
		"WalkPresentation",
		create_test_definition(10.0, 10.0, 0.08),
		0
	)
	var enemy: CharacterBody2D = fixture.enemy
	enemy.set_physics_process(false)
	var sprite := enemy.get_node("Visual/BarkWardenSprite") as AnimatedSprite2D
	expect(
		is_equal_approx(BARK_WARDEN.movement_speed, 85.0),
		"Bark Warden gameplay movement speed changed."
	)
	expect(is_instance_valid(sprite), "Bark Warden walk visual is missing.")
	if not is_instance_valid(sprite):
		await cleanup_fixture(fixture.root)
		return
	expect(sprite.sprite_frames.has_animation(&"walk"), "Warden walk is missing.")
	expect(
		is_equal_approx(sprite.sprite_frames.get_animation_speed(&"walk"), 12.0),
		"Warden walk baseline is not 12 FPS."
	)
	expect(sprite.sprite_frames.get_animation_loop(&"walk"), "Warden walk does not loop.")
	expect(
		sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"Warden walk is not pixel-sharp."
	)

	enemy.call("setup_crowd_formation", -1.0, 0, 0.0, 0, 1.0, 0.0, 1.0)
	expect(not sprite.flip_h, "Left-spawned Warden does not face right.")
	enemy.velocity.x = BARK_WARDEN.movement_speed
	enemy.call("update_walk_animation")
	expect(
		sprite.is_playing() and is_equal_approx(sprite.speed_scale, 1.0),
		"Normal movement did not use the Warden walk baseline."
	)
	enemy.velocity.x = BARK_WARDEN.movement_speed * 0.5
	enemy.call("update_walk_animation")
	expect(
		is_equal_approx(sprite.speed_scale, 0.5),
		"Warden walk cadence did not scale with actual velocity."
	)
	enemy.velocity.x = 0.0
	enemy.call("update_walk_animation")
	expect(not sprite.is_playing(), "Stationary Warden walked in place.")
	enemy.call("setup_crowd_formation", 1.0, 0, 0.0, 0, 1.0, 0.0, 1.0)
	expect(sprite.flip_h, "Right-spawned Warden does not face left.")
	await cleanup_fixture(fixture.root)


func test_root_slam_timing_and_cooldown() -> void:
	var fixture: Dictionary = await create_fixture(
		"RootSlamTiming",
		create_test_definition(0.30, 0.10, 0.08),
		0
	)
	var tree_node: MockTree = fixture.tree
	var enemy: CharacterBody2D = fixture.enemy
	var runtime: BossAbilityRuntime = fixture.runtime
	var attack := enemy.get_node("AttackComponent") as EnemyAttackComponent

	expect(attack.is_initialized(), "Normal melee AttackComponent is not initialized.")
	expect(not get_tree().paused, "Root Slam fixture paused SceneTree.")
	await runtime.telegraph_started
	expect(runtime.is_ability_running(), "Root Slam did not enter telegraph state.")
	expect(runtime.has_active_telegraph(), "Root Slam telegraph visual is missing.")
	expect(count_damage(tree_node.damage_events, 8.0) == 0, "Root Slam damaged before telegraph ended.")
	expect(not attack.is_enabled(), "Normal melee remained enabled during Root Slam.")

	await runtime.pulse_executed
	await get_tree().process_frame
	expect(count_damage(tree_node.damage_events, 8.0) == 1, "Root Slam did not deal exactly 8 damage.")
	expect(not runtime.has_active_telegraph(), "Root Slam telegraph survived execution.")
	expect(attack.is_enabled(), "Normal melee did not resume after Root Slam.")

	await runtime.telegraph_started
	expect(runtime.is_ability_running(), "Root Slam did not use its next cooldown.")
	await runtime.pulse_executed
	expect(count_damage(tree_node.damage_events, 8.0) == 2, "Second Root Slam cast is wrong.")
	expect(not get_tree().paused, "Root Slam paused SceneTree.")
	await cleanup_fixture(fixture.root)


func test_death_during_telegraph() -> void:
	var fixture: Dictionary = await create_fixture(
		"RootSlamDeath",
		create_test_definition(0.30, 0.20, 0.16),
		0
	)
	var tree_node: MockTree = fixture.tree
	var enemy: CharacterBody2D = fixture.enemy
	var runtime: BossAbilityRuntime = fixture.runtime
	await runtime.telegraph_started
	expect(runtime.is_ability_running(), "Death fixture never entered telegraph.")
	enemy.call("take_damage", 100000.0)
	await get_tree().process_frame
	expect(not runtime.is_ability_running(), "Death did not cancel Root Slam.")
	expect(not runtime.has_active_telegraph(), "Death retained Root Slam telegraph.")
	expect(
		runtime.cooldown_timer.is_stopped()
		and runtime.telegraph_timer.is_stopped()
		and runtime.pulse_timer.is_stopped(),
		"Death left a Root Slam Timer active."
	)
	await wait_seconds(0.22)
	expect(count_damage(tree_node.damage_events, 8.0) == 0, "Dead Bark Warden dealt delayed Slam damage.")
	await cleanup_fixture(fixture.root)


func test_independent_instances() -> void:
	var root := Node2D.new()
	root.name = "IndependentWardens"
	add_child(root)
	var tracker := EnemyTracker.new()
	root.add_child(tracker)
	var lane_registry := LaneRegistry.new()
	root.add_child(lane_registry)
	var tree_node := MockTree.new()
	root.add_child(tree_node)
	var definition: EnemyDefinition = create_test_definition(0.30, 0.20, 0.14)
	var first: CharacterBody2D = await spawn_enemy(root, tree_node, definition, 0)
	var second: CharacterBody2D = await spawn_enemy(root, tree_node, definition, 1)
	var first_runtime := first.get_node("BossAbilityRuntime") as BossAbilityRuntime
	var second_runtime := second.get_node("BossAbilityRuntime") as BossAbilityRuntime
	var first_started: Array[bool] = [false]
	var second_started: Array[bool] = [false]
	first_runtime.telegraph_started.connect(
		func(_ability_id: StringName, _phase: int) -> void: first_started[0] = true
	)
	second_runtime.telegraph_started.connect(
		func(_ability_id: StringName, _phase: int) -> void: second_started[0] = true
	)
	await wait_until(func() -> bool: return first_started[0] and second_started[0])
	expect(
		first_runtime.is_ability_running() and second_runtime.is_ability_running(),
		"Two Bark Wardens did not enter independent telegraphs."
	)
	expect(
		first_runtime.cooldown_timer != second_runtime.cooldown_timer,
		"Two Bark Wardens share an ability Timer."
	)
	first.call("take_damage", 100000.0)
	await wait_seconds(0.18)
	expect(count_damage(tree_node.damage_events, 8.0) == 1, "Death of Warden A cancelled or duplicated Warden B.")
	expect(not second_runtime.cancelled, "Death of Warden A cancelled Warden B runtime.")
	await cleanup_fixture(root)


func create_test_definition(
	initial_delay: float,
	cooldown: float,
	telegraph_duration: float
) -> EnemyDefinition:
	var definition: EnemyDefinition = BARK_WARDEN.duplicate(true)
	var ability: BossAbilityDefinition = (
		BARK_WARDEN.boss_ability_definition.duplicate(true)
	)
	ability.initial_delay = initial_delay
	ability.cooldown = cooldown
	ability.telegraph_duration = telegraph_duration
	definition.boss_ability_definition = ability
	return definition


func create_fixture(
	fixture_name: String,
	definition: EnemyDefinition,
	lane_index: int
) -> Dictionary:
	var root := Node2D.new()
	root.name = fixture_name
	add_child(root)
	var tracker := EnemyTracker.new()
	root.add_child(tracker)
	var lane_registry := LaneRegistry.new()
	root.add_child(lane_registry)
	var tree_node := MockTree.new()
	root.add_child(tree_node)
	var enemy: CharacterBody2D = await spawn_enemy(
		root, tree_node, definition, lane_index
	)
	return {
		"root": root,
		"tree": tree_node,
		"enemy": enemy,
		"runtime": enemy.get_node("BossAbilityRuntime") as BossAbilityRuntime
	}


func spawn_enemy(
	root: Node2D,
	tree_node: MockTree,
	definition: EnemyDefinition,
	lane_index: int
) -> CharacterBody2D:
	var enemy := definition.enemy_scene.instantiate() as CharacterBody2D
	expect(
		bool(enemy.call("configure_from_definition", definition)),
		"Bark Warden rejected its test definition."
	)
	root.add_child(enemy)
	enemy.call(
		"setup_crowd_formation",
		1.0,
		lane_index,
		float(lane_index) * 12.0,
		0,
		1.0,
		0.0,
		1.0
	)
	enemy.global_position = Vector2(
		tree_node.global_position.x + definition.attack_range,
		float(lane_index) * 12.0
	)
	await get_tree().process_frame
	await get_tree().process_frame
	return enemy


func cleanup_fixture(root: Node) -> void:
	if is_instance_valid(root):
		root.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func wait_seconds(duration: float) -> void:
	await get_tree().create_timer(duration).timeout


func wait_until(condition: Callable, timeout: float = 1.0) -> void:
	var elapsed: float = 0.0
	while not bool(condition.call()) and elapsed < timeout:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func count_damage(events: Array[float], amount: float) -> int:
	return events.count(amount)


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
