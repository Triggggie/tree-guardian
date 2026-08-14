extends Node


const TEST_PATH: String = "user://save_game_inventory_equipment_smoke_test.cfg"

var failures: Array[String] = []
var loot_notification_count: int = 0


func _ready() -> void:
	cleanup_file()
	expect(SaveGame.initialize(TEST_PATH), "Fresh Inventory test initialize failed.")
	EquipmentLoot.equipment_item_dropped.connect(
		func(_instance_id: StringName, _enemy_id: StringName, _position: Vector2) -> void:
			loot_notification_count += 1
	)
	var fixtures: Array[ItemInstance] = [
		create_item(&"equipment_loot_000001", &"living_bark", 14, ItemRarityRules.EPIC, &"maximum_health", 25.0, true),
		create_item(&"equipment_loot_000002", &"living_bark", 4, ItemRarityRules.COMMON, &"branch_damage", 0.08, false),
		create_item(&"equipment_loot_000003", &"deep_roots", 8, ItemRarityRules.UNCOMMON, &"health_regeneration", 1.2, false),
		create_item(&"equipment_loot_000004", &"elder_heartwood", 9, ItemRarityRules.EPIC, &"branch_damage", 0.12, false),
		create_item(&"equipment_loot_000005", &"verdant_canopy", 10, ItemRarityRules.UNCOMMON, &"attack_speed", 0.11, false),
		create_item(&"equipment_loot_000010", &"luminous_sap", 11, ItemRarityRules.EPIC, &"maximum_health", 10.0, false)
	]
	for item in fixtures:
		expect(Inventory.add_item(item), "Inventory fixture add failed for %s." % item.instance_id)
	for slot_id in EquipmentSlotRules.get_supported_slot_ids():
		var matching_items: Array[ItemInstance] = Inventory.get_items_for_slot(slot_id)
		expect(not matching_items.is_empty(), "No fixture for slot %s." % slot_id)
		expect(Equipment.equip_item(matching_items[0].instance_id), "Equip failed for %s." % slot_id)
	expect(SaveGame.save_now(), "Inventory/Equipment save failed.")
	expect(Equipment.restore_equipment_loadout({}), "Equipment clear failed.")
	expect(Inventory.restore_persistence_state([]), "Inventory clear failed.")
	expect(SaveGame.load_now(), "Inventory/Equipment reload failed.")
	expect(loot_notification_count == 0, "Inventory restore replayed Equipment Drop notification.")
	expect(Inventory.get_item_count() == fixtures.size(), "Round trip changed Inventory count.")
	var bark_a: ItemInstance = Inventory.get_item(&"equipment_loot_000001")
	var bark_b: ItemInstance = Inventory.get_item(&"equipment_loot_000002")
	expect(
		bark_a != null and bark_b != null and bark_a != bark_b
		and bark_a.definition_id == bark_b.definition_id
		and bark_a.item_level == 14 and bark_a.rarity_id == ItemRarityRules.EPIC
		and bark_a.is_locked and is_equal_approx(bark_a.affix_rolls[0].value, 25.0),
		"Same-definition identity, lock, rarity, ILvl, or affix did not round trip."
	)
	for slot_id in EquipmentSlotRules.get_supported_slot_ids():
		expect(Equipment.get_equipped_instance_id(slot_id) != &"", "Slot %s did not restore." % slot_id)
	expect(
		is_equal_approx(EquipmentStats.get_total_affix_value(&"maximum_health"), 35.0)
		and is_equal_approx(EquipmentStats.get_total_affix_value(&"health_regeneration"), 1.2)
		and is_equal_approx(EquipmentStats.get_total_affix_value(&"branch_damage"), 0.12)
		and is_equal_approx(EquipmentStats.get_total_affix_value(&"attack_speed"), 0.11),
		"EquipmentStats did not rebuild the saved five-slot loadout."
	)
	expect(EquipmentLoot.next_instance_number >= 11, "Loot instance counter was not reconciled.")
	expect(SaveGame.load_now() and Inventory.get_item_count() == fixtures.size(), "Repeated load duplicated items.")
	cleanup_file()
	finish()


func create_item(instance_id: StringName, definition_id: StringName, level: int, rarity: StringName, stat_id: StringName, value: float, locked: bool) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.definition_id = definition_id
	item.item_level = level
	item.rarity_id = rarity
	item.is_locked = locked
	item.affix_rolls.append(ItemAffixRoll.new(stat_id, value))
	return item


func cleanup_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func finish() -> void:
	if failures.is_empty():
		print("SAVE GAME INVENTORY EQUIPMENT SMOKE TEST PASS")
		get_tree().quit(0)
	else:
		print("SAVE GAME INVENTORY EQUIPMENT SMOKE TEST FAIL: %d failure(s)" % failures.size())
		get_tree().quit(1)
