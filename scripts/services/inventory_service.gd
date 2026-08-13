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
