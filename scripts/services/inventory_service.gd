class_name InventoryService
extends Node


signal item_added(instance_id: StringName)
signal item_removed(instance_id: StringName)


var items_by_instance_id: Dictionary = {}


func add_item(item_instance: ItemInstance) -> bool:
	if not _is_valid_inventory_item(item_instance):
		return false
	if items_by_instance_id.has(item_instance.instance_id):
		return false

	items_by_instance_id[item_instance.instance_id] = item_instance
	item_added.emit(item_instance.instance_id)
	return true


func remove_item(instance_id: StringName) -> bool:
	if instance_id == &"" or not items_by_instance_id.has(instance_id):
		return false

	items_by_instance_id.erase(instance_id)
	item_removed.emit(instance_id)
	return true


func has_item(instance_id: StringName) -> bool:
	return instance_id != &"" and items_by_instance_id.has(instance_id)


func get_item(instance_id: StringName) -> ItemInstance:
	return items_by_instance_id.get(instance_id) as ItemInstance


func get_items() -> Array[ItemInstance]:
	var items: Array[ItemInstance] = []
	for item_value in items_by_instance_id.values():
		var item := item_value as ItemInstance
		if item != null:
			items.append(item)
	return items


func get_items_for_slot(slot_id: StringName) -> Array[ItemInstance]:
	var items: Array[ItemInstance] = []
	if not EquipmentSlotRules.is_valid_slot_id(slot_id):
		return items

	for item in get_items():
		var definition: ItemDefinition = GameContent.get_item(item.definition_id)
		if (
			is_instance_valid(definition)
			and definition.equipment_slot_id == slot_id
		):
			items.append(item)
	return items


func get_item_count() -> int:
	return items_by_instance_id.size()


func export_persistence_state() -> Array:
	var stored_items: Array = []
	var items: Array[ItemInstance] = get_items()
	items.sort_custom(
		func(first: ItemInstance, second: ItemInstance) -> bool:
			return String(first.instance_id) < String(second.instance_id)
	)
	for item in items:
		var stored_affixes: Array = []
		for affix in item.affix_rolls:
			stored_affixes.append({
				"stat_id": String(affix.stat_id),
				"value": affix.value
			})
		stored_items.append({
			"instance_id": String(item.instance_id),
			"definition_id": String(item.definition_id),
			"item_level": item.item_level,
			"rarity_id": String(item.rarity_id),
			"is_locked": item.is_locked,
			"affixes": stored_affixes
		})
	return stored_items


func restore_persistence_state(stored_items: Array) -> bool:
	var restored_items: Array[ItemInstance] = []
	var restored_instance_ids: Dictionary = {}
	for stored_value in stored_items:
		if stored_value is not Dictionary:
			push_warning("Inventory skipped a malformed saved item entry.")
			continue
		var item: ItemInstance = _deserialize_item(stored_value as Dictionary)
		if item == null:
			push_warning("Inventory skipped an invalid saved item entry.")
			continue
		if restored_instance_ids.has(item.instance_id):
			push_warning(
				"Inventory skipped duplicate saved instance ID '%s'."
				% item.instance_id
			)
			continue
		restored_instance_ids[item.instance_id] = true
		restored_items.append(item)

	var previous_instance_ids: Array[StringName] = []
	for instance_id in items_by_instance_id:
		previous_instance_ids.append(StringName(instance_id))
	items_by_instance_id.clear()
	for instance_id in previous_instance_ids:
		item_removed.emit(instance_id)
	for item in restored_items:
		items_by_instance_id[item.instance_id] = item
		item_added.emit(item.instance_id)
	return true


func clear_runtime_state_for_testing() -> void:
	if not OS.is_debug_build():
		push_warning("InventoryService test reset is debug-build only.")
		return
	var instance_ids: Array[StringName] = []
	for instance_id in items_by_instance_id:
		instance_ids.append(StringName(instance_id))
	for instance_id in instance_ids:
		remove_item(instance_id)


func _is_valid_inventory_item(item_instance: ItemInstance) -> bool:
	if item_instance == null or not item_instance.is_valid_data():
		return false
	var definition: ItemDefinition = GameContent.get_item(
		item_instance.definition_id
	)
	return (
		is_instance_valid(definition)
		and definition.is_valid_definition()
		and EquipmentSlotRules.is_valid_slot_id(
			definition.equipment_slot_id
		)
	)


func _deserialize_item(stored_item: Dictionary) -> ItemInstance:
	var instance_id := StringName(str(stored_item.get("instance_id", "")))
	var definition_id := StringName(str(stored_item.get("definition_id", "")))
	var item_level_value = stored_item.get("item_level", 0)
	var rarity_id := StringName(str(stored_item.get("rarity_id", "")))
	var locked_value = stored_item.get("is_locked", false)
	var stored_affixes = stored_item.get("affixes", [])
	if (
		instance_id == &""
		or definition_id == &""
		or item_level_value is not int
		or int(item_level_value) < 1
		or not ItemRarityRules.is_valid_rarity_id(rarity_id)
		or locked_value is not bool
		or stored_affixes is not Array
	):
		return null

	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.definition_id = definition_id
	item.item_level = int(item_level_value)
	item.rarity_id = rarity_id
	item.is_locked = bool(locked_value)
	for stored_affix_value in stored_affixes:
		if stored_affix_value is not Dictionary:
			return null
		var stored_affix := stored_affix_value as Dictionary
		var stat_id := StringName(str(stored_affix.get("stat_id", "")))
		var affix_value = stored_affix.get("value", null)
		if (
			stat_id == &""
			or (affix_value is not float and affix_value is not int)
		):
			return null
		var affix := ItemAffixRoll.new(stat_id, float(affix_value))
		if not affix.is_valid_data():
			return null
		item.affix_rolls.append(affix)
	return item if _is_valid_inventory_item(item) else null
