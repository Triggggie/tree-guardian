extends Node


const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")

var failures: Array[String] = []
var transitions: Array[Array] = []


func _ready() -> void:
	var inventory := get_node("/root/Inventory") as InventoryService
	var equipment := get_node("/root/Equipment") as EquipmentService
	equipment.clear_runtime_state_for_testing()
	inventory.clear_runtime_state_for_testing()
	equipment.equipment_slot_changed.connect(_on_equipment_slot_changed)
	await test_equipment(inventory, equipment)
	equipment.clear_runtime_state_for_testing()
	inventory.clear_runtime_state_for_testing()

	if failures.is_empty():
		print("EQUIPMENT SERVICE SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("EQUIPMENT SERVICE SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func test_equipment(
	inventory: InventoryService,
	equipment: EquipmentService
) -> void:
	expect(
		EquipmentSlotRules.get_supported_slot_ids() == [
			&"bark", &"roots", &"heartwood", &"canopy", &"sap"
		]
		and not EquipmentSlotRules.is_valid_slot_id(&"soul_relic")
		and not EquipmentSlotRules.is_valid_slot_id(&"unknown")
		and not EquipmentSlotRules.is_valid_slot_id(&""),
		"EquipmentSlotRules production set is not exactly five slots."
	)
	var expansion_items: Array[ItemInstance] = [
		create_item(&"slot_heartwood", &"elder_heartwood", 1, ItemRarityRules.COMMON, false),
		create_item(&"slot_canopy", &"verdant_canopy", 1, ItemRarityRules.COMMON, false),
		create_item(&"slot_sap", &"luminous_sap", 1, ItemRarityRules.COMMON, false)
	]
	for item in expansion_items:
		expect(inventory.add_item(item), "Five-slot fixture item was rejected.")
		expect(equipment.equip_item(item.instance_id), "Five-slot fixture equip failed.")
	expect(
		equipment.get_equipped_instance_id(&"heartwood") == &"slot_heartwood"
		and equipment.get_equipped_instance_id(&"canopy") == &"slot_canopy"
		and equipment.get_equipped_instance_id(&"sap") == &"slot_sap",
		"Expanded equipment mappings are not independent."
	)
	expect(equipment.unequip_slot(&"heartwood"), "Heartwood unequip failed.")
	expect(
		equipment.get_equipped_instance_id(&"heartwood") == &""
		and equipment.get_equipped_instance_id(&"canopy") == &"slot_canopy"
		and equipment.get_equipped_instance_id(&"sap") == &"slot_sap",
		"Unequipping Heartwood changed another expanded slot."
	)
	for item in expansion_items:
		inventory.remove_item(item.instance_id)
	transitions.clear()

	var bark_a: ItemInstance = create_item(&"test_bark_epic_001", &"living_bark", 12, ItemRarityRules.EPIC, false)
	var bark_b: ItemInstance = create_item(&"test_bark_common_002", &"living_bark", 4, ItemRarityRules.COMMON, true)
	var roots_a: ItemInstance = create_item(&"test_roots_uncommon_001", &"deep_roots", 8, ItemRarityRules.UNCOMMON, false)
	inventory.add_item(bark_a)
	inventory.add_item(bark_b)
	inventory.add_item(roots_a)
	expect(equipment.get_equipped_instance_id(&"bark") == &"" and equipment.get_equipped_instance_id(&"roots") == &"", "Fresh equipment is not EMPTY.")
	expect(equipment.equip_item(bark_a.instance_id), "Bark A equip failed.")
	expect(equipment.get_equipped_item(&"bark") == bark_a and equipment.get_equipped_instance_id(&"roots") == &"" and equipment.is_item_equipped(bark_a.instance_id), "Bark A equip mapping is wrong.")
	expect(not equipment.equip_item(bark_a.instance_id), "Equipped no-op succeeded.")
	expect(equipment.equip_item(roots_a.instance_id), "Roots A equip failed.")
	expect(equipment.get_equipped_item(&"roots") == roots_a and equipment.get_equipped_item(&"bark") == bark_a, "Roots equip changed Bark.")
	expect(equipment.equip_item(bark_b.instance_id), "Bark replacement failed.")
	expect(equipment.get_equipped_item(&"bark") == bark_b and inventory.get_item(bark_a.instance_id) == bark_a and not equipment.is_item_equipped(bark_a.instance_id), "Replacement copied, removed, or retained Bark A as equipped.")
	expect(bark_b.is_locked, "Locked item state changed during equip.")
	expect(equipment.unequip_slot(&"bark"), "Bark unequip failed.")
	expect(equipment.get_equipped_instance_id(&"bark") == &"" and inventory.get_item(bark_b.instance_id) == bark_b and bark_b.is_locked, "Unequip removed or changed locked Bark B.")
	expect(not equipment.unequip_slot(&"bark") and not equipment.unequip_slot(&"soul_relic") and not equipment.equip_item(&"missing"), "Invalid/no-op Equipment operation succeeded.")
	expect(transitions == [[&"bark", &"", bark_a.instance_id], [&"roots", &"", roots_a.instance_id], [&"bark", bark_a.instance_id, bark_b.instance_id], [&"bark", bark_b.instance_id, &""]], "Equipment signal transition sequence is wrong.")

	transitions.clear()
	expect(inventory.remove_item(roots_a.instance_id), "Equipped Roots removal failed.")
	expect(equipment.get_equipped_instance_id(&"roots") == &"" and not equipment.is_item_equipped(roots_a.instance_id) and not inventory.has_item(roots_a.instance_id), "Removing equipped item left stale equipment.")
	expect(transitions == [[&"roots", roots_a.instance_id, &""]], "Remove-equipped signal sequence is wrong.")

	expect(equipment.equip_item(bark_a.instance_id), "Bark A lifecycle equip failed.")
	var first_world: Node = MAIN_WORLD_SCENE.instantiate()
	first_world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(first_world)
	await get_tree().process_frame
	first_world.queue_free()
	await get_tree().process_frame
	var second_world: Node = MAIN_WORLD_SCENE.instantiate()
	second_world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(second_world)
	await get_tree().process_frame
	expect(inventory.get_item(bark_a.instance_id) == bark_a and equipment.get_equipped_instance_id(&"bark") == bark_a.instance_id and inventory.get_item_count() == 2, "MainWorld recreation lost or duplicated runtime equipment state.")
	second_world.queue_free()
	await get_tree().process_frame


func create_item(
	instance_id: StringName,
	definition_id: StringName,
	item_level: int,
	rarity_id: StringName,
	is_locked: bool
) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.definition_id = definition_id
	item.item_level = item_level
	item.rarity_id = rarity_id
	item.is_locked = is_locked
	return item


func _on_equipment_slot_changed(
	slot_id: StringName,
	previous_instance_id: StringName,
	new_instance_id: StringName
) -> void:
	transitions.append([slot_id, previous_instance_id, new_instance_id])


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
