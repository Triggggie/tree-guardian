class_name BranchTalentLoadoutRecord
extends RefCounted


var slot_id: StringName = &""
var branch_id: StringName = &""

var purchased_talents: Dictionary = {}


func duplicate_record() -> BranchTalentLoadoutRecord:
	var duplicated_record := BranchTalentLoadoutRecord.new()

	duplicated_record.slot_id = slot_id
	duplicated_record.branch_id = branch_id
	duplicated_record.purchased_talents = purchased_talents.duplicate(true)

	return duplicated_record


func is_talent_purchased(
	talent_id: StringName
) -> bool:
	if talent_id == &"":
		return false

	return bool(purchased_talents.get(talent_id, false))


func get_purchased_talent_ids() -> Array[StringName]:
	var talent_ids: Array[StringName] = []

	for talent_id in purchased_talents:
		if bool(purchased_talents[talent_id]):
			talent_ids.append(StringName(talent_id))

	return talent_ids


func set_talent_purchased(
	talent_id: StringName,
	purchased: bool = true
) -> bool:
	if talent_id == &"":
		return false

	if purchased:
		purchased_talents[talent_id] = true
	else:
		purchased_talents.erase(talent_id)

	return true


func is_valid_record() -> bool:
	if slot_id == &"" or BranchSlotRules.get_slot_index(slot_id) < 0:
		return false

	if branch_id == &"":
		return false

	for talent_id in purchased_talents:
		if StringName(talent_id) == &"":
			return false

	return true
