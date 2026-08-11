extends Node


const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")
const STRENGTH_SCENE: PackedScene = preload("res://scenes/branches/strength_branch.tscn")
const BLOSSOM_SCENE: PackedScene = preload("res://scenes/branches/blossom_branch.tscn")

var failures: Array[String] = []
var branch_progress: BranchProgressService


func _ready() -> void:
	branch_progress = get_node("/root/BranchProgress") as BranchProgressService
	branch_progress.clear_runtime_progress_for_testing()
	await run_test()
	branch_progress.clear_runtime_progress_for_testing()

	if failures.is_empty():
		print("PER-SLOT TALENT LOADOUT SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print("PER-SLOT TALENT LOADOUT SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func run_test() -> void:
	test_slot_identity()
	var world: Node = await create_world()
	var branches: Dictionary = find_branches(world)
	var strength_1 := branches.get(1) as CombatBranch
	var blossom_2 := branches.get(2) as CombatBranch
	var strength_3 := branches.get(3) as CombatBranch
	var blossom_4 := branches.get(4) as CombatBranch

	if not all_valid([strength_1, blossom_2, strength_3, blossom_4]):
		await cleanup_world(world)
		return

	expect(strength_1.branch_level == 1 and strength_3.branch_level == 1, "Strength did not start at Level 1.")
	strength_1.add_xp(2)
	expect(strength_1.branch_level == 2 and strength_3.branch_level == 2, "Strength Level was not shared.")
	expect(strength_1.total_talent_points_earned == 1 and strength_3.total_talent_points_earned == 1, "Strength total TP was not shared.")
	expect(strength_1.available_talent_points == 1 and strength_3.available_talent_points == 1, "Each Strength slot did not receive the full TP budget.")
	expect(strength_1.purchase_talent(&"sweeping_strike"), "Slot 1 could not buy Sweeping Strike.")
	expect(strength_3.purchase_talent(&"rebuff"), "Slot 3 could not buy Rebuff.")
	expect(strength_1.has_talent(&"sweeping_strike") and not strength_1.has_talent(&"rebuff"), "Slot 1 Strength build is wrong.")
	expect(strength_3.has_talent(&"rebuff") and not strength_3.has_talent(&"sweeping_strike"), "Slot 3 Strength build is wrong.")
	expect(strength_1.talent_effect_set != strength_3.talent_effect_set, "Strength slots share a TalentEffectSet.")
	expect(strength_1.talent_effect_set.has_active_effect(&"sweeping_strike") and not strength_3.talent_effect_set.has_active_effect(&"sweeping_strike"), "Sweeping Strike effect leaked across slots.")
	expect(strength_3.talent_effect_set.has_active_effect(&"rebuff") and not strength_1.talent_effect_set.has_active_effect(&"rebuff"), "Rebuff effect leaked across slots.")

	strength_1.add_xp(4)
	expect(strength_1.total_talent_points_earned == 2, "Second shared TP milestone was not awarded.")
	expect(strength_1.available_talent_points == 1 and strength_3.available_talent_points == 1, "Available TP was not derived from each slot's own spend.")

	blossom_2.add_xp(6)
	expect(blossom_2.available_talent_points == 2 and blossom_4.available_talent_points == 2, "Blossom slots did not receive the full TP budget.")
	expect(blossom_2.purchase_talent(&"abundant_bloom"), "Slot 2 could not buy Abundant Bloom.")
	expect(blossom_4.purchase_talent(&"twin_petals"), "Slot 4 could not buy Twin Petals.")
	expect(blossom_2.talent_effect_set != blossom_4.talent_effect_set, "Blossom slots share a TalentEffectSet.")
	expect(blossom_2.get_current_healing_per_tick() > blossom_4.get_current_healing_per_tick(), "Abundant Bloom healing leaked or was inactive.")
	expect(blossom_4.talent_effect_set.has_active_effect(&"twin_petals") and not blossom_2.talent_effect_set.has_active_effect(&"twin_petals"), "Twin Petals effect leaked across slots.")

	var progress_copy: BranchProgressRecord = branch_progress.get_progress_copy(&"strength_branch")
	progress_copy.branch_level = 99
	expect(branch_progress.get_progress(&"strength_branch").branch_level != 99, "get_progress_copy returned mutable service state.")
	var loadout_copy: BranchTalentLoadoutRecord = branch_progress.get_talent_loadout_copy(&"standard_slot_1", &"strength_branch")
	loadout_copy.set_talent_purchased(&"rebuff")
	expect(not strength_1.has_talent(&"rebuff"), "get_talent_loadout_copy returned mutable service state.")

	await cleanup_world(world)
	var recreated_world: Node = await create_world()
	var recreated: Dictionary = find_branches(recreated_world)
	var recreated_strength_1 := recreated.get(1) as CombatBranch
	var recreated_strength_3 := recreated.get(3) as CombatBranch
	var recreated_blossom_2 := recreated.get(2) as CombatBranch
	var recreated_blossom_4 := recreated.get(4) as CombatBranch
	expect(recreated_strength_1.has_talent(&"sweeping_strike") and recreated_strength_3.has_talent(&"rebuff"), "Strength loadouts did not survive MainWorld recreation.")
	expect(recreated_blossom_2.has_talent(&"abundant_bloom") and recreated_blossom_4.has_talent(&"twin_petals"), "Blossom loadouts did not survive MainWorld recreation.")
	expect(recreated_strength_1.branch_level == 4 and recreated_strength_3.branch_level == 4, "Shared Strength progress did not survive recreation.")
	await cleanup_world(recreated_world)
	branch_progress.clear_runtime_progress_for_testing()
	await test_same_talent_in_two_slots()
	branch_progress.clear_runtime_progress_for_testing()
	await test_archetype_swap_persistence()


func test_same_talent_in_two_slots() -> void:
	var world: Node = await create_world()
	var branches: Dictionary = find_branches(world)
	var strength_1 := branches.get(1) as CombatBranch
	var strength_3 := branches.get(3) as CombatBranch
	strength_1.add_xp(2)
	expect(strength_1.purchase_talent(&"sweeping_strike"), "Slot 1 same-talent purchase failed.")
	expect(strength_3.purchase_talent(&"sweeping_strike"), "Slot 3 same-talent purchase failed.")
	expect(not strength_3.purchase_talent(&"sweeping_strike"), "Duplicate purchase in the same slot succeeded.")
	await cleanup_world(world)


func test_archetype_swap_persistence() -> void:
	var fixture := Node2D.new()
	add_child(fixture)
	var strength: CombatBranch = await create_branch(STRENGTH_SCENE, fixture, 1)
	strength.add_xp(2)
	expect(strength.purchase_talent(&"sweeping_strike"), "Swap fixture Strength purchase failed.")
	strength.queue_free()
	await get_tree().process_frame

	var blossom: CombatBranch = await create_branch(BLOSSOM_SCENE, fixture, 1)
	blossom.add_xp(2)
	expect(blossom.purchase_talent(&"abundant_bloom"), "Swap fixture Blossom purchase failed.")
	blossom.queue_free()
	await get_tree().process_frame

	var restored_strength: CombatBranch = await create_branch(STRENGTH_SCENE, fixture, 1)
	expect(restored_strength.has_talent(&"sweeping_strike") and not restored_strength.has_talent(&"abundant_bloom"), "Strength build did not survive Strength-Blossom-Strength swap.")
	restored_strength.queue_free()
	await get_tree().process_frame
	var restored_blossom: CombatBranch = await create_branch(BLOSSOM_SCENE, fixture, 1)
	expect(restored_blossom.has_talent(&"abundant_bloom") and not restored_blossom.has_talent(&"sweeping_strike"), "Blossom build did not survive the slot swap.")
	fixture.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func create_branch(scene: PackedScene, parent: Node, slot_index: int) -> CombatBranch:
	var branch := scene.instantiate() as CombatBranch
	branch.process_mode = Node.PROCESS_MODE_DISABLED
	branch.slot_index = slot_index
	parent.add_child(branch)
	await get_tree().process_frame
	return branch


func test_slot_identity() -> void:
	var expected_ids: Array[StringName] = [&"standard_slot_1", &"standard_slot_2", &"standard_slot_3", &"standard_slot_4", &"apex_slot"]
	for index in range(expected_ids.size()):
		var slot_index: int = index + 1
		expect(BranchSlotRules.get_slot_id(slot_index) == expected_ids[index], "Slot ID mapping failed for %d." % slot_index)
		expect(BranchSlotRules.get_slot_index(expected_ids[index]) == slot_index, "Reverse slot mapping failed for %s." % expected_ids[index])
	expect(BranchSlotRules.get_slot_id(0) == &"", "Invalid slot index did not return an empty ID.")
	expect(BranchSlotRules.get_slot_index(&"invalid") == -1, "Invalid slot ID did not return -1.")


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


func find_branches(world: Node) -> Dictionary:
	var branches: Dictionary = {}
	for node in get_tree().get_nodes_in_group("combat_branch"):
		if world.is_ancestor_of(node):
			var branch := node as CombatBranch
			branches[branch.slot_index] = branch
	return branches


func all_valid(branches: Array) -> bool:
	for branch in branches:
		if not is_instance_valid(branch):
			expect(false, "Production Tree is missing an equipped Branch slot.")
			return false
	return true


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
