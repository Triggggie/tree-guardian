extends Control


enum PickerMode {
	NONE,
	STANDARD,
	APEX
}

@onready var close_button: Button = $MainPanel/CloseButton
@onready var detail_title_label: Label = $MainPanel/DetailPanel/DetailTitleLabel
@onready var category_label: Label = $MainPanel/DetailPanel/CategoryLabel
@onready var shared_progress_label: Label = $MainPanel/DetailPanel/SharedProgressLabel
@onready var talent_build_label: Label = $MainPanel/DetailPanel/TalentBuildLabel
@onready var upgrades_label: Label = $MainPanel/DetailPanel/UpgradesLabel
@onready var stats_label: Label = $MainPanel/DetailPanel/StatsLabel
@onready var seed_list_label: Label = $MainPanel/SeedPanel/SeedListLabel
@onready var preparation_banner: Label = $MainPanel/PreparationBanner
@onready var continue_button: Button = $MainPanel/ContinueButton
@onready var loadout_status_label: Label = $MainPanel/DetailPanel/LoadoutStatusLabel
@onready var change_branch_button: Button = $MainPanel/DetailPanel/ChangeBranchButton
@onready var branch_picker: Panel = $BranchPicker
@onready var picker_title_label: Label = $BranchPicker/TitleLabel
@onready var candidate_list: VBoxContainer = $BranchPicker/CandidateList
@onready var candidate_name_label: Label = $BranchPicker/PreviewPanel/NameLabel
@onready var candidate_category_label: Label = $BranchPicker/PreviewPanel/CategoryLabel
@onready var candidate_description_label: Label = $BranchPicker/PreviewPanel/DescriptionLabel
@onready var candidate_progress_label: Label = $BranchPicker/PreviewPanel/ProgressLabel
@onready var candidate_saved_build_label: Label = $BranchPicker/PreviewPanel/SavedBuildLabel
@onready var confirm_candidate_button: Button = $BranchPicker/ConfirmButton
@onready var cancel_picker_button: Button = $BranchPicker/CancelButton

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
var preparation_active: bool = false
var preparation_reason: StringName = &""
var candidate_definitions: Array[BranchDefinition] = []
var candidate_buttons_by_branch_id: Dictionary = {}
var selected_candidate_branch_id: StringName = &""
var wave_manager: Node
var picker_mode: PickerMode = PickerMode.NONE


func _ready() -> void:
	close_button.pressed.connect(close_screen)
	continue_button.pressed.connect(_on_continue_pressed)
	change_branch_button.pressed.connect(open_branch_picker)
	confirm_candidate_button.pressed.connect(confirm_selected_branch_candidate)
	cancel_picker_button.pressed.connect(close_branch_picker)
	for slot_id in slot_buttons:
		var button: Button = slot_buttons[slot_id]
		button.pressed.connect(select_slot.bind(StringName(slot_id)))
	_connect_loadout_controller()
	_connect_branch_seed_service()
	hide()


func open_screen() -> void:
	refresh_screen()
	show()


func close_screen() -> void:
	if preparation_active:
		return
	close_branch_picker()
	hide()


func set_preparation_mode(
	is_active: bool,
	reason: StringName
) -> void:
	preparation_active = is_active
	preparation_reason = reason if is_active else &""
	preparation_banner.visible = is_active
	continue_button.visible = is_active
	close_button.visible = not is_active
	close_button.disabled = is_active
	if is_active:
		match reason:
			&"substage_complete":
				preparation_banner.text = "PREPARATION\nSUBSTAGE COMPLETE"
				continue_button.text = "CONTINUE"
			&"retry":
				preparation_banner.text = "PREPARATION\nRETRY SUBSTAGE"
				continue_button.text = "RETRY SUBSTAGE"
			_:
				preparation_banner.text = "PREPARATION\nBUILD YOUR TREE"
				continue_button.text = "START RUN"
	else:
		close_branch_picker()
	if is_node_ready():
		_refresh_loadout_controls()


func refresh_screen() -> void:
	_disconnect_branch_signals()
	_find_active_branches()
	_connect_branch_signals()
	_refresh_slot_buttons()
	_validate_selection()
	_refresh_selected_detail()
	_refresh_seed_panel()
	_refresh_loadout_controls()


func select_slot(slot_id: StringName) -> void:
	if BranchSlotRules.get_slot_index(slot_id) < 0:
		return
	selected_slot_id = slot_id
	_refresh_slot_buttons()
	_refresh_selected_detail()
	_refresh_loadout_controls()


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

	detail_title_label.text = (
		"APEX\n%s" % branch.get_branch_display_name()
		if branch.get_slot_id() == BranchSlotRules.APEX_SLOT_ID
		else "SLOT %d\n%s" % [branch.slot_index, branch.get_branch_display_name()]
	)
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


func _refresh_loadout_controls() -> void:
	var slot_index: int = BranchSlotRules.get_slot_index(selected_slot_id)
	var is_standard_slot: bool = BranchSlotRules.is_standard_slot(slot_index)
	var is_apex_slot: bool = BranchSlotRules.is_apex_slot(slot_index)
	var edit_allowed: bool = _is_branch_loadout_edit_allowed()
	if is_apex_slot:
		var apex_candidates: Array[BranchDefinition] = _get_apex_candidate_definitions()
		change_branch_button.disabled = not edit_allowed or apex_candidates.is_empty()
		if not edit_allowed:
			change_branch_button.text = "LOADOUT UNAVAILABLE"
			loadout_status_label.text = "LOADOUT UNAVAILABLE\nTree is defeated."
		elif apex_candidates.is_empty():
			change_branch_button.text = "NO LEGENDARY BRANCH SEEDS"
			loadout_status_label.text = "Unlock a Legendary Branch Seed to select an Apex Branch."
		else:
			change_branch_button.text = "SELECT APEX BRANCH"
			loadout_status_label.text = "APEX LOADOUT EDITING ENABLED"
		return

	change_branch_button.disabled = not is_standard_slot or not edit_allowed
	if is_standard_slot and edit_allowed:
		change_branch_button.text = "CHANGE BRANCH"
		loadout_status_label.text = "LOADOUT EDITING ENABLED"
	elif is_standard_slot:
		change_branch_button.text = "LOADOUT UNAVAILABLE"
		loadout_status_label.text = "LOADOUT UNAVAILABLE\nTree is defeated."
	else:
		change_branch_button.text = "BRANCH PICKER UNAVAILABLE"
		loadout_status_label.text = "LOADOUT LOCKED"


func open_branch_picker() -> bool:
	if not _is_branch_loadout_edit_allowed():
		return false
	var slot_index: int = BranchSlotRules.get_slot_index(selected_slot_id)
	if BranchSlotRules.is_standard_slot(slot_index):
		picker_mode = PickerMode.STANDARD
	elif BranchSlotRules.is_apex_slot(slot_index):
		picker_mode = PickerMode.APEX
	else:
		return false

	_rebuild_candidate_collection()
	if candidate_definitions.is_empty():
		picker_mode = PickerMode.NONE
		return false
	picker_title_label.text = (
		"CHOOSE APEX BRANCH"
		if picker_mode == PickerMode.APEX
		else "CHOOSE BRANCH FOR SLOT %d" % slot_index
	)
	branch_picker.show()
	var current_branch_id: StringName = _get_equipped_branch_id(selected_slot_id)
	var initial_candidate_id: StringName = candidate_definitions[0].branch_id
	for definition in candidate_definitions:
		if definition.branch_id == current_branch_id:
			initial_candidate_id = current_branch_id
			break
	select_branch_candidate(initial_candidate_id)
	return true


func close_branch_picker() -> void:
	branch_picker.hide()
	selected_candidate_branch_id = &""
	picker_mode = PickerMode.NONE


func _rebuild_candidate_collection() -> void:
	candidate_definitions.clear()
	candidate_buttons_by_branch_id.clear()
	for child in candidate_list.get_children():
		child.queue_free()

	var available_definitions: Array[BranchDefinition] = []
	if picker_mode == PickerMode.APEX:
		available_definitions = _get_apex_candidate_definitions()
	else:
		for definition in GameContent.get_branches():
			if _is_valid_standard_candidate(definition, selected_slot_id):
				available_definitions.append(definition)

	for definition in available_definitions:
		candidate_definitions.append(definition)
		var candidate_button := Button.new()
		candidate_button.text = definition.display_name
		candidate_button.toggle_mode = true
		candidate_button.pressed.connect(
			select_branch_candidate.bind(definition.branch_id)
		)
		candidate_list.add_child(candidate_button)
		candidate_buttons_by_branch_id[definition.branch_id] = candidate_button


func _is_valid_standard_candidate(
	definition: BranchDefinition,
	slot_id: StringName
) -> bool:
	var slot_index: int = BranchSlotRules.get_slot_index(slot_id)
	return (
		is_instance_valid(definition)
		and definition.is_valid_definition()
		and definition.is_standard_branch()
		and definition.branch_scene != null
		and BranchSlotRules.is_standard_slot(slot_index)
		and BranchSlotRules.can_place_definition(definition, slot_index)
	)


func _is_valid_apex_definition(definition: BranchDefinition) -> bool:
	return (
		is_instance_valid(definition)
		and definition.is_valid_definition()
		and definition.is_legendary_branch()
		and definition.get_legendary_tier() in [
			BranchDefinition.LEGENDARY_TIER_1,
			BranchDefinition.LEGENDARY_TIER_2,
			BranchDefinition.LEGENDARY_TIER_3
		]
		and definition.branch_scene != null
		and BranchSlotRules.can_place_definition(
			definition,
			BranchSlotRules.APEX_SLOT
		)
	)


func _get_apex_candidate_definitions() -> Array[BranchDefinition]:
	var definitions: Array[BranchDefinition] = []
	var seed_service := get_node_or_null("/root/BranchSeeds") as BranchSeedService
	if not is_instance_valid(seed_service):
		return definitions
	for branch_id in seed_service.get_unlocked_branch_seed_ids():
		var definition: BranchDefinition = GameContent.get_branch(branch_id)
		if _is_valid_apex_definition(definition):
			definitions.append(definition)
	return definitions


func select_branch_candidate(branch_id: StringName) -> bool:
	var definition: BranchDefinition = GameContent.get_branch(branch_id)
	var valid_candidate: bool = (
		_is_valid_apex_definition(definition)
		if picker_mode == PickerMode.APEX
		else _is_valid_standard_candidate(definition, selected_slot_id)
	)
	if not valid_candidate:
		return false
	selected_candidate_branch_id = branch_id
	_refresh_candidate_buttons()
	_refresh_candidate_preview(definition)
	return true


func _refresh_candidate_buttons() -> void:
	var current_branch_id: StringName = _get_equipped_branch_id(selected_slot_id)
	for definition in candidate_definitions:
		var button: Button = candidate_buttons_by_branch_id.get(
			definition.branch_id
		) as Button
		if not is_instance_valid(button):
			continue
		button.button_pressed = definition.branch_id == selected_candidate_branch_id
		button.text = definition.display_name
		if definition.branch_id == current_branch_id:
			button.text += "\nEQUIPPED"


func _refresh_candidate_preview(definition: BranchDefinition) -> void:
	candidate_name_label.text = definition.display_name
	candidate_category_label.text = _get_category_text(definition)
	candidate_description_label.text = definition.description
	_refresh_candidate_progress(definition.branch_id)
	_refresh_candidate_saved_build(definition)
	var is_current: bool = (
		definition.branch_id == _get_equipped_branch_id(selected_slot_id)
	)
	confirm_candidate_button.disabled = is_current
	confirm_candidate_button.text = "EQUIPPED" if is_current else "EQUIP"


func _refresh_candidate_progress(branch_id: StringName) -> void:
	var progress_service := get_node_or_null(
		"/root/BranchProgress"
	) as BranchProgressService
	var progress: BranchProgressRecord = null
	if is_instance_valid(progress_service):
		progress = progress_service.get_progress_copy(branch_id)
	if progress == null:
		candidate_progress_label.text = (
			"SHARED ARCHETYPE PROGRESS\n"
			+ "No progression recorded yet."
		)
		return

	var xp_text: String = "XP %d" % progress.current_xp
	for branch_value in branches_by_slot.values():
		var branch := branch_value as CombatBranch
		if is_instance_valid(branch) and branch.branch_id == branch_id:
			xp_text = "XP %d / %d" % [
				progress.current_xp,
				branch.get_safe_xp_required_per_level()
			]
			break
	candidate_progress_label.text = (
		"SHARED ARCHETYPE PROGRESS\nLevel %d\n%s\nTalent Points Earned %d"
		% [
			progress.branch_level,
			xp_text,
			progress.total_talent_points_earned
		]
	)


func _refresh_candidate_saved_build(definition: BranchDefinition) -> void:
	var slot_index: int = BranchSlotRules.get_slot_index(selected_slot_id)
	var is_apex: bool = BranchSlotRules.is_apex_slot(slot_index)
	var lines: Array[String] = [
		"SAVED APEX BUILD" if is_apex else "SAVED BUILD FOR SLOT %d" % slot_index
	]
	var progress_service := get_node_or_null(
		"/root/BranchProgress"
	) as BranchProgressService
	var loadout: BranchTalentLoadoutRecord = null
	if is_instance_valid(progress_service):
		loadout = progress_service.get_talent_loadout_copy(
			selected_slot_id,
			definition.branch_id
		)
	var found_talent: bool = false
	if loadout != null and is_instance_valid(definition.talent_tree):
		for talent in definition.talent_tree.talents:
			if (
				is_instance_valid(talent)
				and loadout.is_talent_purchased(talent.talent_id)
			):
				lines.append(talent.display_name)
				found_talent = true
	if not found_talent:
		lines.append(
			"No saved Apex talents."
			if is_apex
			else "No saved talents for this slot."
		)
	candidate_saved_build_label.text = "\n".join(lines)


func confirm_selected_branch_candidate() -> bool:
	if not _is_branch_loadout_edit_allowed():
		return false
	var slot_index: int = BranchSlotRules.get_slot_index(selected_slot_id)
	var definition: BranchDefinition = GameContent.get_branch(
		selected_candidate_branch_id
	)
	if BranchSlotRules.is_apex_slot(slot_index):
		var seed_service := get_node_or_null("/root/BranchSeeds") as BranchSeedService
		if (
			selected_candidate_branch_id == &""
			or not is_instance_valid(seed_service)
			or not seed_service.is_branch_seed_unlocked(selected_candidate_branch_id)
			or not _is_valid_apex_definition(definition)
			or _get_equipped_branch_id(selected_slot_id) == definition.branch_id
		):
			return false
		var apex_loadout := get_node_or_null("/root/BranchLoadout") as BranchLoadoutService
		return (
			is_instance_valid(apex_loadout)
			and apex_loadout.equip_apex_branch(definition.branch_id)
		)

	if not BranchSlotRules.is_standard_slot(slot_index):
		return false
	if not _is_valid_standard_candidate(definition, selected_slot_id):
		return false
	if _get_equipped_branch_id(selected_slot_id) == definition.branch_id:
		return false
	var loadout := get_node_or_null("/root/BranchLoadout") as BranchLoadoutService
	if not is_instance_valid(loadout):
		return false
	return loadout.equip_standard_branch(
		selected_slot_id,
		definition.branch_id
	)


func _get_equipped_branch_id(slot_id: StringName) -> StringName:
	var loadout := get_node_or_null("/root/BranchLoadout") as BranchLoadoutService
	if not is_instance_valid(loadout):
		return &""
	if slot_id == BranchSlotRules.APEX_SLOT_ID:
		return loadout.get_equipped_apex_branch_id()
	return loadout.get_equipped_branch_id(slot_id)


func _is_standard_loadout_edit_allowed() -> bool:
	return _is_branch_loadout_edit_allowed()


func _is_branch_loadout_edit_allowed() -> bool:
	if not is_instance_valid(wave_manager):
		wave_manager = get_tree().get_first_node_in_group("wave_manager")
	return (
		is_instance_valid(wave_manager)
		and wave_manager.has_method("is_branch_loadout_edit_allowed")
		and wave_manager.is_branch_loadout_edit_allowed()
	)


func _on_continue_pressed() -> void:
	close_branch_picker()
	if not is_instance_valid(wave_manager):
		wave_manager = get_tree().get_first_node_in_group("wave_manager")
	if (
		is_instance_valid(wave_manager)
		and wave_manager.has_method("continue_from_preparation")
	):
		wave_manager.continue_from_preparation()


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


func _connect_loadout_controller() -> void:
	var controller: TreeBranchLoadoutController = get_tree().get_first_node_in_group(
		"branch_loadout_controller"
	) as TreeBranchLoadoutController
	if (
		is_instance_valid(controller)
		and not controller.runtime_standard_slot_changed.is_connected(
			_on_runtime_standard_slot_changed
		)
	):
		controller.runtime_standard_slot_changed.connect(
			_on_runtime_standard_slot_changed
		)
	if (
		is_instance_valid(controller)
		and not controller.runtime_apex_slot_changed.is_connected(
			_on_runtime_apex_slot_changed
		)
	):
		controller.runtime_apex_slot_changed.connect(
			_on_runtime_apex_slot_changed
		)


func _on_runtime_standard_slot_changed(
	slot_id: StringName,
	_branch_id: StringName
) -> void:
	if visible:
		refresh_screen()
	if branch_picker.visible and slot_id == selected_slot_id:
		close_branch_picker()


func _on_runtime_apex_slot_changed(
	_branch_id: StringName
) -> void:
	if visible:
		refresh_screen()
	if branch_picker.visible and selected_slot_id == BranchSlotRules.APEX_SLOT_ID:
		close_branch_picker()


func _connect_branch_seed_service() -> void:
	var seed_service := get_node_or_null("/root/BranchSeeds") as BranchSeedService
	if (
		is_instance_valid(seed_service)
		and not seed_service.branch_seed_unlocked.is_connected(
			_on_branch_seed_unlocked
		)
	):
		seed_service.branch_seed_unlocked.connect(_on_branch_seed_unlocked)


func _on_branch_seed_unlocked(_branch_id: StringName) -> void:
	if not visible:
		return
	_refresh_seed_panel()
	_refresh_loadout_controls()
	if not branch_picker.visible or picker_mode != PickerMode.APEX:
		return
	var previous_candidate_id: StringName = selected_candidate_branch_id
	_rebuild_candidate_collection()
	if candidate_definitions.is_empty():
		close_branch_picker()
		return
	for definition in candidate_definitions:
		if definition.branch_id == previous_candidate_id:
			select_branch_candidate(previous_candidate_id)
			return
	select_branch_candidate(candidate_definitions[0].branch_id)
