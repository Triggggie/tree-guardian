extends Node


const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")
const TEST_A_SCENE: PackedScene = preload(
	"res://tests/fixtures/branches/test_legendary_branch_a.tscn"
)
const TEST_B_SCENE: PackedScene = preload(
	"res://tests/fixtures/branches/test_legendary_branch_b.tscn"
)


var failures: Array[String] = []
var loadout: BranchLoadoutService
var progress: BranchProgressService
var definition_a: BranchDefinition
var definition_b: BranchDefinition


func _ready() -> void:
	loadout = get_node("/root/BranchLoadout") as BranchLoadoutService
	progress = get_node("/root/BranchProgress") as BranchProgressService
	definition_a = create_definition(
		&"test_legendary_a", "Test Legendary A",
		BranchDefinition.LEGENDARY_TIER_1, TEST_A_SCENE,
		&"test_talent_a", "Test Talent A", &"test_upgrade_a"
	)
	definition_b = create_definition(
		&"test_legendary_b", "Test Legendary B",
		BranchDefinition.LEGENDARY_TIER_2, TEST_B_SCENE,
		&"test_talent_b", "Test Talent B", &"test_upgrade_b"
	)
	install_definitions()
	loadout.clear_runtime_loadout_for_testing()
	progress.clear_runtime_progress_for_testing()
	await run_test()
	loadout.clear_runtime_loadout_for_testing()
	progress.clear_runtime_progress_for_testing()
	uninstall_definitions()

	if failures.is_empty():
		print("APEX BRANCH LOADOUT SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("APEX BRANCH LOADOUT SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func run_test() -> void:
	var world: Node = await create_world()
	var controller := get_controller(world)
	var apex_mount: Node2D = world.get_node(
		"Entities/Tree/AttachmentPoints/Apex/BranchMount"
	) as Node2D
	expect(loadout.is_apex_slot_initialized(), "Apex did not initialize.")
	expect(loadout.get_equipped_apex_branch_id() == &"", "Initial Apex is not EMPTY.")
	expect(controller.get_runtime_apex_branch() == null, "Initial runtime Apex exists.")
	expect(
		apex_mount.position == Vector2(0.0, -170.0),
		"Apex BranchMount does not use the dedicated top offset."
	)
	expect(not loadout.get_standard_loadout_copy().has(&"apex_slot"), "Standard copy contains Apex.")
	expect(loadout.get_full_loadout_copy().has(&"apex_slot"), "Full copy omits Apex.")

	expect(not loadout.equip_apex_branch(&"strength_branch"), "Strength entered Apex.")
	expect(not loadout.equip_apex_branch(&"blossom_branch"), "Blossom entered Apex.")
	expect(not loadout.equip_apex_branch(&"unknown"), "Unknown Branch entered Apex.")
	expect(not loadout.equip_apex_branch(&""), "EMPTY ID equipped as Apex.")

	var standard_instances: Array[CombatBranch] = []
	for slot_index in range(1, 5):
		standard_instances.append(controller.get_runtime_branch(
			BranchSlotRules.get_slot_id(slot_index)
		))
	var signal_count: Array[int] = [0]
	loadout.apex_slot_changed.connect(
		func(_previous: StringName, _next: StringName) -> void:
			signal_count[0] += 1
	)
	expect(loadout.equip_apex_branch(definition_a.branch_id), "Low-level Apex A equip failed.")
	var apex_a: CombatBranch = controller.get_runtime_apex_branch()
	expect(
		is_instance_valid(apex_a)
		and apex_a.slot_index == BranchSlotRules.APEX_SLOT
		and apex_a.get_slot_id() == BranchSlotRules.APEX_SLOT_ID
		and apex_a.branch_id == definition_a.branch_id
		and apex_a.get_parent() == apex_mount
		and apex_a.position == Vector2.ZERO
		and apex_a.is_slot_assignment_valid(),
		"Runtime Apex A identity or mount is invalid."
	)
	expect(count_world_branches(world) == 5, "Equipped Apex did not produce five Branches.")
	var apex_a_instance_id: int = apex_a.get_instance_id()
	expect(not loadout.equip_apex_branch(definition_a.branch_id), "Apex no-op succeeded.")
	expect(
		controller.get_runtime_apex_branch().get_instance_id() == apex_a_instance_id
		and signal_count[0] == 1,
		"Apex no-op replaced runtime or emitted signal."
	)

	apex_a.add_xp(2)
	expect(
		apex_a.branch_level == 2
		and apex_a.total_talent_points_earned == 1,
		"Apex A shared progress did not level."
	)
	expect(apex_a.purchase_talent(&"test_talent_a"), "Apex A talent purchase failed.")
	var tree_node: Node = world.get_node("Entities/Tree")
	tree_node.call("add_forest_essence", 10)
	expect(apex_a.purchase_upgrade(&"test_upgrade_a"), "Apex A upgrade purchase failed.")

	expect(loadout.equip_apex_branch(definition_b.branch_id), "Apex A to B swap failed.")
	await get_tree().process_frame
	var apex_b: CombatBranch = controller.get_runtime_apex_branch()
	expect(not is_instance_valid(apex_a), "Removed Apex A remained alive.")
	expect(
		is_instance_valid(apex_b)
		and apex_b.branch_id == definition_b.branch_id
		and not apex_b.has_talent(&"test_talent_a"),
		"Runtime Apex B or its independent build is wrong."
	)
	for slot_index in range(standard_instances.size()):
		expect(
			controller.get_runtime_branch(BranchSlotRules.get_slot_id(slot_index + 1))
			== standard_instances[slot_index],
			"Apex swap replaced standard Slot %d." % (slot_index + 1)
		)
	var registered_a: Array = progress.registered_branches_by_id.get(
		definition_a.branch_id, []
	)
	expect(registered_a.is_empty(), "Removed Apex A remains registered in BranchProgress.")

	expect(loadout.equip_apex_branch(definition_a.branch_id), "Apex B to A restore failed.")
	await get_tree().process_frame
	var restored_a: CombatBranch = controller.get_runtime_apex_branch()
	expect(
		restored_a.has_talent(&"test_talent_a")
		and restored_a.branch_level == 2
		and restored_a.get_upgrade_level(&"test_upgrade_a") == 1,
		"Apex A progress or apex_slot talent build was not restored."
	)
	expect(
		progress.get_talent_loadout_copy(&"apex_slot", definition_a.branch_id)
		.is_talent_purchased(&"test_talent_a"),
		"Apex talent loadout copy is missing Test Talent A."
	)

	expect(loadout.unequip_apex_branch(), "Low-level Apex unequip failed.")
	await get_tree().process_frame
	expect(
		loadout.is_apex_slot_initialized()
		and loadout.get_equipped_apex_branch_id() == &""
		and controller.get_runtime_apex_branch() == null,
		"Apex explicit EMPTY state is wrong."
	)
	expect(
		progress.get_progress(definition_a.branch_id) != null
		and progress.get_talent_loadout_copy(&"apex_slot", definition_a.branch_id) != null,
		"Apex unequip erased progress or talent build."
	)

	expect(loadout.equip_apex_branch(definition_a.branch_id), "Apex A re-equip failed.")
	await cleanup_world(world)
	var recreated: Node = await create_world()
	var recreated_controller := get_controller(recreated)
	expect(
		loadout.get_equipped_apex_branch_id() == definition_a.branch_id
		and recreated_controller.get_runtime_apex_branch().branch_id == definition_a.branch_id,
		"Equipped Apex did not survive MainWorld recreation."
	)
	expect(loadout.unequip_apex_branch(), "Recreated Apex unequip failed.")
	await cleanup_world(recreated)
	var empty_recreated: Node = await create_world()
	expect(
		loadout.is_apex_slot_initialized()
		and loadout.get_equipped_apex_branch_id() == &""
		and get_controller(empty_recreated).get_runtime_apex_branch() == null,
		"Explicit Apex EMPTY did not survive MainWorld recreation."
	)
	await cleanup_world(empty_recreated)


func create_definition(
	branch_id: StringName,
	display_name: String,
	tier: int,
	branch_scene: PackedScene,
	talent_id: StringName,
	talent_name: String,
	upgrade_id: StringName
) -> BranchDefinition:
	var talent := TalentDefinition.new()
	talent.talent_id = talent_id
	talent.display_name = talent_name
	talent.path_name = "Fixture"
	talent.required_branch_level = 2
	var talent_tree := TalentTreeDefinition.new()
	talent_tree.talent_tree_id = StringName("%s_tree" % branch_id)
	talent_tree.display_name = "%s Tree" % display_name
	talent_tree.talents = [talent]
	var upgrade := UpgradeDefinition.new()
	upgrade.upgrade_id = upgrade_id
	upgrade.display_name = "Test Upgrade"
	upgrade.effect_id = upgrade_id
	upgrade.value_per_level = 1.0
	upgrade.base_cost = 1
	upgrade.maximum_level = 3
	var definition := BranchDefinition.new()
	definition.branch_id = branch_id
	definition.display_name = display_name
	definition.description = "%s synthetic fixture description." % display_name
	definition.category_id = BranchDefinition.CATEGORY_LEGENDARY
	definition.legendary_tier = tier
	definition.branch_scene = branch_scene
	definition.targeting_profile = TargetingProfile.new()
	definition.upgrades = [upgrade]
	definition.talent_tree = talent_tree
	return definition


func install_definitions() -> void:
	GameContent.registry.branches.append(definition_a)
	GameContent.registry.branches.append(definition_b)
	GameContent.registry.rebuild_indexes()


func uninstall_definitions() -> void:
	GameContent.registry.branches.erase(definition_a)
	GameContent.registry.branches.erase(definition_b)
	GameContent.registry.rebuild_indexes()


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


func get_controller(world: Node) -> TreeBranchLoadoutController:
	return world.get_node(
		"Entities/Tree/Systems/TreeBranchLoadoutController"
	) as TreeBranchLoadoutController


func count_world_branches(world: Node) -> int:
	var count: int = 0
	for node in get_tree().get_nodes_in_group("combat_branch"):
		if world.is_ancestor_of(node):
			count += 1
	return count


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
