class_name BranchSlotRules
extends RefCounted


const FIRST_STANDARD_SLOT: int = 1
const LAST_STANDARD_SLOT: int = 4
const APEX_SLOT: int = 5
const TOTAL_SLOT_COUNT: int = 5


static func is_valid_slot_index(
	slot_index: int
) -> bool:
	return (
		slot_index >= FIRST_STANDARD_SLOT
		and slot_index <= APEX_SLOT
	)


static func is_standard_slot(
	slot_index: int
) -> bool:
	return (
		slot_index >= FIRST_STANDARD_SLOT
		and slot_index <= LAST_STANDARD_SLOT
	)


static func is_apex_slot(
	slot_index: int
) -> bool:
	return slot_index == APEX_SLOT


static func can_place_definition(
	branch_definition: BranchDefinition,
	slot_index: int
) -> bool:
	if not is_valid_slot_index(slot_index):
		return false

	if not is_instance_valid(branch_definition):
		return false

	if not branch_definition.is_valid_definition():
		return false

	if branch_definition.is_standard_branch():
		return is_standard_slot(slot_index)

	if branch_definition.is_legendary_branch():
		return is_apex_slot(slot_index)

	return false
