extends Node


const TEST_PATH: String = "user://debug_progress_reset_smoke_test.cfg"
const SEED_PATH: String = "user://debug_progress_reset_seeds_smoke_test.cfg"
const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")

var failures: Array[String] = []


func _ready() -> void:
	cleanup_files()
	BranchLoadout.clear_runtime_loadout_for_testing()
	BranchProgress.clear_runtime_progress_for_testing()
	Equipment.clear_runtime_state_for_testing()
	Inventory.clear_runtime_state_for_testing()
	BranchSeeds.initialize(SEED_PATH)
	expect(SaveGame.initialize(TEST_PATH), "Debug reset save initialize failed.")
	await run_test()
	cleanup_files()
	if failures.is_empty():
		print("DEBUG PROGRESS RESET SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("DEBUG PROGRESS RESET SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func run_test() -> void:
	var world: Node = await create_world()
	var strength: CombatBranch = find_branch(world, &"standard_slot_1")
	expect(is_instance_valid(strength), "Debug reset Strength fixture is missing.")
	if not is_instance_valid(strength):
		return
	strength.add_xp(strength.get_safe_xp_required_per_level())
	expect(strength.purchase_talent(&"sweeping_strike"), "Debug reset talent fixture failed.")

	var item := ItemInstance.new()
	item.instance_id = &"debug_reset_bark"
	item.definition_id = &"living_bark"
	item.item_level = 12
	item.rarity_id = ItemRarityRules.EPIC
	item.affix_rolls.append(ItemAffixRoll.new(&"maximum_health", 25.0))
	expect(Inventory.add_item(item), "Debug reset Inventory fixture failed.")
	expect(Equipment.equip_item(item.instance_id), "Debug reset Equipment fixture failed.")
	expect(
		BranchSeeds.unlock_branch_seed(GameContent.get_branch(&"thorn_crown")),
		"Debug reset Branch Seed fixture failed."
	)
	BranchSeeds.pity_points_by_tier[BranchDefinition.LEGENDARY_TIER_1] = 7
	expect(BranchSeeds.save_unlocks(), "Debug reset pity fixture save failed.")
	expect(BranchLoadout.equip_apex_branch(&"thorn_crown"), "Debug reset Apex fixture failed.")
	var available_souls: Array[TreeSoulDefinition] = TreeSouls.get_available_souls()
	if not available_souls.is_empty():
		TreeSouls.select_soul(available_souls[0], 200)
	expect(SaveGame.save_now(), "Debug reset player fixture save failed.")
	expect(FileAccess.file_exists(TEST_PATH), "Player fixture file was not created.")
	expect(FileAccess.file_exists(SEED_PATH), "Seed fixture file was not created.")

	expect(
		SaveGame.reset_all_player_progress_for_debug(false),
		"Central debug progress reset failed."
	)
	expect(Inventory.get_item_count() == 0, "Debug reset retained Inventory items.")
	for slot_id in EquipmentSlotRules.get_supported_slot_ids():
		expect(
			Equipment.get_equipped_instance_id(slot_id) == &"",
			"Debug reset retained Equipment in %s." % slot_id
		)
	expect(
		BranchLoadout.get_full_loadout_copy().is_empty(),
		"Debug reset retained Branch or Apex loadout state."
	)
	var strength_progress: BranchProgressRecord = BranchProgress.get_progress(
		&"strength_branch"
	)
	expect(
		strength_progress == null
		or (
			strength_progress.branch_level == 1
			and strength_progress.total_talent_points_earned == 0
		),
		"Debug reset retained shared Branch Progress."
	)
	var reset_loadout: BranchTalentLoadoutRecord = BranchProgress.get_talent_loadout(
		&"standard_slot_1", &"strength_branch"
	)
	expect(
		reset_loadout == null or reset_loadout.get_purchased_talent_ids().is_empty(),
		"Debug reset retained purchased talents."
	)
	expect(
		BranchSeeds.get_unlocked_branch_seed_ids().is_empty()
		and BranchSeeds.get_pity_points(BranchDefinition.LEGENDARY_TIER_1) == 0,
		"Debug reset retained Branch Seed unlocks or pity."
	)
	expect(not TreeSouls.has_selected_soul(), "Debug reset retained Tree Soul runtime state.")
	expect(
		not FileAccess.file_exists(TEST_PATH)
		and not FileAccess.file_exists(SEED_PATH),
		"Debug reset retained a persistence file."
	)

	expect(SaveGame.load_now(), "Fresh player reload after reset failed.")
	expect(BranchSeeds.reload_from_disk(), "Fresh Seed reload after reset failed.")
	expect(
		Inventory.get_item_count() == 0
		and BranchSeeds.get_unlocked_branch_seed_ids().is_empty(),
		"Old progress returned after disk reload."
	)
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var fresh_world: Node = await create_world()
	expect(
		BranchLoadout.get_equipped_branch_id(&"standard_slot_1") == &"strength_branch"
		and BranchLoadout.get_equipped_branch_id(&"standard_slot_2") == &"blossom_branch"
		and BranchLoadout.get_equipped_branch_id(&"standard_slot_3") == &"strength_branch"
		and BranchLoadout.get_equipped_branch_id(&"standard_slot_4") == &"blossom_branch"
		and BranchLoadout.get_equipped_apex_branch_id() == &"",
		"Fresh scene initialization did not restore the default loadout."
	)
	expect(
		SaveGame.reset_all_player_progress_for_debug(false),
		"Repeated debug progress reset was not idempotent."
	)
	fresh_world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func create_world() -> Node:
	var world: Node = MAIN_WORLD_SCENE.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	return world


func find_branch(world: Node, slot_id: StringName) -> CombatBranch:
	for node in get_tree().get_nodes_in_group("combat_branch"):
		if world.is_ancestor_of(node) and (node as CombatBranch).get_slot_id() == slot_id:
			return node as CombatBranch
	return null


func cleanup_files() -> void:
	for path in [TEST_PATH, SEED_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
