class_name BranchLoadoutService
extends Node


signal standard_slot_changed(
	slot_id: StringName,
	previous_branch_id: StringName,
	new_branch_id: StringName
)

signal apex_slot_changed(
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
	var standard_loadout: Dictionary = {}
	for slot_index in range(
		BranchSlotRules.FIRST_STANDARD_SLOT,
		BranchSlotRules.LAST_STANDARD_SLOT + 1
	):
		var slot_id: StringName = BranchSlotRules.get_slot_id(slot_index)
		if equipped_branch_ids_by_slot_id.has(slot_id):
			standard_loadout[slot_id] = equipped_branch_ids_by_slot_id[slot_id]
	return standard_loadout


func get_full_loadout_copy() -> Dictionary:
	return equipped_branch_ids_by_slot_id.duplicate(true)


func export_persistence_state() -> Dictionary:
	var stored_loadout: Dictionary = {}
	for slot_index in range(
		BranchSlotRules.FIRST_STANDARD_SLOT,
		BranchSlotRules.APEX_SLOT + 1
	):
		var slot_id: StringName = BranchSlotRules.get_slot_id(slot_index)
		if equipped_branch_ids_by_slot_id.has(slot_id):
			stored_loadout[String(slot_id)] = String(
				equipped_branch_ids_by_slot_id[slot_id]
			)
	return stored_loadout


func restore_persistence_state(
	stored_loadout: Dictionary,
	branch_seeds: BranchSeedService
) -> bool:
	var restored_loadout: Dictionary = {}
	for slot_index in range(
		BranchSlotRules.FIRST_STANDARD_SLOT,
		BranchSlotRules.LAST_STANDARD_SLOT + 1
	):
		var slot_id: StringName = BranchSlotRules.get_slot_id(slot_index)
		var stored_key: String = String(slot_id)
		if not stored_loadout.has(stored_key) and not stored_loadout.has(slot_id):
			continue
		var branch_id := StringName(str(
			stored_loadout.get(stored_key, stored_loadout.get(slot_id, ""))
		))
		if branch_id == &"" or _is_valid_standard_branch(slot_id, branch_id):
			restored_loadout[slot_id] = branch_id
		else:
			push_warning(
				"BranchLoadout skipped invalid Standard Branch '%s' for %s."
				% [branch_id, slot_id]
			)

	var apex_slot_id: StringName = BranchSlotRules.APEX_SLOT_ID
	var apex_key: String = String(apex_slot_id)
	if stored_loadout.has(apex_key) or stored_loadout.has(apex_slot_id):
		var apex_branch_id := StringName(str(
			stored_loadout.get(
				apex_key,
				stored_loadout.get(apex_slot_id, "")
			)
		))
		if apex_branch_id == &"":
			restored_loadout[apex_slot_id] = &""
		elif (
			_is_valid_apex_branch(apex_branch_id)
			and is_instance_valid(branch_seeds)
			and branch_seeds.is_branch_seed_unlocked(apex_branch_id)
		):
			restored_loadout[apex_slot_id] = apex_branch_id
		else:
			push_warning(
				"BranchLoadout rejected locked or invalid saved Apex '%s'."
				% apex_branch_id
			)
			restored_loadout[apex_slot_id] = &""

	var previous_loadout: Dictionary = equipped_branch_ids_by_slot_id
	equipped_branch_ids_by_slot_id = restored_loadout
	for slot_index in range(
		BranchSlotRules.FIRST_STANDARD_SLOT,
		BranchSlotRules.LAST_STANDARD_SLOT + 1
	):
		var slot_id: StringName = BranchSlotRules.get_slot_id(slot_index)
		var previous_id := StringName(previous_loadout.get(slot_id, &""))
		var restored_id := StringName(restored_loadout.get(slot_id, &""))
		if previous_id != restored_id:
			standard_slot_changed.emit(slot_id, previous_id, restored_id)
	var previous_apex := StringName(previous_loadout.get(apex_slot_id, &""))
	var restored_apex := StringName(restored_loadout.get(apex_slot_id, &""))
	if previous_apex != restored_apex:
		apex_slot_changed.emit(previous_apex, restored_apex)
	return true


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


func is_apex_slot_initialized() -> bool:
	return equipped_branch_ids_by_slot_id.has(BranchSlotRules.APEX_SLOT_ID)


func ensure_apex_slot_initialized(
	default_branch_id: StringName = &""
) -> bool:
	if is_apex_slot_initialized():
		return false
	if default_branch_id != &"" and not _is_valid_apex_branch(default_branch_id):
		return false
	equipped_branch_ids_by_slot_id[BranchSlotRules.APEX_SLOT_ID] = default_branch_id
	apex_slot_changed.emit(&"", default_branch_id)
	return true


func get_equipped_apex_branch_id() -> StringName:
	if not is_apex_slot_initialized():
		return &""
	return StringName(
		equipped_branch_ids_by_slot_id[BranchSlotRules.APEX_SLOT_ID]
	)


func equip_apex_branch(branch_id: StringName) -> bool:
	if not _is_valid_apex_branch(branch_id):
		return false
	var previous_branch_id: StringName = get_equipped_apex_branch_id()
	if is_apex_slot_initialized() and previous_branch_id == branch_id:
		return false
	equipped_branch_ids_by_slot_id[BranchSlotRules.APEX_SLOT_ID] = branch_id
	apex_slot_changed.emit(previous_branch_id, branch_id)
	return true


func unequip_apex_branch() -> bool:
	if not is_apex_slot_initialized():
		return false
	var previous_branch_id: StringName = get_equipped_apex_branch_id()
	if previous_branch_id == &"":
		return false
	equipped_branch_ids_by_slot_id[BranchSlotRules.APEX_SLOT_ID] = &""
	apex_slot_changed.emit(previous_branch_id, &"")
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


func _is_valid_apex_branch(branch_id: StringName) -> bool:
	if branch_id == &"":
		return false
	var definition: BranchDefinition = GameContent.get_branch(branch_id)
	if not is_instance_valid(definition):
		return false
	return (
		definition.is_valid_definition()
		and definition.is_legendary_branch()
		and definition.branch_scene != null
		and BranchSlotRules.can_place_definition(
			definition,
			BranchSlotRules.APEX_SLOT
		)
	)
