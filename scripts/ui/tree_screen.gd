extends Control


@onready var close_button: Button = $MainPanel/CloseButton
@onready var detail_title_label: Label = $MainPanel/DetailPanel/DetailTitleLabel
@onready var category_label: Label = $MainPanel/DetailPanel/CategoryLabel
@onready var shared_progress_label: Label = $MainPanel/DetailPanel/SharedProgressLabel
@onready var talent_build_label: Label = $MainPanel/DetailPanel/TalentBuildLabel
@onready var upgrades_label: Label = $MainPanel/DetailPanel/UpgradesLabel
@onready var stats_label: Label = $MainPanel/DetailPanel/StatsLabel
@onready var seed_list_label: Label = $MainPanel/SeedPanel/SeedListLabel

@onready var slot_buttons: Dictionary = {
	BranchSlotRules.STANDARD_SLOT_1_ID: $MainPanel/TreeCanvas/Slot1Button,
	BranchSlotRules.STANDARD_SLOT_2_ID: $MainPanel/TreeCanvas/Slot2Button,
	BranchSlotRules.STANDARD_SLOT_3_ID: $MainPanel/TreeCanvas/Slot3Button,
	BranchSlotRules.STANDARD_SLOT_4_ID: $MainPanel/TreeCanvas/Slot4Button,
	BranchSlotRules.APEX_SLOT_ID: $MainPanel/TreeCanvas/ApexButton
}

var selected_slot_id: StringName = &""
var branches_by_slot: Dictionary = {}
var connected_branches: Array[CombatBranch] = []


func _ready() -> void:
	close_button.pressed.connect(close_screen)
	for slot_id in slot_buttons:
		var button: Button = slot_buttons[slot_id]
		button.pressed.connect(select_slot.bind(StringName(slot_id)))
	hide()


func open_screen() -> void:
	refresh_screen()
	show()


func close_screen() -> void:
	hide()


func refresh_screen() -> void:
	_disconnect_branch_signals()
	_find_active_branches()
	_connect_branch_signals()
	_refresh_slot_buttons()
	_validate_selection()
	_refresh_selected_detail()
	_refresh_seed_panel()


func select_slot(slot_id: StringName) -> void:
	if BranchSlotRules.get_slot_index(slot_id) < 0:
		return
	selected_slot_id = slot_id
	_refresh_slot_buttons()
	_refresh_selected_detail()


func _find_active_branches() -> void:
	branches_by_slot.clear()
	for node in get_tree().get_nodes_in_group("combat_branch"):
		if node is not CombatBranch or not is_instance_valid(node):
			continue
		var branch := node as CombatBranch
		if not branch.is_slot_assignment_valid():
			continue
		branches_by_slot[branch.get_slot_id()] = branch


func _validate_selection() -> void:
	if BranchSlotRules.get_slot_index(selected_slot_id) >= 0:
		return
	for slot_index in range(BranchSlotRules.FIRST_STANDARD_SLOT, BranchSlotRules.LAST_STANDARD_SLOT + 1):
		var slot_id: StringName = BranchSlotRules.get_slot_id(slot_index)
		if is_instance_valid(branches_by_slot.get(slot_id)):
			selected_slot_id = slot_id
			return
	selected_slot_id = BranchSlotRules.STANDARD_SLOT_1_ID


func _refresh_slot_buttons() -> void:
	for slot_id_value in slot_buttons:
		var slot_id := StringName(slot_id_value)
		var button: Button = slot_buttons[slot_id]
		var branch: CombatBranch = branches_by_slot.get(slot_id) as CombatBranch
		var slot_index: int = BranchSlotRules.get_slot_index(slot_id)
		if slot_id == BranchSlotRules.APEX_SLOT_ID:
			button.text = "APEX\n%s" % (_get_short_branch_name(branch) if is_instance_valid(branch) else "EMPTY")
		else:
			button.text = "SLOT %d\n%s" % [slot_index, _get_short_branch_name(branch) if is_instance_valid(branch) else "EMPTY"]
		button.disabled = false
		button.button_pressed = slot_id == selected_slot_id


func _refresh_selected_detail() -> void:
	var branch: CombatBranch = branches_by_slot.get(selected_slot_id) as CombatBranch
	if not is_instance_valid(branch):
		_refresh_empty_detail()
		return

	var progress_service := get_node_or_null("/root/BranchProgress") as BranchProgressService
	var progress: BranchProgressRecord = null
	if is_instance_valid(progress_service):
		progress = progress_service.get_progress(branch.branch_id)

	detail_title_label.text = "SLOT %d\n%s" % [branch.slot_index, branch.get_branch_display_name()]
	category_label.text = _get_category_text(branch.branch_definition)
	if progress == null:
		shared_progress_label.text = "SHARED ARCHETYPE PROGRESS\nUnavailable"
	else:
		shared_progress_label.text = "SHARED ARCHETYPE PROGRESS\nLevel %d\nXP %d / %d\nTalent Points Earned %d" % [progress.branch_level, progress.current_xp, branch.get_safe_xp_required_per_level(), progress.total_talent_points_earned]

	var purchased_names: Array[String] = []
	for talent_id in branch.get_talent_ids():
		if branch.has_talent(talent_id):
			purchased_names.append(branch.get_talent_display_name(talent_id))
	var talent_lines: Array[String] = ["THIS SLOT TALENT BUILD", "Available Talent Points: %d" % branch.get_available_talent_points()]
	if purchased_names.is_empty():
		talent_lines.append("No talents selected.")
	else:
		talent_lines.append_array(purchased_names)
	talent_build_label.text = "\n".join(talent_lines)

	var upgrade_lines: Array[String] = ["ESSENCE UPGRADES"]
	for upgrade_id in branch.get_upgrade_ids():
		upgrade_lines.append("%s — Lv.%d" % [branch.get_upgrade_display_name(upgrade_id), branch.get_upgrade_level(upgrade_id)])
	upgrades_label.text = "\n".join(upgrade_lines)

	var stat_lines: Array[String] = ["EFFECTIVE STATS"]
	stat_lines.append_array(branch.get_stat_summary_lines())
	stats_label.text = "\n".join(stat_lines)


func _refresh_empty_detail() -> void:
	if selected_slot_id == BranchSlotRules.APEX_SLOT_ID:
		detail_title_label.text = "APEX SLOT\nEMPTY"
		category_label.text = "Legendary Branches can be equipped here.\nApex Branches act on both sides of the tree."
	else:
		detail_title_label.text = "SLOT %d\nEMPTY" % BranchSlotRules.get_slot_index(selected_slot_id)
		category_label.text = "No Branch equipped."
	shared_progress_label.text = ""
	talent_build_label.text = ""
	upgrades_label.text = ""
	stats_label.text = ""


func _refresh_seed_panel() -> void:
	var seed_service := get_node_or_null("/root/BranchSeeds") as BranchSeedService
	if not is_instance_valid(seed_service):
		seed_list_label.text = "No Legendary Branch Seeds unlocked."
		return
	var unlocked_ids: Array[StringName] = seed_service.get_unlocked_branch_seed_ids()
	if unlocked_ids.is_empty():
		seed_list_label.text = "No Legendary Branch Seeds unlocked."
		return
	var lines: Array[String] = []
	for branch_id in unlocked_ids:
		var definition: BranchDefinition = GameContent.get_branch(branch_id)
		if not is_instance_valid(definition) or not definition.is_legendary_branch():
			lines.append("Unknown Branch Seed\n%s" % branch_id)
			continue
		lines.append("%s — %s" % [definition.display_name, definition.get_legendary_tier_display_name()])
	seed_list_label.text = "\n\n".join(lines)


func _get_short_branch_name(branch: CombatBranch) -> String:
	return branch.get_branch_display_name().replace(" Branch", "").to_upper()


func _get_category_text(definition: BranchDefinition) -> String:
	if not is_instance_valid(definition):
		return "UNKNOWN"
	if definition.is_legendary_branch():
		return "LEGENDARY • %s" % definition.get_legendary_tier_display_name()
	return "STANDARD"


func _connect_branch_signals() -> void:
	for branch_value in branches_by_slot.values():
		var branch := branch_value as CombatBranch
		if not is_instance_valid(branch):
			continue
		_connect_signal(branch.level_changed, _on_level_changed)
		_connect_signal(branch.xp_changed, _on_xp_changed)
		_connect_signal(branch.talent_points_changed, _on_talent_points_changed)
		_connect_signal(branch.talent_changed, _on_talent_changed)
		_connect_signal(branch.upgrade_changed, _on_upgrade_changed)
		connected_branches.append(branch)


func _connect_signal(source_signal: Signal, callback: Callable) -> void:
	if not source_signal.is_connected(callback):
		source_signal.connect(callback)


func _disconnect_branch_signals() -> void:
	for branch in connected_branches:
		if not is_instance_valid(branch):
			continue
		_disconnect_signal(branch.level_changed, _on_level_changed)
		_disconnect_signal(branch.xp_changed, _on_xp_changed)
		_disconnect_signal(branch.talent_points_changed, _on_talent_points_changed)
		_disconnect_signal(branch.talent_changed, _on_talent_changed)
		_disconnect_signal(branch.upgrade_changed, _on_upgrade_changed)
	connected_branches.clear()


func _disconnect_signal(source_signal: Signal, callback: Callable) -> void:
	if source_signal.is_connected(callback):
		source_signal.disconnect(callback)


func _refresh_if_selected(branch_id: StringName) -> void:
	var selected_branch: CombatBranch = branches_by_slot.get(selected_slot_id) as CombatBranch
	if is_instance_valid(selected_branch) and selected_branch.branch_id == branch_id:
		_refresh_selected_detail()


func _on_level_changed(_level: int) -> void:
	_refresh_selected_detail()


func _on_xp_changed(_xp: int, _required: int) -> void:
	_refresh_selected_detail()


func _on_talent_points_changed(_available: int, _total: int) -> void:
	_refresh_selected_detail()


func _on_talent_changed(_talent_id: StringName, _purchased: bool) -> void:
	_refresh_selected_detail()


func _on_upgrade_changed(_upgrade_id: StringName, _level: int) -> void:
	_refresh_selected_detail()
