extends Node


const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")
var failures: Array[String] = []
var loadout: BranchLoadoutService
var progress: BranchProgressService


func _ready() -> void:
	loadout = get_node("/root/BranchLoadout") as BranchLoadoutService
	progress = get_node("/root/BranchProgress") as BranchProgressService
	loadout.clear_runtime_loadout_for_testing()
	progress.clear_runtime_progress_for_testing()
	await run_test()
	loadout.clear_runtime_loadout_for_testing()
	progress.clear_runtime_progress_for_testing()
	if failures.is_empty():
		print("STANDARD BRANCH LOADOUT SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("STANDARD BRANCH LOADOUT SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func run_test() -> void:
	var world: Node = await create_world()
	var controller := get_controller(world)
	test_default_loadout(controller)
	test_invalid_and_copy_api(controller)

	var original_slot_1: CombatBranch = controller.get_runtime_branch(&"standard_slot_1")
	var signal_count: int = 0
	loadout.standard_slot_changed.connect(func(_s: StringName, _p: StringName, _n: StringName) -> void: signal_count += 1)
	expect(not loadout.equip_standard_branch(&"standard_slot_1", &"strength_branch"), "No-op equip succeeded.")
	expect(controller.get_runtime_branch(&"standard_slot_1") == original_slot_1 and signal_count == 0, "No-op replaced runtime or emitted signal.")

	var old_slot_2: CombatBranch = controller.get_runtime_branch(&"standard_slot_2")
	expect(loadout.equip_standard_branch(&"standard_slot_2", &"strength_branch"), "Blossom-to-Strength swap failed.")
	await get_tree().process_frame
	var new_slot_2: CombatBranch = controller.get_runtime_branch(&"standard_slot_2")
	expect(new_slot_2 != old_slot_2 and new_slot_2.branch_id == &"strength_branch" and new_slot_2.facing_side == 0, "Slot 2 runtime swap is invalid.")
	expect(not is_instance_valid(old_slot_2), "Removed Blossom remained alive.")
	var branch_panel: Panel = world.get_node("UI/BranchUpgradePanel") as Panel
	var panel_branches: Array = branch_panel.get("branches_by_slot") as Array
	expect(panel_branches[1] == new_slot_2 and branch_panel.get("selected_branch") != old_slot_2, "BRANCHES panel retained the freed Slot 2 Branch.")

	expect(loadout.equip_standard_branch(&"standard_slot_4", &"strength_branch"), "Slot 4 duplicate Strength equip failed.")
	await get_tree().process_frame
	var strengths: Array[CombatBranch] = []
	for slot_index in range(1, 5):
		var branch: CombatBranch = controller.get_runtime_branch(BranchSlotRules.get_slot_id(slot_index))
		expect(branch.branch_id == &"strength_branch", "Slot %d is not Strength." % slot_index)
		strengths.append(branch)
	expect(_count_world_branches(world) == 4, "Four-Strength loadout did not contain exactly four Branches.")
	var effect_sets: Dictionary = {}
	for branch in strengths:
		effect_sets[branch.talent_effect_set] = true
	expect(effect_sets.size() == 4, "Four Strength copies share TalentEffectSet objects.")

	strengths[0].add_xp(
		strengths[0].get_safe_xp_required_per_level()
	)
	for branch in strengths:
		expect(branch.branch_level == 2 and branch.total_talent_points_earned == 1, "Shared Strength progress did not reach every copy.")
	expect(strengths[0].purchase_talent(&"sweeping_strike"), "Slot 1 Sweeping Strike failed.")
	expect(strengths[1].purchase_talent(&"rebuff"), "Slot 2 Rebuff failed.")
	expect(strengths[2].purchase_talent(&"marked_prey"), "Slot 3 Marked Prey failed.")
	expect(strengths[0].has_talent(&"sweeping_strike") and not strengths[0].has_talent(&"rebuff"), "Slot 1 talent leaked.")
	expect(strengths[1].has_talent(&"rebuff") and not strengths[1].has_talent(&"sweeping_strike"), "Slot 2 talent leaked.")
	expect(strengths[2].has_talent(&"marked_prey") and not strengths[3].has_talent(&"marked_prey"), "Slot 3 talent leaked.")
	expect(strengths[3].available_talent_points == 1, "Untalented Slot 4 lost its TP budget.")

	var tree_node: Node = world.get_node("Entities/Tree")
	tree_node.call("add_forest_essence", 100)
	var essence_before: int = tree_node.call("get_forest_essence")
	var upgrade_id: StringName = strengths[0].get_upgrade_ids()[0]
	var cost: int = strengths[0].get_upgrade_cost_by_id(upgrade_id)
	expect(strengths[0].purchase_upgrade(upgrade_id), "Shared Strength upgrade failed.")
	expect(int(tree_node.call("get_forest_essence")) == essence_before - cost, "Essence was not spent exactly once.")
	for branch in strengths: expect(branch.get_upgrade_level(upgrade_id) == 1, "Shared upgrade missed a Strength copy.")

	# Real slot 1 Strength -> Blossom -> Strength -> Blossom persistence.
	expect(loadout.equip_standard_branch(&"standard_slot_1", &"blossom_branch"), "Slot 1 Strength-to-Blossom failed.")
	await get_tree().process_frame
	var blossom: CombatBranch = controller.get_runtime_branch(&"standard_slot_1")
	blossom.add_xp(
		blossom.get_safe_xp_required_per_level()
	)
	expect(blossom.purchase_talent(&"abundant_bloom"), "Slot 1 Abundant Bloom failed.")
	expect(loadout.equip_standard_branch(&"standard_slot_1", &"strength_branch"), "Slot 1 Blossom-to-Strength failed.")
	await get_tree().process_frame
	var restored_strength: CombatBranch = controller.get_runtime_branch(&"standard_slot_1")
	expect(restored_strength.has_talent(&"sweeping_strike") and not restored_strength.has_talent(&"abundant_bloom"), "Strength talent build was not restored.")
	expect(restored_strength.branch_level == 2 and restored_strength.get_upgrade_level(upgrade_id) == 1, "Strength shared progress was not restored.")
	expect(loadout.equip_standard_branch(&"standard_slot_1", &"blossom_branch"), "Second Blossom restore failed.")
	await get_tree().process_frame
	var restored_blossom: CombatBranch = controller.get_runtime_branch(&"standard_slot_1")
	expect(restored_blossom.has_talent(&"abundant_bloom") and not restored_blossom.has_talent(&"sweeping_strike"), "Blossom talent build was not restored.")

	expect(loadout.unequip_standard_branch(&"standard_slot_1"), "Slot 1 unequip failed.")
	await get_tree().process_frame
	expect(loadout.is_standard_slot_initialized(&"standard_slot_1") and loadout.get_equipped_branch_id(&"standard_slot_1") == &"", "EMPTY state is not initialized.")
	expect(controller.get_runtime_branch(&"standard_slot_1") == null, "Unequipped Slot 1 retained a runtime Branch.")
	expect(progress.get_progress(&"strength_branch") != null, "Unequip erased Strength progress.")

	await cleanup_world(world)
	var recreated: Node = await create_world()
	var recreated_controller := get_controller(recreated)
	expect(recreated_controller.get_runtime_branch(&"standard_slot_1") == null, "Explicit EMPTY did not survive MainWorld recreation.")
	for slot_index in range(2, 5):
		var slot_id: StringName = BranchSlotRules.get_slot_id(slot_index)
		expect(recreated_controller.get_runtime_branch(slot_id).branch_id == loadout.get_equipped_branch_id(slot_id), "Active loadout did not survive recreation in %s." % slot_id)
	await cleanup_world(recreated)

	loadout.clear_runtime_loadout_for_testing()
	var reset_world: Node = await create_world()
	test_default_loadout(get_controller(reset_world))
	await cleanup_world(reset_world)


func test_default_loadout(controller: TreeBranchLoadoutController) -> void:
	var expected: Dictionary = {&"standard_slot_1": &"strength_branch", &"standard_slot_2": &"blossom_branch", &"standard_slot_3": &"strength_branch", &"standard_slot_4": &"blossom_branch"}
	for slot_id in expected:
		expect(loadout.is_standard_slot_initialized(slot_id), "%s was not initialized." % slot_id)
		expect(loadout.get_equipped_branch_id(slot_id) == expected[slot_id], "%s has wrong default." % slot_id)
		var branch: CombatBranch = controller.get_runtime_branch(slot_id)
		var mount: Node = _get_mount(controller, slot_id)
		expect(is_instance_valid(branch) and branch.get_parent() == mount and branch.position == Vector2.ZERO, "%s runtime mount is invalid." % slot_id)
		expect(branch.get_slot_id() == slot_id and branch.is_slot_assignment_valid(), "%s runtime identity is invalid." % slot_id)
	expect(not loadout.is_standard_slot_initialized(&"apex_slot"), "Apex was initialized as standard.")
	expect(_count_world_branches(controller.get_tree().current_scene if controller.get_tree().current_scene else controller.get_parent()) >= 4, "Default runtime Branches are missing.")


func test_invalid_and_copy_api(controller: TreeBranchLoadoutController) -> void:
	var original: CombatBranch = controller.get_runtime_branch(&"standard_slot_1")
	for operation_result in [loadout.equip_standard_branch(&"invalid", &"strength_branch"), loadout.equip_standard_branch(&"apex_slot", &"strength_branch"), loadout.equip_standard_branch(&"standard_slot_1", &""), loadout.equip_standard_branch(&"standard_slot_1", &"unknown")]:
		expect(not operation_result, "Invalid equip operation succeeded.")
	expect(controller.get_runtime_branch(&"standard_slot_1") == original, "Invalid operation changed runtime.")
	var copy: Dictionary = loadout.get_standard_loadout_copy()
	copy[&"standard_slot_1"] = &"blossom_branch"
	expect(loadout.get_equipped_branch_id(&"standard_slot_1") == &"strength_branch", "Loadout copy mutated service state.")


func _get_mount(controller: TreeBranchLoadoutController, slot_id: StringName) -> Node:
	var tree: Node = controller.get_parent().get_parent()
	var names: Dictionary = {&"standard_slot_1": "LeftLower", &"standard_slot_2": "LeftUpper", &"standard_slot_3": "RightLower", &"standard_slot_4": "RightUpper"}
	var mount: Node2D = tree.get_node("AttachmentPoints/%s/BranchMount" % names[slot_id]) as Node2D
	var expected_offset := Vector2(-20, -170) if slot_id in [&"standard_slot_1", &"standard_slot_2"] else Vector2(20, -170)
	expect(mount.position == expected_offset, "%s mount offset changed." % slot_id)
	return mount


func _count_world_branches(world: Node) -> int:
	var count: int = 0
	for node in get_tree().get_nodes_in_group("combat_branch"):
		if world == node or world.is_ancestor_of(node): count += 1
	return count


func get_controller(world: Node) -> TreeBranchLoadoutController:
	return world.get_node("Entities/Tree/Systems/TreeBranchLoadoutController") as TreeBranchLoadoutController


func create_world() -> Node:
	var world: Node = MAIN_WORLD_SCENE.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await get_tree().process_frame
	return world


func cleanup_world(world: Node) -> void:
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func expect(condition: bool, message: String) -> void:
	if condition: return
	failures.append(message)
	push_error(message)
