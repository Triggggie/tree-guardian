class_name EquipmentService
extends Node


signal equipment_slot_changed(
	slot_id: StringName,
	previous_instance_id: StringName,
	new_instance_id: StringName
)


var equipped_instance_ids_by_slot_id: Dictionary = {
	EquipmentSlotRules.BARK_SLOT_ID: &"",
	EquipmentSlotRules.ROOTS_SLOT_ID: &""
}

var inventory: InventoryService


func _ready() -> void:
	inventory = get_node_or_null("/root/Inventory") as InventoryService
	if not is_instance_valid(inventory):
		push_error("EquipmentService requires Inventory.")
		return
	if not inventory.item_removed.is_connected(_on_inventory_item_removed):
		inventory.item_removed.connect(_on_inventory_item_removed)


func equip_item(instance_id: StringName) -> bool:
	var item: ItemInstance = _get_valid_inventory_item(instance_id)
	if item == null:
		return false
	var definition: ItemDefinition = GameContent.get_item(item.definition_id)
	var slot_id: StringName = definition.equipment_slot_id
	var previous_instance_id: StringName = get_equipped_instance_id(slot_id)
	if previous_instance_id == instance_id:
		return false

	equipped_instance_ids_by_slot_id[slot_id] = instance_id
	equipment_slot_changed.emit(slot_id, previous_instance_id, instance_id)
	return true


func unequip_slot(slot_id: StringName) -> bool:
	if not EquipmentSlotRules.is_valid_slot_id(slot_id):
		return false
	var previous_instance_id: StringName = get_equipped_instance_id(slot_id)
	if previous_instance_id == &"":
		return false

	equipped_instance_ids_by_slot_id[slot_id] = &""
	equipment_slot_changed.emit(slot_id, previous_instance_id, &"")
	return true


func get_equipped_instance_id(slot_id: StringName) -> StringName:
	if not EquipmentSlotRules.is_valid_slot_id(slot_id):
		return &""
	return StringName(equipped_instance_ids_by_slot_id.get(slot_id, &""))


func get_equipped_item(slot_id: StringName) -> ItemInstance:
	if not is_instance_valid(inventory):
		return null
	return inventory.get_item(get_equipped_instance_id(slot_id))


func is_item_equipped(instance_id: StringName) -> bool:
	return instance_id != &"" and instance_id in equipped_instance_ids_by_slot_id.values()


func get_equipped_loadout_copy() -> Dictionary:
	return equipped_instance_ids_by_slot_id.duplicate(true)


func clear_runtime_state_for_testing() -> void:
	if not OS.is_debug_build():
		push_warning("EquipmentService test reset is debug-build only.")
		return
	for slot_id in EquipmentSlotRules.get_supported_slot_ids():
		unequip_slot(slot_id)


func _get_valid_inventory_item(instance_id: StringName) -> ItemInstance:
	if instance_id == &"" or not is_instance_valid(inventory):
		return null
	var item: ItemInstance = inventory.get_item(instance_id)
	if item == null or not item.is_valid_data():
		return null
	var definition: ItemDefinition = GameContent.get_item(item.definition_id)
	if (
		not is_instance_valid(definition)
		or not definition.is_valid_definition()
		or not EquipmentSlotRules.is_valid_slot_id(
			definition.equipment_slot_id
		)
	):
		return null
	return item


func _on_inventory_item_removed(instance_id: StringName) -> void:
	for slot_id in EquipmentSlotRules.get_supported_slot_ids():
		if get_equipped_instance_id(slot_id) == instance_id:
			unequip_slot(slot_id)
