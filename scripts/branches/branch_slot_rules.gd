class_name BranchSlotRules
extends RefCounted


const FIRST_STANDARD_SLOT: int = 1
const LAST_STANDARD_SLOT: int = 4
const APEX_SLOT: int = 5
const TOTAL_SLOT_COUNT: int = 5

const STANDARD_SLOT_1_ID: StringName = &"standard_slot_1"
const STANDARD_SLOT_2_ID: StringName = &"standard_slot_2"
const STANDARD_SLOT_3_ID: StringName = &"standard_slot_3"
const STANDARD_SLOT_4_ID: StringName = &"standard_slot_4"
const APEX_SLOT_ID: StringName = &"apex_slot"


static func get_slot_id(
	slot_index: int
) -> StringName:
	match slot_index:
		1:
			return STANDARD_SLOT_1_ID
		2:
			return STANDARD_SLOT_2_ID
		3:
			return STANDARD_SLOT_3_ID
		4:
			return STANDARD_SLOT_4_ID
		5:
			return APEX_SLOT_ID

	return &""


static func get_slot_index(
	slot_id: StringName
) -> int:
	match slot_id:
		STANDARD_SLOT_1_ID:
			return 1
		STANDARD_SLOT_2_ID:
			return 2
		STANDARD_SLOT_3_ID:
			return 3
		STANDARD_SLOT_4_ID:
			return 4
		APEX_SLOT_ID:
			return 5

	return -1


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
