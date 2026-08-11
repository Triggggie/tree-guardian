class_name BranchProgressService
extends Node


signal progress_changed(branch_id: StringName)
signal xp_changed(branch_id: StringName, current_xp: int, xp_required: int)
signal level_changed(branch_id: StringName, new_level: int)
signal talent_budget_changed(branch_id: StringName, total_points_earned: int)
signal talent_loadout_changed(slot_id: StringName, branch_id: StringName)
signal talent_changed(
	slot_id: StringName,
	branch_id: StringName,
	talent_id: StringName,
	is_purchased: bool
)
signal upgrade_changed(
	branch_id: StringName,
	upgrade_id: StringName,
	new_level: int
)


var progress_by_branch_id: Dictionary = {}
var registered_branches_by_id: Dictionary = {}
var talent_loadouts_by_slot_id: Dictionary = {}


func register_branch(branch: CombatBranch) -> bool:
	if not _is_usable_branch(branch):
		return false

	var branch_id: StringName = branch.branch_id
	var registered_branches: Array = registered_branches_by_id.get(branch_id, [])
	_prune_invalid_branches(registered_branches)

	if not registered_branches.has(branch):
		registered_branches.append(branch)

	registered_branches_by_id[branch_id] = registered_branches
	_get_or_create_progress(branch)
	_get_or_create_talent_loadout(branch.get_slot_id(), branch_id)
	return synchronize_branch(branch)


func unregister_branch(branch: CombatBranch) -> void:
	if not is_instance_valid(branch):
		return

	var branch_id: StringName = branch.branch_id
	if not registered_branches_by_id.has(branch_id):
		return

	var registered_branches: Array = registered_branches_by_id[branch_id]
	registered_branches.erase(branch)
	_prune_invalid_branches(registered_branches)

	if registered_branches.is_empty():
		registered_branches_by_id.erase(branch_id)
	else:
		registered_branches_by_id[branch_id] = registered_branches


func get_progress(branch_id: StringName) -> BranchProgressRecord:
	if branch_id == &"":
		return null

	return progress_by_branch_id.get(branch_id) as BranchProgressRecord


func get_progress_copy(branch_id: StringName) -> BranchProgressRecord:
	var progress: BranchProgressRecord = get_progress(branch_id)
	return null if progress == null else progress.duplicate_record()


func get_talent_loadout(
	slot_id: StringName,
	branch_id: StringName
) -> BranchTalentLoadoutRecord:
	if BranchSlotRules.get_slot_index(slot_id) < 0 or branch_id == &"":
		return null

	var loadouts_by_branch: Dictionary = talent_loadouts_by_slot_id.get(slot_id, {})
	return loadouts_by_branch.get(branch_id) as BranchTalentLoadoutRecord


func get_talent_loadout_copy(
	slot_id: StringName,
	branch_id: StringName
) -> BranchTalentLoadoutRecord:
	var loadout: BranchTalentLoadoutRecord = get_talent_loadout(slot_id, branch_id)
	return null if loadout == null else loadout.duplicate_record()


func get_talent_loadout_for_branch(
	branch: CombatBranch
) -> BranchTalentLoadoutRecord:
	if not _is_usable_branch(branch):
		return null

	return get_talent_loadout(branch.get_slot_id(), branch.branch_id)


func get_spent_talent_points(branch: CombatBranch) -> int:
	var loadout: BranchTalentLoadoutRecord = get_talent_loadout_for_branch(branch)
	if loadout == null:
		return 0

	var spent_points: int = 0
	for talent_id in loadout.get_purchased_talent_ids():
		var talent: TalentDefinition = branch.get_talent_definition(talent_id)
		if not is_instance_valid(talent):
			push_warning(
				"Stored talent '%s' is unknown for %s in %s."
				% [talent_id, branch.branch_id, branch.get_slot_id()]
			)
			continue

		spent_points += max(talent.talent_point_cost, 0)

	return spent_points


func get_available_talent_points(branch: CombatBranch) -> int:
	if not _is_usable_branch(branch):
		return 0

	var progress: BranchProgressRecord = get_progress(branch.branch_id)
	if progress == null:
		return 0

	return max(progress.total_talent_points_earned - get_spent_talent_points(branch), 0)


func add_xp(branch: CombatBranch, amount: int) -> bool:
	if amount <= 0 or not _is_registered_branch(branch):
		return false

	var progress: BranchProgressRecord = get_progress(branch.branch_id)
	if progress == null:
		return false

	var xp_required: int = branch.get_safe_xp_required_per_level()
	var previous_level: int = progress.branch_level
	var previous_total_points: int = progress.total_talent_points_earned
	var gained_talent_levels: Array[int] = []
	progress.current_xp += amount

	while progress.current_xp >= xp_required:
		progress.current_xp -= xp_required
		progress.branch_level += 1
		if progress.branch_level in branch.talent_point_levels:
			progress.total_talent_points_earned += 1
			gained_talent_levels.append(progress.branch_level)

	_synchronize_registered_branches(branch.branch_id)
	_emit_instance_progress_signals(
		branch.branch_id,
		true,
		progress.branch_level != previous_level,
		progress.total_talent_points_earned != previous_total_points,
		&"",
		&"",
		&"",
		gained_talent_levels
	)
	progress_changed.emit(branch.branch_id)
	xp_changed.emit(branch.branch_id, progress.current_xp, xp_required)

	if progress.branch_level != previous_level:
		level_changed.emit(branch.branch_id, progress.branch_level)
	if progress.total_talent_points_earned != previous_total_points:
		talent_budget_changed.emit(branch.branch_id, progress.total_talent_points_earned)

	return true


func purchase_talent(branch: CombatBranch, talent_id: StringName) -> bool:
	if talent_id == &"" or not _is_registered_branch(branch):
		return false

	var progress: BranchProgressRecord = get_progress(branch.branch_id)
	var loadout: BranchTalentLoadoutRecord = get_talent_loadout_for_branch(branch)
	var talent: TalentDefinition = branch.get_talent_definition(talent_id)
	if progress == null or loadout == null or not is_instance_valid(talent):
		return false
	if loadout.is_talent_purchased(talent_id):
		return false
	if progress.branch_level < talent.required_branch_level:
		return false
	if get_available_talent_points(branch) < talent.talent_point_cost:
		return false

	for prerequisite_id in talent.prerequisite_ids:
		if not loadout.is_talent_purchased(prerequisite_id):
			return false
	for conflicting_id in talent.conflicting_ids:
		if loadout.is_talent_purchased(conflicting_id):
			return false
	if not loadout.set_talent_purchased(talent_id):
		return false

	_synchronize_registered_loadout(branch.get_slot_id(), branch.branch_id)
	_emit_instance_progress_signals(
		branch.branch_id,
		false,
		false,
		true,
		branch.get_slot_id(),
		talent_id
	)
	progress_changed.emit(branch.branch_id)
	talent_loadout_changed.emit(branch.get_slot_id(), branch.branch_id)
	talent_changed.emit(branch.get_slot_id(), branch.branch_id, talent_id, true)
	return true


func purchase_upgrade(branch: CombatBranch, upgrade_id: StringName) -> bool:
	if upgrade_id == &"" or not _is_registered_branch(branch):
		return false

	var progress: BranchProgressRecord = get_progress(branch.branch_id)
	var upgrade: UpgradeDefinition = branch.get_upgrade_definition(upgrade_id)
	if progress == null or not is_instance_valid(upgrade):
		return false

	var current_level: int = progress.get_upgrade_level(upgrade_id)
	if not branch.can_apply_progress_upgrade(upgrade_id, current_level):
		return false

	var cost: int = upgrade.get_cost_for_level(current_level)
	if not branch.try_spend_essence(cost):
		return false

	var new_level: int = current_level + 1
	if not progress.set_upgrade_level(upgrade_id, new_level):
		return false

	_synchronize_registered_branches(branch.branch_id)
	_emit_instance_progress_signals(branch.branch_id, false, false, false, &"", &"", upgrade_id)
	progress_changed.emit(branch.branch_id)
	upgrade_changed.emit(branch.branch_id, upgrade_id, new_level)
	return true


func synchronize_branch(branch: CombatBranch) -> bool:
	if not _is_usable_branch(branch):
		return false

	var progress: BranchProgressRecord = get_progress(branch.branch_id)
	if progress == null:
		progress = _get_or_create_progress(branch)
	var loadout: BranchTalentLoadoutRecord = _get_or_create_talent_loadout(
		branch.get_slot_id(), branch.branch_id
	)
	if progress == null or loadout == null:
		return false
	if not progress.is_valid_record() or not loadout.is_valid_record():
		return false
	if not _validate_talent_loadout(branch, loadout):
		return false

	branch.apply_progress_state(progress, loadout, get_available_talent_points(branch))
	return true


func clear_runtime_progress_for_testing() -> void:
	if not OS.is_debug_build():
		push_warning("BranchProgressService test reset is debug-build only.")
		return

	progress_by_branch_id.clear()
	registered_branches_by_id.clear()
	talent_loadouts_by_slot_id.clear()


func _get_or_create_progress(branch: CombatBranch) -> BranchProgressRecord:
	var existing_progress: BranchProgressRecord = get_progress(branch.branch_id)
	if existing_progress != null:
		return existing_progress

	var progress := BranchProgressRecord.new()
	progress.branch_id = branch.branch_id
	for upgrade_id in branch.get_upgrade_ids():
		progress.set_upgrade_level(upgrade_id, 0)
	progress_by_branch_id[branch.branch_id] = progress
	return progress


func _get_or_create_talent_loadout(
	slot_id: StringName,
	branch_id: StringName
) -> BranchTalentLoadoutRecord:
	if BranchSlotRules.get_slot_index(slot_id) < 0 or branch_id == &"":
		return null

	var existing: BranchTalentLoadoutRecord = get_talent_loadout(slot_id, branch_id)
	if existing != null:
		return existing

	var loadout := BranchTalentLoadoutRecord.new()
	loadout.slot_id = slot_id
	loadout.branch_id = branch_id
	var loadouts_by_branch: Dictionary = talent_loadouts_by_slot_id.get(slot_id, {})
	loadouts_by_branch[branch_id] = loadout
	talent_loadouts_by_slot_id[slot_id] = loadouts_by_branch
	return loadout


func _validate_talent_loadout(
	branch: CombatBranch,
	loadout: BranchTalentLoadoutRecord
) -> bool:
	for talent_id in loadout.get_purchased_talent_ids():
		if not is_instance_valid(branch.get_talent_definition(talent_id)):
			push_warning(
				"Stored talent '%s' is unknown for %s in %s; synchronization was skipped."
				% [talent_id, branch.branch_id, branch.get_slot_id()]
			)
			return false

	return true


func _is_usable_branch(branch: CombatBranch) -> bool:
	return (
		is_instance_valid(branch)
		and branch.branch_id != &""
		and branch.get_slot_id() != &""
		and is_instance_valid(branch.branch_definition)
		and branch.branch_definition.branch_id == branch.branch_id
	)


func _is_registered_branch(branch: CombatBranch) -> bool:
	if not _is_usable_branch(branch):
		return false
	var registered_branches: Array = registered_branches_by_id.get(branch.branch_id, [])
	return registered_branches.has(branch)


func _prune_invalid_branches(registered_branches: Array) -> void:
	for index in range(registered_branches.size() - 1, -1, -1):
		if not is_instance_valid(registered_branches[index]):
			registered_branches.remove_at(index)


func _synchronize_registered_branches(branch_id: StringName) -> void:
	var registered_branches: Array = registered_branches_by_id.get(branch_id, [])
	_prune_invalid_branches(registered_branches)
	for branch in registered_branches:
		synchronize_branch(branch as CombatBranch)


func _synchronize_registered_loadout(slot_id: StringName, branch_id: StringName) -> void:
	var registered_branches: Array = registered_branches_by_id.get(branch_id, [])
	_prune_invalid_branches(registered_branches)
	for branch_value in registered_branches:
		var branch := branch_value as CombatBranch
		if branch.get_slot_id() == slot_id:
			synchronize_branch(branch)


func _emit_instance_progress_signals(
	branch_id: StringName,
	emit_xp: bool,
	emit_level: bool,
	emit_talent_points: bool,
	slot_id: StringName = &"",
	talent_id: StringName = &"",
	upgrade_id: StringName = &"",
	gained_talent_levels: Array[int] = []
) -> void:
	var progress: BranchProgressRecord = get_progress(branch_id)
	if progress == null:
		return

	var registered_branches: Array = registered_branches_by_id.get(branch_id, [])
	_prune_invalid_branches(registered_branches)
	for branch_value in registered_branches:
		var branch := branch_value as CombatBranch
		var branch_available: int = get_available_talent_points(branch)
		if emit_level:
			branch.level_changed.emit(progress.branch_level)
		if emit_talent_points:
			branch.talent_points_changed.emit(branch_available, progress.total_talent_points_earned)
		for talent_level in gained_talent_levels:
			branch.talent_point_gained.emit(talent_level, branch_available)
		if talent_id != &"" and branch.get_slot_id() == slot_id:
			branch.talent_changed.emit(talent_id, true)
		if upgrade_id != &"":
			branch.upgrade_changed.emit(upgrade_id, progress.get_upgrade_level(upgrade_id))
		if emit_xp:
			branch.xp_changed.emit(progress.current_xp, branch.get_safe_xp_required_per_level())
