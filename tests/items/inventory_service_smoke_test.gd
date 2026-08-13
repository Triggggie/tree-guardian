extends Node


var failures: Array[String] = []
var added_ids: Array[StringName] = []
var removed_ids: Array[StringName] = []


func _ready() -> void:
	var inventory := get_node("/root/Inventory") as InventoryService
	var equipment := get_node("/root/Equipment") as EquipmentService
	equipment.clear_runtime_state_for_testing()
	inventory.clear_runtime_state_for_testing()
	inventory.item_added.connect(_on_item_added)
	inventory.item_removed.connect(_on_item_removed)
	test_inventory(inventory)
	equipment.clear_runtime_state_for_testing()
	inventory.clear_runtime_state_for_testing()

	if failures.is_empty():
		print("INVENTORY SERVICE SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("INVENTORY SERVICE SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func test_inventory(inventory: InventoryService) -> void:
	expect(inventory.get_item_count() == 0, "Fresh inventory is not empty.")
	var bark_a: ItemInstance = create_item(&"test_bark_epic_001", &"living_bark", 12, ItemRarityRules.EPIC, &"maximum_health", 15.0)
	var bark_b: ItemInstance = create_item(&"test_bark_common_002", &"living_bark", 4, ItemRarityRules.COMMON, &"health_regeneration", 0.5)
	var roots_a: ItemInstance = create_item(&"test_roots_uncommon_001", &"deep_roots", 8, ItemRarityRules.UNCOMMON, &"health_regeneration", 1.0)
	expect(inventory.add_item(bark_a), "Valid Bark A add failed.")
	expect(inventory.get_item_count() == 1 and inventory.get_item(bark_a.instance_id) == bark_a and inventory.has_item(bark_a.instance_id), "Bark A identity or count is wrong.")
	expect(not inventory.add_item(bark_a) and inventory.get_item_count() == 1, "Duplicate instance ID was accepted.")
	expect(inventory.add_item(bark_b) and inventory.add_item(roots_a), "Valid Bark B or Roots A add failed.")
	expect(inventory.get_item_count() == 3, "Inventory count is not 3.")
	expect(item_ids(inventory.get_items_for_slot(&"bark")) == [&"test_bark_epic_001", &"test_bark_common_002"], "Bark filter is wrong.")
	expect(item_ids(inventory.get_items_for_slot(&"roots")) == [&"test_roots_uncommon_001"], "Roots filter is wrong.")
	expect(inventory.get_items_for_slot(&"canopy").is_empty(), "Unknown slot returned items.")
	expect(inventory.get_item(&"missing") == null and not inventory.remove_item(&"missing"), "Unknown item behavior is wrong.")

	var signal_count_before_invalid: int = added_ids.size()
	var invalid_items: Array[ItemInstance] = []
	invalid_items.append(create_item(&"", &"living_bark", 1, ItemRarityRules.COMMON))
	invalid_items.append(create_item(&"invalid_definition", &"", 1, ItemRarityRules.COMMON))
	invalid_items.append(create_item(&"invalid_level", &"living_bark", 0, ItemRarityRules.COMMON))
	invalid_items.append(create_item(&"invalid_rarity", &"living_bark", 1, &"rare"))
	invalid_items.append(create_item(&"unknown_definition", &"missing_item", 1, ItemRarityRules.COMMON))
	var invalid_affix: ItemInstance = create_item(&"invalid_affix", &"living_bark", 1, ItemRarityRules.COMMON)
	invalid_affix.affix_rolls.append(ItemAffixRoll.new())
	invalid_items.append(invalid_affix)
	expect(not inventory.add_item(null), "Null ItemInstance was accepted.")
	for invalid_item in invalid_items:
		expect(not inventory.add_item(invalid_item), "Invalid ItemInstance was accepted.")
	expect(inventory.get_item_count() == 3 and added_ids.size() == signal_count_before_invalid, "Invalid add changed inventory or emitted a signal.")
	expect(inventory.remove_item(bark_b.instance_id), "Bark B remove failed.")
	expect(not inventory.has_item(bark_b.instance_id) and inventory.has_item(bark_a.instance_id) and inventory.has_item(roots_a.instance_id), "Remove damaged unrelated inventory state.")
	expect(added_ids == [&"test_bark_epic_001", &"test_bark_common_002", &"test_roots_uncommon_001"], "item_added signal sequence is wrong.")
	expect(removed_ids == [&"test_bark_common_002"], "item_removed signal sequence is wrong.")


func create_item(
	instance_id: StringName,
	definition_id: StringName,
	item_level: int,
	rarity_id: StringName,
	stat_id: StringName = &"",
	value: float = 0.0
) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.definition_id = definition_id
	item.item_level = item_level
	item.rarity_id = rarity_id
	if stat_id != &"":
		item.affix_rolls.append(ItemAffixRoll.new(stat_id, value))
	return item


func item_ids(items: Array[ItemInstance]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for item in items:
		ids.append(item.instance_id)
	return ids


func _on_item_added(instance_id: StringName) -> void:
	added_ids.append(instance_id)


func _on_item_removed(instance_id: StringName) -> void:
	removed_ids.append(instance_id)


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
