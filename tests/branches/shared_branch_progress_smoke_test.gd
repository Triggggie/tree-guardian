extends Node


const MAIN_WORLD_SCENE: PackedScene = preload(
	"res://scenes/main_world.tscn"
)


var failures: Array[String] = []
var branch_progress: BranchProgressService


func _ready() -> void:
	branch_progress = get_node("/root/BranchProgress") as BranchProgressService
	branch_progress.clear_runtime_progress_for_testing()

	await run_test()

	branch_progress.clear_runtime_progress_for_testing()

	if failures.is_empty():
		print("SHARED BRANCH PROGRESS SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print(
		"SHARED BRANCH PROGRESS SMOKE TEST FAIL: %d failure(s)"
		% failures.size()
	)
	get_tree().quit(1)


func run_test() -> void:
	var main_world: Node = await create_main_world()
	var branches: Dictionary = find_branch_pairs(main_world)

	var left_strength := branches.get("left_strength") as CombatBranch
	var right_strength := branches.get("right_strength") as CombatBranch
	var left_blossom := branches.get("left_blossom") as CombatBranch
	var right_blossom := branches.get("right_blossom") as CombatBranch
	var tree_node: Node = main_world.get_node("Entities/Tree")

	expect_all_branches_valid(
		left_strength,
		right_strength,
		left_blossom,
		right_blossom
	)

	if not _all_branches_valid(branches):
		await cleanup_main_world(main_world)
		return

	var strength_definition: BranchDefinition = left_strength.branch_definition
	var blossom_definition: BranchDefinition = left_blossom.branch_definition
	var strength_upgrade_ids: Array[StringName] = strength_definition.get_upgrade_ids()
	var blossom_upgrade_ids: Array[StringName] = blossom_definition.get_upgrade_ids()

	expect(
		branch_progress.get_progress(&"strength_branch")
		== branch_progress.get_progress(&"strength_branch"),
		"Strength did not resolve one shared progress record."
	)
	expect(
		branch_progress.get_progress(&"strength_branch")
		!= branch_progress.get_progress(&"blossom_branch"),
		"Different Branch archetypes shared a progress record."
	)
	expect_same_shared_progress(left_strength, right_strength, "initial Strength")
	expect_same_shared_progress(left_blossom, right_blossom, "initial Blossom")
	expect(
		left_strength.talent_effect_set != right_strength.talent_effect_set,
		"Strength instances shared a talent effect set."
	)
	expect(
		left_blossom.talent_effect_set != right_blossom.talent_effect_set,
		"Blossom instances shared a talent effect set."
	)

	var strength_signal_counts: Dictionary = {
		"left_level": 0,
		"right_level": 0,
		"left_xp": 0,
		"right_xp": 0,
		"left_tp": 0,
		"right_tp": 0
	}
	left_strength.level_changed.connect(
		func(_level: int) -> void:
			strength_signal_counts["left_level"] += 1
	)
	right_strength.level_changed.connect(
		func(_level: int) -> void:
			strength_signal_counts["right_level"] += 1
	)
	left_strength.xp_changed.connect(
		func(_xp: int, _required: int) -> void:
			strength_signal_counts["left_xp"] += 1
	)
	right_strength.xp_changed.connect(
		func(_xp: int, _required: int) -> void:
			strength_signal_counts["right_xp"] += 1
	)
	left_strength.talent_points_changed.connect(
		func(_available: int, _total: int) -> void:
			strength_signal_counts["left_tp"] += 1
	)
	right_strength.talent_points_changed.connect(
		func(_available: int, _total: int) -> void:
			strength_signal_counts["right_tp"] += 1
	)

	left_strength.add_xp(
		left_strength.get_safe_xp_required_per_level()
	)
	expect_same_shared_progress(left_strength, right_strength, "Strength XP")
	expect(left_strength.branch_level == 2, "Strength did not level to 2.")
	expect(
		left_strength.available_talent_points == 1
		and left_strength.total_talent_points_earned == 1,
		"Strength Talent Point milestone was not awarded exactly once."
	)
	expect(left_blossom.branch_level == 1, "Strength XP changed Blossom.")
	for signal_key in strength_signal_counts:
		expect(
			int(strength_signal_counts[signal_key]) == 1,
			"Strength signal '%s' did not fire exactly once." % signal_key
		)

	left_strength.current_target = Node2D.new()
	right_strength.current_target = null
	var strength_talent_id: StringName = left_strength.get_talent_ids()[0]
	expect(
		left_strength.purchase_talent(strength_talent_id),
		"Strength talent purchase failed."
	)
	expect(left_strength.has_talent(strength_talent_id), "Left Strength lost talent.")
	expect(not right_strength.has_talent(strength_talent_id), "Strength talent leaked across slots.")
	expect(
		left_strength.available_talent_points == 0
		and right_strength.available_talent_points == 1,
		"Strength talent cost was not isolated to Slot 1."
	)
	expect(
		left_strength.talent_effect_set.has_active_effect(
			left_strength.get_active_talent_effect_ids()[0]
		)
		and right_strength.get_active_talent_effect_ids().is_empty(),
		"Strength talent effects were not isolated per slot."
	)
	expect(
		right_strength.purchase_talent(strength_talent_id),
		"Independent Strength talent purchase in Slot 3 failed."
	)
	expect(
		is_instance_valid(left_strength.current_target)
		and right_strength.current_target == null,
		"Strength runtime targets were shared."
	)

	left_blossom.add_xp(
		left_blossom.get_safe_xp_required_per_level()
	)
	expect_same_shared_progress(left_blossom, right_blossom, "Blossom XP")
	expect(left_blossom.branch_level == 2, "Blossom did not level to 2.")
	var blossom_talent_id: StringName = left_blossom.get_talent_ids()[0]
	expect(
		right_blossom.purchase_talent(blossom_talent_id),
		"Blossom talent purchase failed."
	)
	expect(
		not left_blossom.has_talent(blossom_talent_id)
		and right_blossom.has_talent(blossom_talent_id),
		"Blossom talent was not isolated to Slot 4."
	)
	expect(
		not left_strength.has_talent(blossom_talent_id),
		"Blossom talent leaked into Strength."
	)

	tree_node.call("add_forest_essence", 1000)
	var essence_before_strength: int = tree_node.call("get_forest_essence")
	var strength_upgrade_id: StringName = strength_upgrade_ids[0]
	var strength_cost: int = left_strength.get_upgrade_cost_by_id(strength_upgrade_id)
	var strength_damage_before: float = left_strength.get_current_damage()
	expect(
		left_strength.purchase_upgrade(strength_upgrade_id),
		"Strength Damage upgrade purchase failed."
	)
	expect(
		int(tree_node.call("get_forest_essence"))
		== essence_before_strength - strength_cost,
		"Strength upgrade did not deduct Forest Essence exactly once."
	)
	expect(
		left_strength.get_upgrade_level(strength_upgrade_id) == 1
		and right_strength.get_upgrade_level(strength_upgrade_id) == 1,
		"Strength upgrade level did not synchronize."
	)
	expect(
		left_strength.get_current_damage() == right_strength.get_current_damage()
		and left_strength.get_current_damage() > strength_damage_before,
		"Strength shared Damage result is incorrect."
	)
	expect(
		left_strength.get_upgrade_cost_by_id(strength_upgrade_id)
		== strength_definition.get_upgrade_by_id(strength_upgrade_id).get_cost_for_level(1),
		"Next Strength cost did not use the shared new level."
	)
	expect(
		left_blossom.get_upgrade_level(blossom_upgrade_ids[0]) == 0,
		"Strength upgrade leaked into Blossom."
	)

	var blossom_upgrade_id: StringName = blossom_upgrade_ids[0]
	var blossom_healing_before: float = left_blossom.get_current_healing_per_tick()
	var essence_before_blossom: int = tree_node.call("get_forest_essence")
	var blossom_cost: int = right_blossom.get_upgrade_cost_by_id(blossom_upgrade_id)
	expect(
		right_blossom.purchase_upgrade(blossom_upgrade_id),
		"Blossom healing upgrade purchase failed."
	)
	expect(
		int(tree_node.call("get_forest_essence"))
		== essence_before_blossom - blossom_cost,
		"Blossom upgrade did not deduct Forest Essence exactly once."
	)
	expect(
		left_blossom.get_upgrade_level(blossom_upgrade_id) == 1
		and right_blossom.get_upgrade_level(blossom_upgrade_id) == 1,
		"Blossom upgrade level did not synchronize."
	)
	expect(
		left_blossom.get_upgrade_level(blossom_upgrade_id) == 1
		and right_blossom.get_upgrade_level(blossom_upgrade_id) == 1
		and left_blossom.get_current_healing_per_tick() > blossom_healing_before,
		"Blossom shared upgrade result is incorrect."
	)

	var saved_strength: BranchProgressRecord = (
		branch_progress.get_progress_copy(&"strength_branch")
	)
	var saved_blossom: BranchProgressRecord = (
		branch_progress.get_progress_copy(&"blossom_branch")
	)
	var original_slot: int = left_strength.slot_index
	left_strength.slot_index = 5
	expect(right_strength.slot_index != 5, "slot_index was shared.")
	left_strength.slot_index = original_slot
	left_strength.facing_side = 1
	expect(right_strength.facing_side == 1, "Unexpected right Strength side.")
	left_strength.facing_side = 0

	left_strength.current_target.free()
	left_strength.current_target = null
	await cleanup_main_world(main_world)

	var recreated_world: Node = await create_main_world()
	var recreated_branches: Dictionary = find_branch_pairs(recreated_world)
	var recreated_strength := recreated_branches.get("left_strength") as CombatBranch
	var recreated_blossom := recreated_branches.get("right_blossom") as CombatBranch

	expect(
		recreated_strength.branch_level == saved_strength.branch_level
		and recreated_strength.current_xp == saved_strength.current_xp
		and recreated_strength.has_talent(strength_talent_id)
		and recreated_strength.get_upgrade_level(strength_upgrade_id) == 1,
		"Recreated Strength did not restore shared runtime progress."
	)
	expect(
		recreated_blossom.branch_level == saved_blossom.branch_level
		and recreated_blossom.has_talent(blossom_talent_id)
		and recreated_blossom.get_upgrade_level(blossom_upgrade_id) == 1,
		"Recreated Blossom did not restore shared runtime progress."
	)
	expect(
		strength_definition.branch_id == &"strength_branch"
		and strength_definition.get_upgrade_ids() == strength_upgrade_ids
		and blossom_definition.branch_id == &"blossom_branch"
		and blossom_definition.get_upgrade_ids() == blossom_upgrade_ids,
		"Shared BranchDefinition Resources were mutated."
	)

	await cleanup_main_world(recreated_world)


func create_main_world() -> Node:
	var main_world: Node = MAIN_WORLD_SCENE.instantiate()
	main_world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main_world)
	await get_tree().process_frame
	return main_world


func cleanup_main_world(main_world: Node) -> void:
	main_world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func find_branch_pairs(main_world: Node) -> Dictionary:
	var branches: Dictionary = {}

	for node in main_world.get_tree().get_nodes_in_group("combat_branch"):
		if not main_world.is_ancestor_of(node):
			continue

		var branch := node as CombatBranch
		var side: String = "left" if branch.facing_side == 0 else "right"
		var archetype: String = (
			"strength" if branch.branch_id == &"strength_branch" else "blossom"
		)
		branches["%s_%s" % [side, archetype]] = branch

	return branches


func expect_all_branches_valid(
	left_strength: CombatBranch,
	right_strength: CombatBranch,
	left_blossom: CombatBranch,
	right_blossom: CombatBranch
) -> void:
	expect(is_instance_valid(left_strength), "Left Strength is missing.")
	expect(is_instance_valid(right_strength), "Right Strength is missing.")
	expect(is_instance_valid(left_blossom), "Left Blossom is missing.")
	expect(is_instance_valid(right_blossom), "Right Blossom is missing.")


func _all_branches_valid(branches: Dictionary) -> bool:
	return (
		is_instance_valid(branches.get("left_strength"))
		and is_instance_valid(branches.get("right_strength"))
		and is_instance_valid(branches.get("left_blossom"))
		and is_instance_valid(branches.get("right_blossom"))
	)


func expect_same_shared_progress(
	first: CombatBranch,
	second: CombatBranch,
	label: String
) -> void:
	expect(
		first.branch_level == second.branch_level
		and first.current_xp == second.current_xp
		and first.total_talent_points_earned == second.total_talent_points_earned
		and first.get_progress_upgrade_levels()
		== second.get_progress_upgrade_levels(),
		"%s progress differs between instances." % label
	)


func expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures.append(message)
	push_error(message)
