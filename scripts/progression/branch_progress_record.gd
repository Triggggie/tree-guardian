class_name BranchProgressRecord
extends RefCounted


var branch_id: StringName

var branch_level: int = 1
var current_xp: int = 0

var available_talent_points: int = 0
var total_talent_points_earned: int = 0

var purchased_talents: Dictionary = {}
var upgrade_levels: Dictionary = {}


func duplicate_record() -> BranchProgressRecord:
	var duplicated_record := BranchProgressRecord.new()

	duplicated_record.branch_id = branch_id
	duplicated_record.branch_level = branch_level
	duplicated_record.current_xp = current_xp
	duplicated_record.available_talent_points = available_talent_points
	duplicated_record.total_talent_points_earned = total_talent_points_earned
	duplicated_record.purchased_talents = purchased_talents.duplicate(true)
	duplicated_record.upgrade_levels = upgrade_levels.duplicate(true)

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


func get_upgrade_level(
	upgrade_id: StringName
) -> int:
	if upgrade_id == &"":
		return 0

	return max(int(upgrade_levels.get(upgrade_id, 0)), 0)


func set_upgrade_level(
	upgrade_id: StringName,
	new_level: int
) -> bool:
	if upgrade_id == &"" or new_level < 0:
		return false

	upgrade_levels[upgrade_id] = new_level
	return true


func is_valid_record() -> bool:
	if branch_id == &"" or branch_level < 1 or current_xp < 0:
		return false

	if available_talent_points < 0 or total_talent_points_earned < 0:
		return false

	if available_talent_points > total_talent_points_earned:
		return false

	for talent_id in purchased_talents:
		if StringName(talent_id) == &"":
			return false

	for upgrade_id in upgrade_levels:
		if StringName(upgrade_id) == &"":
			return false

		if int(upgrade_levels[upgrade_id]) < 0:
			return false

	return true
