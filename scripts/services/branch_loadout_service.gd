class_name BranchLoadoutService
extends Node


signal standard_slot_changed(
	slot_id: StringName,
	previous_branch_id: StringName,
	new_branch_id: StringName
)


var equipped_branch_ids_by_slot_id: Dictionary = {}


func is_standard_slot_initialized(slot_id: StringName) -> bool:
	return (
		_is_standard_slot_id(slot_id)
		and equipped_branch_ids_by_slot_id.has(slot_id)
	)


func ensure_standard_slot_initialized(
	slot_id: StringName,
	default_branch_id: StringName
) -> bool:
	if not _is_standard_slot_id(slot_id):
		return false
	if equipped_branch_ids_by_slot_id.has(slot_id):
		return false
	if not _is_valid_standard_branch(slot_id, default_branch_id):
		return false

	equipped_branch_ids_by_slot_id[slot_id] = default_branch_id
	standard_slot_changed.emit(slot_id, &"", default_branch_id)
	return true


func get_equipped_branch_id(slot_id: StringName) -> StringName:
	if not is_standard_slot_initialized(slot_id):
		return &""
	return StringName(equipped_branch_ids_by_slot_id[slot_id])


func get_standard_loadout_copy() -> Dictionary:
	return equipped_branch_ids_by_slot_id.duplicate(true)


func equip_standard_branch(
	slot_id: StringName,
	branch_id: StringName
) -> bool:
	if not _is_valid_standard_branch(slot_id, branch_id):
		return false
	var previous_branch_id: StringName = get_equipped_branch_id(slot_id)
	if is_standard_slot_initialized(slot_id) and previous_branch_id == branch_id:
		return false

	equipped_branch_ids_by_slot_id[slot_id] = branch_id
	standard_slot_changed.emit(slot_id, previous_branch_id, branch_id)
	return true


func unequip_standard_branch(slot_id: StringName) -> bool:
	if not _is_standard_slot_id(slot_id):
		return false
	if not is_standard_slot_initialized(slot_id):
		return false
	var previous_branch_id: StringName = get_equipped_branch_id(slot_id)
	if previous_branch_id == &"":
		return false

	equipped_branch_ids_by_slot_id[slot_id] = &""
	standard_slot_changed.emit(slot_id, previous_branch_id, &"")
	return true


func clear_runtime_loadout_for_testing() -> void:
	if not OS.is_debug_build():
		push_warning("BranchLoadoutService test reset is debug-build only.")
		return
	equipped_branch_ids_by_slot_id.clear()


func _is_standard_slot_id(slot_id: StringName) -> bool:
	return BranchSlotRules.is_standard_slot(
		BranchSlotRules.get_slot_index(slot_id)
	)


func _is_valid_standard_branch(
	slot_id: StringName,
	branch_id: StringName
) -> bool:
	if not _is_standard_slot_id(slot_id) or branch_id == &"":
		return false
	var definition: BranchDefinition = GameContent.get_branch(branch_id)
	if not is_instance_valid(definition):
		return false
	return (
		definition.is_valid_definition()
		and definition.is_standard_branch()
		and definition.branch_scene != null
		and BranchSlotRules.can_place_definition(
			definition,
			BranchSlotRules.get_slot_index(slot_id)
		)
	)
