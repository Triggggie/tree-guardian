extends Node


const TREE_SCRIPT: Script = preload("res://scripts/tree.gd")
const BLOSSOM_SCENE: PackedScene = preload(
	"res://scenes/branches/blossom_branch.tscn"
)


var failures: Array[String] = []


func _ready() -> void:
	await run_test()

	if failures.is_empty():
		print("BLOSSOM HEALING STACK SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print(
		"BLOSSOM HEALING STACK SMOKE TEST FAIL: %d failure(s)"
		% failures.size()
	)
	get_tree().quit(1)


func run_test() -> void:
	var fixture := Node2D.new()
	fixture.name = "BlossomHealingStackFixture"
	add_child(fixture)

	var tree_node: Node2D = TREE_SCRIPT.new()
	tree_node.name = "Tree"
	tree_node.set_process(false)
	fixture.add_child(tree_node)

	var first_blossom: Node2D = BLOSSOM_SCENE.instantiate()
	first_blossom.name = "FirstBlossom"
	first_blossom.set_process(false)
	fixture.add_child(first_blossom)

	var second_blossom: Node2D = BLOSSOM_SCENE.instantiate()
	second_blossom.name = "SecondBlossom"
	second_blossom.set_process(false)
	fixture.add_child(second_blossom)

	var first_id: StringName = StringName(
		first_blossom.call("get_healing_effect_id")
	)
	var repeated_first_id: StringName = StringName(
		first_blossom.call("get_healing_effect_id")
	)
	var second_id: StringName = StringName(
		second_blossom.call("get_healing_effect_id")
	)

	expect(first_id != &"", "First Blossom healing ID is empty.")
	expect(second_id != &"", "Second Blossom healing ID is empty.")
	expect(
		first_id == repeated_first_id,
		"One Blossom did not retain a stable healing ID."
	)
	expect(
		first_id != second_id,
		"Two Blossom instances received the same healing ID."
	)
	expect(
		String(first_id).begins_with("blossom_healing_"),
		"First Blossom healing ID has the wrong prefix."
	)
	expect(
		String(second_id).begins_with("blossom_healing_"),
		"Second Blossom healing ID has the wrong prefix."
	)

	expect(
		is_equal_approx(
			float(first_blossom.call("get_current_healing_per_tick")),
			3.0
		),
		"Blossom healing per tick changed from 3.0."
	)
	expect(
		is_equal_approx(
			float(first_blossom.call("get_current_healing_tick_interval")),
			2.0
		),
		"Blossom healing interval changed from 2.0."
	)
	expect(
		is_equal_approx(
			float(first_blossom.call("get_current_petal_damage")),
			3.0
		),
		"Blossom petal damage changed from 3.0."
	)
	expect(
		is_equal_approx(
			float(first_blossom.call("get_current_ranged_attack_interval")),
			2.0
		),
		"Blossom ranged attack interval changed from 2.0."
	)
	expect(
		is_equal_approx(
			float(first_blossom.get("ranged_attack_range")),
			650.0
		),
		"Blossom ranged attack range changed from 650.0."
	)

	first_blossom.call("apply_blossom_healing")
	expect(
		_get_active_effect_count(tree_node) == 1,
		"First Blossom did not create exactly one healing effect."
	)
	expect(
		bool(tree_node.call("has_healing_over_time_effect", first_id)),
		"Tree did not retain the first Blossom healing effect."
	)

	tree_node.call("process_healing_over_time", 1.0)
	first_blossom.call("apply_blossom_healing")
	expect(
		_get_active_effect_count(tree_node) == 1,
		"Refreshing one Blossom created a duplicate healing effect."
	)

	var refreshed_effect: Dictionary = (
		_get_healing_effects(tree_node)[first_id]
	)
	expect(
		is_equal_approx(
			float(refreshed_effect["remaining_duration"]),
			6.0
		),
		"Refreshing one Blossom did not restore its effect duration."
	)

	second_blossom.call("apply_blossom_healing")
	expect(
		_get_active_effect_count(tree_node) == 2,
		"Second Blossom did not create a separate healing effect."
	)
	expect(
		bool(tree_node.call("has_healing_over_time_effect", second_id)),
		"Tree did not retain the second Blossom healing effect."
	)

	var maximum_health: float = float(tree_node.get("max_health"))
	tree_node.set("current_health", maximum_health - 10.0)
	tree_node.call("process_healing_over_time", 2.0)
	expect(
		is_equal_approx(
			float(tree_node.get("current_health")),
			maximum_health - 4.0
		),
		"One shared tick of two Blossom effects did not heal 6 HP."
	)

	fixture.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	expect(
		get_tree().get_nodes_in_group("tree").is_empty(),
		"Blossom fixture left a tree group member."
	)
	expect(
		get_tree().get_nodes_in_group("blossom_branch").is_empty(),
		"Blossom fixture left a Blossom group member."
	)
	expect(
		get_tree().get_nodes_in_group("combat_branch").is_empty(),
		"Blossom fixture left a combat branch group member."
	)


func _get_healing_effects(tree_node: Node2D) -> Dictionary:
	return tree_node.get("healing_over_time_effects") as Dictionary


func _get_active_effect_count(tree_node: Node2D) -> int:
	return _get_healing_effects(tree_node).size()


func expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures.append(message)
	push_error(message)
