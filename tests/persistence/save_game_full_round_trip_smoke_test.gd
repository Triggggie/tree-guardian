extends Node


const TEST_PATH: String = "user://save_game_full_round_trip_smoke_test.cfg"
const SEED_PATH: String = "user://save_game_full_round_trip_seeds.cfg"
const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")

var failures: Array[String] = []


func _ready() -> void:
	cleanup_file(TEST_PATH)
	cleanup_file(SEED_PATH)
	BranchSeeds.initialize(SEED_PATH)
	expect(BranchSeeds.unlock_branch_seed(GameContent.get_branch(&"thorn_crown")), "Thorn Crown seed fixture unlock failed.")
	expect(SaveGame.initialize(TEST_PATH), "Full round-trip initialize failed.")
	expect(BranchLoadout.restore_persistence_state({
		"standard_slot_1": "blossom_branch",
		"standard_slot_2": "poison_vine",
		"standard_slot_3": "blossom_branch",
		"standard_slot_4": "poison_vine",
		"apex_slot": "thorn_crown"
	}, BranchSeeds), "Non-default Branch loadout fixture failed.")
	var item := ItemInstance.new()
	item.instance_id = &"full_round_trip_bark"
	item.definition_id = &"living_bark"
	item.item_level = 21
	item.rarity_id = ItemRarityRules.EPIC
	item.affix_rolls.append(ItemAffixRoll.new(&"maximum_health", 30.0))
	expect(Inventory.add_item(item) and Equipment.equip_item(item.instance_id), "Full item fixture failed.")
	expect(SaveGame.save_now(), "Full round-trip save failed.")
	expect(BranchLoadout.restore_persistence_state({}, BranchSeeds), "Branch loadout clear failed.")
	expect(Equipment.restore_equipment_loadout({}) and Inventory.restore_persistence_state([]), "Item state clear failed.")
	expect(SaveGame.load_now(), "Full round-trip reload failed.")
	var world: Node = MAIN_WORLD_SCENE.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await get_tree().process_frame
	var controller := world.get_node("Entities/Tree/Systems/TreeBranchLoadoutController") as TreeBranchLoadoutController
	expect(
		controller.get_runtime_branch(&"standard_slot_1").branch_id == &"blossom_branch"
		and controller.get_runtime_branch(&"standard_slot_2").branch_id == &"poison_vine"
		and controller.get_runtime_apex_branch().branch_id == &"thorn_crown",
		"Runtime Branches did not reflect restored non-default loadout."
	)
	expect(
		controller.get_runtime_branch(&"standard_slot_1").branch_definition.targeting_profile.side_mode
		== TargetingProfile.SideMode.OWN_SIDE_PREFERRED
		and controller.get_runtime_branch(&"standard_slot_2").branch_definition.targeting_profile.side_mode
		== TargetingProfile.SideMode.OWN_SIDE_PREFERRED
		and controller.get_runtime_apex_branch().branch_definition.targeting_profile.side_mode
		== TargetingProfile.SideMode.ANY_SIDE,
		"Restored Branches did not retain their authored side-targeting policies."
	)
	for lower_slot_id: StringName in [
		BranchSlotRules.STANDARD_SLOT_1_ID,
		BranchSlotRules.STANDARD_SLOT_3_ID
	]:
		var restored_blossom: CombatBranch = controller.get_runtime_branch(lower_slot_id)
		var restored_visual := restored_blossom.get_node("Visual") as BlossomBranchVisual
		var restored_sprite := restored_visual.get_node("ProductionSprite") as Sprite2D
		expect(
			restored_visual.is_using_production_sprite()
			and restored_sprite.visible
			and restored_sprite.texture.resource_path
			== "res://resources/branches/blossom/visuals/blossom_branch.png",
			"Saved lower Blossom did not restore its production artwork in %s."
			% lower_slot_id
		)
	expect(
		Inventory.has_item(item.instance_id)
		and Equipment.get_equipped_instance_id(&"bark") == item.instance_id,
		"Full integration did not restore Inventory + Equipment."
	)
	world.queue_free()
	await get_tree().process_frame
	BranchSeeds.unlocked_branch_seed_ids.clear()
	BranchSeeds.acquired_tiers_by_branch_id.clear()
	BranchLoadout.restore_persistence_state({"apex_slot": "thorn_crown"}, BranchSeeds)
	expect(BranchLoadout.get_equipped_apex_branch_id() == &"", "Saved Apex bypassed locked Branch Seed gate.")
	cleanup_file(TEST_PATH)
	cleanup_file(SEED_PATH)
	finish()


func cleanup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func finish() -> void:
	if failures.is_empty():
		print("SAVE GAME FULL ROUND TRIP SMOKE TEST PASS")
		get_tree().quit(0)
	else:
		print("SAVE GAME FULL ROUND TRIP SMOKE TEST FAIL: %d failure(s)" % failures.size())
		get_tree().quit(1)
