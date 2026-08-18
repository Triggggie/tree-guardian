extends Control


enum PickerMode {
	NONE,
	STANDARD,
	APEX
}

enum SelectionMode {
	BRANCH,
	EQUIPMENT,
	INVENTORY
}

enum TreeView {
	TREE,
	INVENTORY
}

const ITEM_METADATA_SEPARATOR: String = " - "

@onready var close_button: Button = $MainPanel/CloseButton
@onready var tree_button: Button = $MainPanel/TreeButton
@onready var inventory_button: Button = $MainPanel/InventoryButton
@onready var tree_canvas: Panel = $MainPanel/TreeCanvas
@onready var detail_title_label: Label = $MainPanel/DetailPanel/DetailScroll/DetailContent/DetailTitleLabel
@onready var category_label: Label = $MainPanel/DetailPanel/DetailScroll/DetailContent/CategoryLabel
@onready var shared_progress_label: Label = $MainPanel/DetailPanel/DetailScroll/DetailContent/SharedProgressLabel
@onready var talent_build_label: Label = $MainPanel/DetailPanel/DetailScroll/DetailContent/TalentBuildLabel
@onready var upgrades_label: Label = $MainPanel/DetailPanel/DetailScroll/DetailContent/UpgradesLabel
@onready var stats_label: Label = $MainPanel/DetailPanel/DetailScroll/DetailContent/StatsLabel
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
@onready var detail_panel: Panel = $MainPanel/DetailPanel
@onready var seed_panel: Panel = $MainPanel/SeedPanel
@onready var equipment_detail_panel: Panel = $MainPanel/EquipmentDetailPanel
@onready var equipment_title_label: Label = $MainPanel/EquipmentDetailPanel/TitleLabel
@onready var currently_equipped_label: Label = $MainPanel/EquipmentDetailPanel/CurrentlyEquippedLabel
@onready var selected_item_label: Label = $MainPanel/EquipmentDetailPanel/SelectedItemLabel
@onready var equipment_status_label: Label = $MainPanel/EquipmentDetailPanel/StatusLabel
@onready var equip_button: Button = $MainPanel/EquipmentDetailPanel/EquipButton
@onready var unequip_button: Button = $MainPanel/EquipmentDetailPanel/UnequipButton
@onready var equipment_inventory_panel: Panel = $MainPanel/EquipmentInventoryPanel
@onready var equipment_inventory_title: Label = $MainPanel/EquipmentInventoryPanel/TitleLabel
@onready var equipment_candidate_list: VBoxContainer = $MainPanel/EquipmentInventoryPanel/ScrollContainer/CandidateList
@onready var equipment_empty_label: Label = $MainPanel/EquipmentInventoryPanel/EmptyLabel
@onready var inventory_overview_panel: Panel = $MainPanel/InventoryOverviewPanel
@onready var inventory_item_count_label: Label = $MainPanel/InventoryOverviewPanel/ItemCountLabel
@onready var inventory_filter_container: HBoxContainer = $MainPanel/InventoryOverviewPanel/FilterContainer
@onready var inventory_item_grid: GridContainer = $MainPanel/InventoryOverviewPanel/ScrollContainer/ItemGrid
@onready var inventory_overview_empty_label: Label = $MainPanel/InventoryOverviewPanel/EmptyLabel
@onready var debug_reset_button: Button = $MainPanel/DebugResetButton
@onready var debug_reset_confirmation: ConfirmationDialog = $DebugResetConfirmation
@onready var equipment_slot_buttons: Dictionary = {
	EquipmentSlotRules.BARK_SLOT_ID: $MainPanel/TreeCanvas/BarkButton,
	EquipmentSlotRules.ROOTS_SLOT_ID: $MainPanel/TreeCanvas/RootsButton,
	EquipmentSlotRules.HEARTWOOD_SLOT_ID: $MainPanel/TreeCanvas/HeartwoodButton,
	EquipmentSlotRules.CANOPY_SLOT_ID: $MainPanel/TreeCanvas/CanopyButton,
	EquipmentSlotRules.SAP_SLOT_ID: $MainPanel/TreeCanvas/SapButton
}

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
var selection_mode: SelectionMode = SelectionMode.BRANCH
var active_view: TreeView = TreeView.TREE
var selected_equipment_slot_id: StringName = &""
var selected_equipment_instance_id: StringName = &""
var equipment_candidate_buttons_by_instance_id: Dictionary = {}
var inventory_filter_buttons_by_slot_id: Dictionary = {}
var inventory_filter_slot_id: StringName = &""
var visible_inventory_item_count: int = 0
var inventory_service: InventoryService
var equipment_service: EquipmentService


func _ready() -> void:
	close_button.pressed.connect(close_screen)
	tree_button.pressed.connect(open_tree_view)
	inventory_button.pressed.connect(open_inventory_overview)
	continue_button.pressed.connect(_on_continue_pressed)
	change_branch_button.pressed.connect(open_branch_picker)
	confirm_candidate_button.pressed.connect(confirm_selected_branch_candidate)
	cancel_picker_button.pressed.connect(close_branch_picker)
	equip_button.pressed.connect(equip_selected_equipment)
	unequip_button.pressed.connect(unequip_selected_equipment)
	debug_reset_button.visible = OS.is_debug_build()
	debug_reset_button.pressed.connect(_request_debug_progress_reset)
	debug_reset_confirmation.confirmed.connect(_confirm_debug_progress_reset)
	for slot_id in slot_buttons:
		var button: Button = slot_buttons[slot_id]
		button.pressed.connect(select_slot.bind(StringName(slot_id)))
	for slot_id in equipment_slot_buttons:
		var button: Button = equipment_slot_buttons[slot_id]
		button.pressed.connect(select_equipment_slot.bind(StringName(slot_id)))
	_create_inventory_filter_buttons()
	_connect_loadout_controller()
	_connect_branch_seed_service()
	_connect_equipment_services()
	hide()


func open_screen() -> void:
	active_view = TreeView.TREE
	if selection_mode == SelectionMode.INVENTORY:
		selection_mode = SelectionMode.BRANCH
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
		if selection_mode in [SelectionMode.EQUIPMENT, SelectionMode.INVENTORY]:
			_refresh_equipment_ui()


func refresh_screen() -> void:
	_disconnect_branch_signals()
	_find_active_branches()
	_connect_branch_signals()
	_refresh_slot_buttons()
	_refresh_equipment_slot_buttons()
	if selection_mode in [SelectionMode.EQUIPMENT, SelectionMode.INVENTORY]:
		_validate_equipment_selection()
		_refresh_equipment_ui()
	else:
		_validate_selection()
		_refresh_selected_detail()
	_refresh_seed_panel()
	_refresh_loadout_controls()
	_refresh_mode_visibility()


func select_slot(slot_id: StringName) -> void:
	if BranchSlotRules.get_slot_index(slot_id) < 0:
		return
	close_branch_picker()
	active_view = TreeView.TREE
	selection_mode = SelectionMode.BRANCH
	selected_slot_id = slot_id
	selected_equipment_slot_id = &""
	selected_equipment_instance_id = &""
	_refresh_slot_buttons()
	_refresh_selected_detail()
	_refresh_loadout_controls()
	_refresh_mode_visibility()


func select_equipment_slot(slot_id: StringName) -> bool:
	if not EquipmentSlotRules.is_valid_slot_id(slot_id):
		return false
	close_branch_picker()
	active_view = TreeView.TREE
	selection_mode = SelectionMode.EQUIPMENT
	selected_equipment_slot_id = slot_id
	selected_equipment_instance_id = &""
	if is_instance_valid(equipment_service):
		selected_equipment_instance_id = equipment_service.get_equipped_instance_id(
			slot_id
		)
	inventory_filter_slot_id = slot_id
	_refresh_inventory_filter_buttons()
	_refresh_slot_buttons()
	_refresh_equipment_slot_buttons()
	_refresh_equipment_ui()
	_refresh_mode_visibility()
	return true


func open_inventory_overview() -> void:
	close_branch_picker()
	active_view = TreeView.INVENTORY
	selection_mode = SelectionMode.INVENTORY
	selected_equipment_slot_id = &""
	_validate_equipment_selection()
	_refresh_slot_buttons()
	_refresh_equipment_slot_buttons()
	_refresh_equipment_ui()
	_refresh_mode_visibility()


func open_tree_view() -> void:
	close_branch_picker()
	active_view = TreeView.TREE
	selection_mode = SelectionMode.BRANCH
	selected_equipment_slot_id = &""
	_validate_selection()
	_refresh_slot_buttons()
	_refresh_equipment_slot_buttons()
	_refresh_selected_detail()
	_refresh_loadout_controls()
	_refresh_mode_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if branch_picker.visible:
		close_branch_picker()
	elif active_view == TreeView.INVENTORY:
		open_tree_view()
	else:
		close_screen()
	get_viewport().set_input_as_handled()


func select_inventory_filter(slot_id: StringName) -> bool:
	if slot_id != &"" and not EquipmentSlotRules.is_valid_slot_id(slot_id):
		return false
	inventory_filter_slot_id = slot_id
	_refresh_inventory_filter_buttons()
	if selection_mode == SelectionMode.INVENTORY:
		_refresh_equipment_ui()
	return true


func _create_inventory_filter_buttons() -> void:
	for child in inventory_filter_container.get_children():
		child.queue_free()
	inventory_filter_buttons_by_slot_id.clear()
	var filter_slot_ids: Array[StringName] = [&""]
	filter_slot_ids.append_array(EquipmentSlotRules.get_supported_slot_ids())
	for slot_id in filter_slot_ids:
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(145.0, 44.0)
		button.text = (
			"ALL"
			if slot_id == &""
			else EquipmentSlotRules.get_slot_display_name(slot_id).to_upper()
		)
		button.pressed.connect(select_inventory_filter.bind(slot_id))
		inventory_filter_container.add_child(button)
		inventory_filter_buttons_by_slot_id[slot_id] = button
	_refresh_inventory_filter_buttons()


func _refresh_inventory_filter_buttons() -> void:
	for slot_id_value in inventory_filter_buttons_by_slot_id:
		var slot_id := StringName(slot_id_value)
		var button := inventory_filter_buttons_by_slot_id[slot_id] as Button
		if is_instance_valid(button):
			button.button_pressed = slot_id == inventory_filter_slot_id


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
		var branch: CombatBranch = _get_runtime_branch_for_slot(slot_id)
		var slot_index: int = BranchSlotRules.get_slot_index(slot_id)
		if slot_id == BranchSlotRules.APEX_SLOT_ID:
			button.text = "APEX\n%s" % (_get_short_branch_name(branch) if is_instance_valid(branch) else "EMPTY")
		else:
			button.text = "SLOT %d\n%s" % [slot_index, _get_short_branch_name(branch) if is_instance_valid(branch) else "EMPTY"]
		button.disabled = false
		button.button_pressed = slot_id == selected_slot_id


func _refresh_equipment_slot_buttons() -> void:
	for slot_id_value in equipment_slot_buttons:
		var slot_id := StringName(slot_id_value)
		var button: Button = equipment_slot_buttons[slot_id]
		var item: ItemInstance = null
		if is_instance_valid(equipment_service):
			item = equipment_service.get_equipped_item(slot_id)
		button.icon = null
		if item != null:
			var definition: ItemDefinition = GameContent.get_item(item.definition_id)
			if is_instance_valid(definition):
				_apply_item_tile_presentation(button, item, definition, false)
		else:
			_apply_empty_equipment_slot_presentation(button, slot_id)
		button.button_pressed = (
			selection_mode == SelectionMode.EQUIPMENT
			and slot_id == selected_equipment_slot_id
		)


func _refresh_mode_visibility() -> void:
	var equipment_slot_mode: bool = (
		active_view == TreeView.TREE
		and selection_mode == SelectionMode.EQUIPMENT
	)
	var inventory_mode: bool = active_view == TreeView.INVENTORY
	detail_panel.visible = not equipment_slot_mode and not inventory_mode
	seed_panel.visible = not equipment_slot_mode and not inventory_mode
	tree_canvas.visible = not inventory_mode
	equipment_detail_panel.visible = equipment_slot_mode or inventory_mode
	equipment_inventory_panel.visible = equipment_slot_mode
	inventory_overview_panel.visible = inventory_mode
	tree_button.disabled = not inventory_mode
	inventory_button.disabled = inventory_mode


func _validate_equipment_selection() -> void:
	if (
		selection_mode == SelectionMode.EQUIPMENT
		and not EquipmentSlotRules.is_valid_slot_id(selected_equipment_slot_id)
	):
		selected_equipment_slot_id = EquipmentSlotRules.BARK_SLOT_ID
	if (
		selected_equipment_instance_id == &""
		or not is_instance_valid(inventory_service)
	):
		return
	var selected_item: ItemInstance = inventory_service.get_item(
		selected_equipment_instance_id
	)
	if selected_item == null:
		selected_equipment_instance_id = &""
		return
	var definition: ItemDefinition = GameContent.get_item(
		selected_item.definition_id
	)
	if not is_instance_valid(definition):
		selected_equipment_instance_id = &""
	elif (
		selection_mode == SelectionMode.EQUIPMENT
		and definition.equipment_slot_id != selected_equipment_slot_id
	):
		selected_equipment_instance_id = &""


func _refresh_equipment_ui() -> void:
	_validate_equipment_selection()
	if selection_mode == SelectionMode.INVENTORY:
		_refresh_inventory_overview()
		return
	_rebuild_equipment_candidate_list()
	var slot_name: String = EquipmentSlotRules.get_slot_display_name(
		selected_equipment_slot_id
	)
	equipment_title_label.text = "%s EQUIPMENT" % slot_name.to_upper()
	equipment_inventory_title.text = "%s INVENTORY" % slot_name.to_upper()
	equipment_empty_label.text = "No %s items in inventory." % slot_name
	var equipped_item: ItemInstance = null
	if is_instance_valid(equipment_service):
		equipped_item = equipment_service.get_equipped_item(
			selected_equipment_slot_id
		)
	currently_equipped_label.text = _format_item_detail(
		"CURRENTLY EQUIPPED",
		equipped_item,
		"EMPTY"
	)
	var selected_item: ItemInstance = null
	if is_instance_valid(inventory_service):
		selected_item = inventory_service.get_item(
			selected_equipment_instance_id
		)
	selected_item_label.text = _format_item_detail(
		"SELECTED ITEM",
		selected_item,
		"Select an item from inventory."
	)
	var edit_allowed: bool = _is_branch_loadout_edit_allowed()
	var selected_is_equipped: bool = (
		selected_item != null
		and is_instance_valid(equipment_service)
		and equipment_service.is_item_equipped(selected_item.instance_id)
	)
	equip_button.disabled = (
		not edit_allowed
		or selected_item == null
		or selected_is_equipped
	)
	equip_button.text = "EQUIPPED" if selected_is_equipped else "EQUIP"
	unequip_button.disabled = not edit_allowed or equipped_item == null
	equipment_status_label.text = (
		"EQUIPMENT EDITING ENABLED"
		if edit_allowed
		else "EQUIPMENT UNAVAILABLE\nTree is defeated."
	)


func _refresh_inventory_overview() -> void:
	_rebuild_inventory_overview_cards()
	var owned_item_count: int = (
		inventory_service.get_item_count()
		if is_instance_valid(inventory_service)
		else 0
	)
	inventory_item_count_label.text = "Items: %d  Owned: %d" % [
		visible_inventory_item_count,
		owned_item_count
	]
	equipment_title_label.text = "INVENTORY ITEM"
	var selected_item: ItemInstance = null
	if is_instance_valid(inventory_service):
		selected_item = inventory_service.get_item(selected_equipment_instance_id)
	var equipped_item: ItemInstance = null
	if selected_item != null and is_instance_valid(equipment_service):
		var definition: ItemDefinition = GameContent.get_item(selected_item.definition_id)
		if is_instance_valid(definition):
			equipped_item = equipment_service.get_equipped_item(
				definition.equipment_slot_id
			)
	currently_equipped_label.text = _format_item_detail(
		"CURRENTLY EQUIPPED IN THIS SLOT",
		equipped_item,
		"EMPTY"
	)
	selected_item_label.text = _format_item_detail(
		"SELECTED ITEM",
		selected_item,
		"Select an item card."
	)
	var edit_allowed: bool = _is_branch_loadout_edit_allowed()
	var selected_is_equipped: bool = (
		selected_item != null
		and is_instance_valid(equipment_service)
		and equipment_service.is_item_equipped(selected_item.instance_id)
	)
	equip_button.disabled = not edit_allowed or selected_item == null or selected_is_equipped
	equip_button.text = "EQUIPPED" if selected_is_equipped else "EQUIP"
	unequip_button.disabled = not edit_allowed or not selected_is_equipped
	equipment_status_label.text = (
		"EQUIPMENT EDITING ENABLED"
		if edit_allowed
		else "EQUIPMENT UNAVAILABLE\nTree is defeated."
	)


func _rebuild_inventory_overview_cards() -> void:
	equipment_candidate_buttons_by_instance_id.clear()
	for child in inventory_item_grid.get_children():
		child.queue_free()
	var items: Array[ItemInstance] = []
	if is_instance_valid(inventory_service):
		items = inventory_service.get_items()
	items.sort_custom(_inventory_item_precedes)
	visible_inventory_item_count = 0
	for item in items:
		var definition: ItemDefinition = GameContent.get_item(item.definition_id)
		if not is_instance_valid(definition):
			continue
		if (
			is_instance_valid(equipment_service)
			and equipment_service.is_item_equipped(item.instance_id)
		):
			continue
		if (
			inventory_filter_slot_id != &""
			and definition.equipment_slot_id != inventory_filter_slot_id
		):
			continue
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(230.0, 170.0)
		_apply_item_tile_presentation(button, item, definition, true)
		button.button_pressed = item.instance_id == selected_equipment_instance_id
		button.pressed.connect(select_equipment_candidate.bind(item.instance_id))
		inventory_item_grid.add_child(button)
		equipment_candidate_buttons_by_instance_id[item.instance_id] = button
		visible_inventory_item_count += 1
	inventory_overview_empty_label.visible = visible_inventory_item_count == 0
	inventory_overview_empty_label.text = (
		"No equipment in inventory.\nDrops from enemies will appear here."
		if inventory_filter_slot_id == &""
		else "No %s equipment in inventory."
		% EquipmentSlotRules.get_slot_display_name(inventory_filter_slot_id)
	)


func _format_inventory_card(
	item: ItemInstance,
	definition: ItemDefinition
) -> String:
	var lines: Array[String] = []
	if definition.icon == null:
		lines.append(_get_slot_fallback_text(definition.equipment_slot_id))
	lines.append(definition.display_name)
	lines.append(ItemRarityRules.get_rarity_display_name(item.rarity_id).to_upper())
	lines.append("ILvl %d%s%s" % [
		item.item_level,
		ITEM_METADATA_SEPARATOR,
		EquipmentSlotRules.get_slot_display_name(definition.equipment_slot_id)
	])
	if item.is_locked:
		lines.append("LOCKED")
	return "\n".join(lines)


func _apply_item_tile_presentation(
	button: Button,
	item: ItemInstance,
	definition: ItemDefinition,
	include_slot: bool
) -> void:
	button.text = _format_inventory_card(item, definition) if include_slot else (
		"%s\n%s\nILvl %d%s%s" % [
			definition.display_name,
			ItemRarityRules.get_rarity_display_name(item.rarity_id).to_upper(),
			item.item_level,
			ITEM_METADATA_SEPARATOR,
			EquipmentSlotRules.get_slot_display_name(definition.equipment_slot_id)
		]
	)
	button.icon = definition.icon
	button.expand_icon = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 15 if include_slot else 12)
	var rarity_color: Color = ItemRarityRules.get_rarity_color(item.rarity_id)
	button.add_theme_color_override("font_color", rarity_color)
	var tile_style := StyleBoxFlat.new()
	tile_style.bg_color = Color(0.035, 0.065, 0.045, 0.96)
	tile_style.border_color = rarity_color
	tile_style.set_border_width_all(3)
	tile_style.set_corner_radius_all(8)
	tile_style.content_margin_left = 8.0
	tile_style.content_margin_top = 8.0
	tile_style.content_margin_right = 8.0
	tile_style.content_margin_bottom = 8.0
	button.add_theme_stylebox_override("normal", tile_style)
	button.add_theme_stylebox_override("hover", tile_style.duplicate())
	button.add_theme_stylebox_override("pressed", tile_style.duplicate())


func _apply_empty_equipment_slot_presentation(
	button: Button,
	slot_id: StringName
) -> void:
	button.icon = null
	button.text = "%s\nEMPTY" % EquipmentSlotRules.get_slot_display_name(
		slot_id
	).to_upper()
	button.remove_theme_color_override("font_color")
	for state_name in [&"normal", &"hover", &"pressed"]:
		button.remove_theme_stylebox_override(state_name)


func _get_slot_fallback_text(slot_id: StringName) -> String:
	match slot_id:
		EquipmentSlotRules.BARK_SLOT_ID:
			return "BARK"
		EquipmentSlotRules.ROOTS_SLOT_ID:
			return "ROOT"
		EquipmentSlotRules.HEARTWOOD_SLOT_ID:
			return "HEART"
		EquipmentSlotRules.CANOPY_SLOT_ID:
			return "CANOPY"
		EquipmentSlotRules.SAP_SLOT_ID:
			return "SAP"
	return "ITEM"


func _rebuild_equipment_candidate_list() -> void:
	equipment_candidate_buttons_by_instance_id.clear()
	for child in equipment_candidate_list.get_children():
		child.queue_free()
	var items: Array[ItemInstance] = []
	if is_instance_valid(inventory_service):
		items = inventory_service.get_items_for_slot(selected_equipment_slot_id)
	items.sort_custom(_inventory_item_precedes)
	var available_item_count: int = 0
	for item in items:
		var definition: ItemDefinition = GameContent.get_item(item.definition_id)
		if not is_instance_valid(definition):
			continue
		if (
			is_instance_valid(equipment_service)
			and equipment_service.is_item_equipped(item.instance_id)
		):
			continue
		var button := Button.new()
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0.0, 76.0)
		button.text = "%s\n%s%sItem Level %d" % [
			definition.display_name,
			ItemRarityRules.get_rarity_display_name(item.rarity_id),
			ITEM_METADATA_SEPARATOR,
			item.item_level
		]
		button.clip_text = true
		button.add_theme_font_size_override("font_size", 16)
		if (
			is_instance_valid(equipment_service)
			and equipment_service.is_item_equipped(item.instance_id)
		):
			button.text += "\nEQUIPPED"
		button.button_pressed = item.instance_id == selected_equipment_instance_id
		button.add_theme_color_override(
			"font_color",
			ItemRarityRules.get_rarity_color(item.rarity_id)
		)
		button.pressed.connect(
			select_equipment_candidate.bind(item.instance_id)
		)
		equipment_candidate_list.add_child(button)
		equipment_candidate_buttons_by_instance_id[item.instance_id] = button
		available_item_count += 1
	equipment_empty_label.visible = available_item_count == 0


func _inventory_item_precedes(
	item_a: ItemInstance,
	item_b: ItemInstance
) -> bool:
	var rarity_a: int = ItemRarityRules.get_rarity_rank(item_a.rarity_id)
	var rarity_b: int = ItemRarityRules.get_rarity_rank(item_b.rarity_id)
	if rarity_a != rarity_b:
		return rarity_a > rarity_b
	if item_a.item_level != item_b.item_level:
		return item_a.item_level > item_b.item_level
	var definition_a: ItemDefinition = GameContent.get_item(item_a.definition_id)
	var definition_b: ItemDefinition = GameContent.get_item(item_b.definition_id)
	var name_a: String = definition_a.display_name if is_instance_valid(definition_a) else ""
	var name_b: String = definition_b.display_name if is_instance_valid(definition_b) else ""
	if name_a != name_b:
		return name_a.naturalnocasecmp_to(name_b) < 0
	return String(item_a.instance_id) < String(item_b.instance_id)


func select_equipment_candidate(instance_id: StringName) -> bool:
	if selection_mode not in [SelectionMode.EQUIPMENT, SelectionMode.INVENTORY]:
		return false
	if not is_instance_valid(inventory_service):
		return false
	var item: ItemInstance = inventory_service.get_item(instance_id)
	if item == null:
		return false
	var definition: ItemDefinition = GameContent.get_item(item.definition_id)
	if (
		not is_instance_valid(definition)
		or (
			selection_mode == SelectionMode.EQUIPMENT
			and definition.equipment_slot_id != selected_equipment_slot_id
		)
	):
		return false
	selected_equipment_instance_id = instance_id
	_refresh_equipment_ui()
	return true


func equip_selected_equipment() -> bool:
	if (
		selection_mode not in [SelectionMode.EQUIPMENT, SelectionMode.INVENTORY]
		or not _is_branch_loadout_edit_allowed()
		or not is_instance_valid(equipment_service)
	):
		return false
	return equipment_service.equip_item(selected_equipment_instance_id)


func unequip_selected_equipment() -> bool:
	if (
		selection_mode not in [SelectionMode.EQUIPMENT, SelectionMode.INVENTORY]
		or not _is_branch_loadout_edit_allowed()
		or not is_instance_valid(equipment_service)
	):
		return false
	var slot_id: StringName = selected_equipment_slot_id
	if selection_mode == SelectionMode.INVENTORY:
		var item: ItemInstance = inventory_service.get_item(
			selected_equipment_instance_id
		) if is_instance_valid(inventory_service) else null
		if item == null:
			return false
		var definition: ItemDefinition = GameContent.get_item(item.definition_id)
		if not is_instance_valid(definition):
			return false
		slot_id = definition.equipment_slot_id
	return equipment_service.unequip_slot(slot_id)


func _format_item_detail(
	heading: String,
	item: ItemInstance,
	empty_text: String
) -> String:
	var lines: Array[String] = [heading]
	if item == null:
		lines.append(empty_text)
		return "\n".join(lines)
	var definition: ItemDefinition = GameContent.get_item(item.definition_id)
	if not is_instance_valid(definition):
		lines.append("Unknown item")
		return "\n".join(lines)
	lines.append(definition.display_name)
	lines.append(ItemRarityRules.get_rarity_display_name(item.rarity_id))
	lines.append("ILvl %d%s%s" % [
		item.item_level,
		ITEM_METADATA_SEPARATOR,
		EquipmentSlotRules.get_slot_display_name(definition.equipment_slot_id)
	])
	if item.is_locked:
		lines.append("LOCKED")
	if (
		is_instance_valid(equipment_service)
		and equipment_service.is_item_equipped(item.instance_id)
	):
		lines.append("EQUIPPED")
	if item.affix_rolls.is_empty():
		lines.append("No affixes.")
	else:
		for affix in item.affix_rolls:
			if EquipmentStatRules.is_supported_stat_id(affix.stat_id):
				lines.append("%s: %s" % [
					EquipmentStatRules.get_stat_display_name(affix.stat_id),
					EquipmentStatRules.format_stat_value(
						affix.stat_id,
						affix.value
					)
				])
			else:
				lines.append("%s: +%s" % [
					_humanize_stat_id(affix.stat_id),
					_format_affix_value(affix.value)
				])
	return "\n".join(lines)


func _humanize_stat_id(stat_id: StringName) -> String:
	var words: PackedStringArray = String(stat_id).split("_", false)
	for word_index in range(words.size()):
		words[word_index] = words[word_index].capitalize()
	return " ".join(words)


func _format_affix_value(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return str(value)


func _refresh_selected_detail() -> void:
	var branch: CombatBranch = _get_runtime_branch_for_slot(selected_slot_id)
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
		upgrade_lines.append("%s - Lv.%d" % [branch.get_upgrade_display_name(upgrade_id), branch.get_upgrade_level(upgrade_id)])
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
		lines.append("%s\n%s" % [
			definition.display_name,
			BranchDefinition.get_legendary_tier_display_name_for_tier(
				seed_service.get_acquired_tier(branch_id)
			)
		])
	seed_list_label.text = "\n\n".join(lines)


func _refresh_loadout_controls() -> void:
	if selection_mode in [SelectionMode.EQUIPMENT, SelectionMode.INVENTORY]:
		return
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
	if (
		selection_mode != SelectionMode.BRANCH
		or not _is_branch_loadout_edit_allowed()
	):
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
		var seed_service := get_node_or_null("/root/BranchSeeds") as BranchSeedService
		var tier: int = (
			seed_service.get_acquired_tier(definition.branch_id)
			if is_instance_valid(seed_service)
			else 0
		)
		return "LEGENDARY - %s" % BranchDefinition.get_legendary_tier_display_name_for_tier(tier)
	return "STANDARD"


func _request_debug_progress_reset() -> void:
	if not OS.is_debug_build():
		return
	debug_reset_confirmation.popup_centered()


func _confirm_debug_progress_reset() -> void:
	if not OS.is_debug_build():
		return
	var save_game := get_node_or_null("/root/SaveGame") as SaveGameService
	if not is_instance_valid(save_game):
		push_warning("SaveGame is unavailable; progress reset was not performed.")
		return
	if not save_game.reset_all_player_progress_for_debug():
		push_warning("Debug player progress reset failed.")


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
	var selected_branch: CombatBranch = _get_runtime_branch_for_slot(selected_slot_id)
	if is_instance_valid(selected_branch) and selected_branch.branch_id == branch_id:
		_refresh_selected_detail()


func _on_level_changed(_level: int) -> void:
	_refresh_selected_detail()


func _get_runtime_branch_for_slot(slot_id: StringName) -> CombatBranch:
	var branch_value: Variant = branches_by_slot.get(slot_id)
	if not is_instance_valid(branch_value):
		branches_by_slot.erase(slot_id)
		return null
	return branch_value as CombatBranch


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
	if (
		is_instance_valid(seed_service)
		and not seed_service.branch_seed_tier_changed.is_connected(
			_on_branch_seed_tier_changed
		)
	):
		seed_service.branch_seed_tier_changed.connect(_on_branch_seed_tier_changed)


func _connect_equipment_services() -> void:
	inventory_service = get_node_or_null("/root/Inventory") as InventoryService
	equipment_service = get_node_or_null("/root/Equipment") as EquipmentService
	if (
		is_instance_valid(inventory_service)
		and not inventory_service.item_added.is_connected(_on_inventory_item_added)
	):
		inventory_service.item_added.connect(_on_inventory_item_added)
	if (
		is_instance_valid(inventory_service)
		and not inventory_service.item_removed.is_connected(_on_inventory_item_removed)
	):
		inventory_service.item_removed.connect(_on_inventory_item_removed)
	if (
		is_instance_valid(equipment_service)
		and not equipment_service.equipment_slot_changed.is_connected(
			_on_equipment_slot_changed
		)
	):
		equipment_service.equipment_slot_changed.connect(
			_on_equipment_slot_changed
		)


func _on_inventory_item_added(_instance_id: StringName) -> void:
	if visible and selection_mode in [SelectionMode.EQUIPMENT, SelectionMode.INVENTORY]:
		_refresh_equipment_ui()


func _on_inventory_item_removed(instance_id: StringName) -> void:
	if selected_equipment_instance_id == instance_id:
		selected_equipment_instance_id = &""
	if visible:
		_refresh_equipment_slot_buttons()
		if selection_mode in [SelectionMode.EQUIPMENT, SelectionMode.INVENTORY]:
			_refresh_equipment_ui()


func _on_equipment_slot_changed(
	_slot_id: StringName,
	_previous_instance_id: StringName,
	_new_instance_id: StringName
) -> void:
	if not visible:
		return
	if (
		selection_mode == SelectionMode.INVENTORY
		and selected_equipment_instance_id == _new_instance_id
	):
		selected_equipment_instance_id = &""
	_refresh_equipment_slot_buttons()
	if selection_mode in [SelectionMode.EQUIPMENT, SelectionMode.INVENTORY]:
		_refresh_equipment_ui()


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


func _on_branch_seed_tier_changed(_branch_id: StringName, _acquired_tier: int) -> void:
	if visible:
		refresh_screen()
