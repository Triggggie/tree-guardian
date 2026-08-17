extends Control


const TALENT_NODE_BUTTON_SCENE: PackedScene = preload(
	"res://scenes/ui/TalentNodeButton.tscn"
)

const NODE_SIZE := Vector2(170.0, 90.0)
const COLUMN_SPACING: float = 190.0
const ROW_SPACING: float = 135.0
const GRAPH_MARGIN := Vector2(40.0, 35.0)


@onready var talent_points_label: Label = (
	$MarginContainer/MainPanel/MainVBox/TopBar
	/TalentPointsLabel
)

@onready var close_button: Button = (
	$MarginContainer/MainPanel/MainVBox/TopBar
	/CloseButton
)

@onready var branch_buttons_container: VBoxContainer = (
	$MarginContainer/MainPanel/MainVBox/ContentHBox
	/BranchSelectorPanel/BranchSelectorVBox
	/BranchButtonsContainer
)

@onready var old_strength_branch_button: Button = (
	$MarginContainer/MainPanel/MainVBox/ContentHBox
	/BranchSelectorPanel/BranchSelectorVBox
	/StrengthBranchButton
)

@onready var old_blossom_branch_button: Button = (
	$MarginContainer/MainPanel/MainVBox/ContentHBox
	/BranchSelectorPanel/BranchSelectorVBox
	/BlossomBranchButton
)

@onready var talent_tree_label: Label = (
	$MarginContainer/MainPanel/MainVBox/ContentHBox
	/TalentTreePanel/TalentTreeVBox
	/TalentTreeLabel
)

@onready var talent_graph: TalentGraphCanvas = (
	$MarginContainer/MainPanel/MainVBox/ContentHBox
	/TalentTreePanel/TalentTreeVBox/TalentTreeScroll
	/TalentGraph
)

@onready var talent_nodes: Control = (
	$MarginContainer/MainPanel/MainVBox/ContentHBox
	/TalentTreePanel/TalentTreeVBox/TalentTreeScroll
	/TalentGraph/TalentNodes
)

@onready var selected_talent_name_label: Label = (
	$MarginContainer/MainPanel/MainVBox/ContentHBox
	/TalentDetailPanel/TalentDetailVBox
	/SelectedTalentNameLabel
)

@onready var selected_talent_branch_label: Label = (
	$MarginContainer/MainPanel/MainVBox/ContentHBox
	/TalentDetailPanel/TalentDetailVBox
	/SelectedTalentBranchLabel
)

@onready var talent_description_label: Label = (
	$MarginContainer/MainPanel/MainVBox/ContentHBox
	/TalentDetailPanel/TalentDetailVBox
	/TalentDescriptionLabel
)

@onready var talent_requirements_label: Label = (
	$MarginContainer/MainPanel/MainVBox/ContentHBox
	/TalentDetailPanel/TalentDetailVBox
	/TalentRequirementsLabel
)

@onready var purchase_talent_button: Button = (
	$MarginContainer/MainPanel/MainVBox/ContentHBox
	/TalentDetailPanel/TalentDetailVBox
	/PurchaseTalentButton
)


var available_branches: Array[Node] = []
var branch_buttons_by_instance_id: Dictionary = {}

var selected_branch
var selected_talent_id: StringName = &""
var talent_positions_by_id: Dictionary = {}


func _ready() -> void:
	close_button.pressed.connect(
		close_screen
	)

	purchase_talent_button.pressed.connect(
		purchase_selected_talent
	)

	old_strength_branch_button.visible = false
	old_blossom_branch_button.visible = false
	_connect_loadout_controller()

	find_available_branches()
	connect_branch_signals()

	if not available_branches.is_empty():
		select_branch(
			available_branches[0]
		)
	else:
		update_empty_state()

	hide()


func find_available_branches() -> void:
	available_branches.clear()

	for branch_node in get_tree().get_nodes_in_group(
		"combat_branch"
	):
		if not is_instance_valid(branch_node):
			continue

		if not branch_node.has_method(
			"get_branch_display_name"
		):
			continue

		if not branch_node.has_method(
			"get_talent_ids"
		):
			continue

		var slot_index: int = (
			get_branch_slot_index(branch_node)
		)

		if slot_index < 1:
			push_warning(
				"%s has invalid slot_index %d."
				% [
					branch_node.name,
					slot_index
				]
			)
			continue

		available_branches.append(
			branch_node
		)

	available_branches.sort_custom(
		sort_branches_by_slot
	)

	rebuild_branch_buttons()


func sort_branches_by_slot(
	first_branch: Node,
	second_branch: Node
) -> bool:
	return (
		get_branch_slot_index(first_branch)
		< get_branch_slot_index(second_branch)
	)


func get_branch_slot_index(
	branch: Node
) -> int:
	if not is_instance_valid(branch):
		return -1

	var slot_value = branch.get(
		"slot_index"
	)

	if slot_value == null:
		return -1

	return int(slot_value)


func rebuild_branch_buttons() -> void:
	for child in branch_buttons_container.get_children():
		child.free()

	branch_buttons_by_instance_id.clear()

	for branch in available_branches:
		create_branch_button(branch)

	update_selected_branch_buttons()


func create_branch_button(
	branch: Node
) -> void:
	if not is_instance_valid(branch):
		return

	var branch_button := Button.new()

	branch_button.custom_minimum_size = Vector2(
		0.0,
		60.0
	)

	branch_button.text = (
		"%s — %s"
		% [
			_get_branch_slot_label(branch),
			get_branch_short_name(branch)
		]
	)

	branch_button.pressed.connect(
		select_branch.bind(branch)
	)

	branch_buttons_container.add_child(
		branch_button
	)

	branch_buttons_by_instance_id[
		branch.get_instance_id()
	] = branch_button


func get_branch_short_name(
	branch: Node
) -> String:
	if not is_instance_valid(branch):
		return "UNKNOWN"

	var display_name: String = (
		branch.get_branch_display_name()
	)

	return (
		display_name
		.replace(" Branch", "")
		.to_upper()
	)


func connect_branch_signals() -> void:
	for branch in available_branches:
		connect_single_branch_signals(branch)


func connect_single_branch_signals(
	branch
) -> void:
	if not is_instance_valid(branch):
		return

	if not branch.talent_points_changed.is_connected(
		_on_branch_talent_points_changed
	):
		branch.talent_points_changed.connect(
			_on_branch_talent_points_changed
		)

	if not branch.talent_changed.is_connected(
		_on_branch_talent_changed
	):
		branch.talent_changed.connect(
			_on_branch_talent_changed
		)


func select_branch(
	branch
) -> void:
	if not is_instance_valid(branch):
		return

	if not available_branches.has(branch):
		return

	selected_branch = branch

	update_selected_branch_buttons()
	update_talent_points_label()
	reset_talent_details()
	rebuild_talent_tree()


func update_selected_branch_buttons() -> void:
	for branch in available_branches:
		if not is_instance_valid(branch):
			continue

		var branch_instance_id: int = (
			branch.get_instance_id()
		)

		if not branch_buttons_by_instance_id.has(
			branch_instance_id
		):
			continue

		var branch_button: Button = (
			branch_buttons_by_instance_id[
				branch_instance_id
			]
		)

		if not is_instance_valid(branch_button):
			continue

		branch_button.disabled = (
			branch == selected_branch
		)


func update_talent_points_label() -> void:
	if not is_instance_valid(selected_branch):
		talent_points_label.text = (
			"Talent Points: 0"
		)
		return

	talent_points_label.text = (
		"%s — %s  |  Talent Points: %d"
		% [
			_get_branch_slot_label(selected_branch),
			get_branch_short_name(
				selected_branch
			),
			selected_branch
				.get_available_talent_points()
		]
	)


func rebuild_talent_tree() -> void:
	clear_talent_nodes()

	if not is_instance_valid(selected_branch):
		talent_tree_label.text = (
			"NO BRANCH SELECTED"
		)
		return

	var talent_ids: Array[StringName] = (
		selected_branch.get_talent_ids()
	)

	if talent_ids.is_empty():
		talent_tree_label.text = (
			"NO TALENTS AVAILABLE IN THIS PROTOTYPE"
		)
		return

	talent_tree_label.text = (
		"%s — %s TALENT TREE"
		% [
			_get_branch_slot_label(selected_branch),
			get_branch_short_name(
				selected_branch
			)
		]
	)

	var graph_layout: Dictionary = _build_graph_layout(talent_ids)
	talent_positions_by_id = graph_layout.get("positions", {})
	talent_graph.custom_minimum_size = graph_layout.get(
		"size",
		Vector2(1000.0, 700.0)
	)
	for talent_id in talent_ids:
		create_talent_node(
			talent_id,
			talent_positions_by_id.get(talent_id, GRAPH_MARGIN)
		)
	_rebuild_prerequisite_connections(talent_ids)


func clear_talent_nodes() -> void:
	talent_positions_by_id.clear()
	if is_instance_valid(talent_graph):
		talent_graph.clear_prerequisite_connections()
	for child in talent_nodes.get_children():
		child.queue_free()


func create_talent_node(
	talent_id: StringName,
	node_position: Vector2
) -> void:
	var talent_button: Button = (
		TALENT_NODE_BUTTON_SCENE.instantiate()
		as Button
	)

	if not is_instance_valid(talent_button):
		push_warning(
			"TalentNodeButton scene root must be a Button."
		)
		return

	talent_nodes.add_child(
		talent_button
	)

	talent_button.pressed.connect(
		select_talent.bind(talent_id)
	)

	if talent_button.has_method("setup"):
		talent_button.call(
			"setup",
			talent_id,
			selected_branch.get_talent_display_name(
				talent_id
			)
		)
	else:
		talent_button.text = (
			selected_branch.get_talent_display_name(
				talent_id
			)
		)

	talent_button.position = node_position
	talent_button.size = NODE_SIZE

	update_talent_node_state(
		talent_button,
		talent_id
	)


func update_talent_node_state(
	talent_button: Button,
	talent_id: StringName
) -> void:
	if not is_instance_valid(selected_branch):
		talent_button.disabled = true
		return

	var talent_name: String = (
		selected_branch.get_talent_display_name(
			talent_id
		)
	)

	var talent_path_name: String = (
		selected_branch.get_talent_branch_name(
			talent_id
		)
	)

	var status_text: String = (
		selected_branch.get_talent_status_text(
			talent_id
		)
	)

	talent_button.text = (
		"%s\n%s\n%s"
		% [
			talent_path_name,
			talent_name,
			status_text
		]
	)

	talent_button.disabled = false
	if status_text == "PURCHASED":
		talent_button.modulate = Color(0.62, 1.0, 0.68, 1.0)
	elif selected_branch.can_purchase_talent(talent_id):
		talent_button.modulate = Color(1.0, 0.88, 0.48, 1.0)
	elif status_text.begins_with("CONFLICT"):
		talent_button.modulate = Color(0.72, 0.48, 0.48, 1.0)
	else:
		talent_button.modulate = Color(0.62, 0.64, 0.62, 1.0)


func _build_graph_layout(talent_ids: Array[StringName]) -> Dictionary:
	var positions: Dictionary = {}
	var fallback_index_by_row: Dictionary = {}
	var maximum_column: int = 0
	var maximum_row: int = 0
	for talent_id in talent_ids:
		var definition: TalentDefinition = selected_branch.get_talent_definition(talent_id)
		if not is_instance_valid(definition):
			continue
		var row: int = definition.tree_row
		if row < 0:
			row = _get_fallback_row(definition.required_branch_level)
		var column: int = definition.tree_column
		if column < 0:
			column = int(fallback_index_by_row.get(row, 0))
			fallback_index_by_row[row] = column + 1
		maximum_column = max(maximum_column, column)
		maximum_row = max(maximum_row, row)
		positions[talent_id] = GRAPH_MARGIN + Vector2(
			float(column) * COLUMN_SPACING,
			float(row) * ROW_SPACING
		)
	return {
		"positions": positions,
		"size": Vector2(
			max(1000.0, GRAPH_MARGIN.x * 2.0 + float(maximum_column) * COLUMN_SPACING + NODE_SIZE.x),
			max(700.0, GRAPH_MARGIN.y * 2.0 + float(maximum_row) * ROW_SPACING + NODE_SIZE.y)
		)
	}


func _get_fallback_row(required_level: int) -> int:
	var milestone_levels: Array[int] = [2, 4, 7, 10, 14]
	for index in range(milestone_levels.size()):
		if required_level <= milestone_levels[index]:
			return index
	return milestone_levels.size()


func _rebuild_prerequisite_connections(talent_ids: Array[StringName]) -> void:
	var connections: Array[Dictionary] = []
	for talent_id in talent_ids:
		var definition: TalentDefinition = selected_branch.get_talent_definition(talent_id)
		if not is_instance_valid(definition):
			continue
		var child_position: Vector2 = talent_positions_by_id.get(talent_id, Vector2.ZERO)
		for prerequisite_id in definition.prerequisite_ids:
			if not talent_positions_by_id.has(prerequisite_id):
				continue
			var parent_position: Vector2 = talent_positions_by_id[prerequisite_id]
			connections.append({
				"start": parent_position + Vector2(NODE_SIZE.x * 0.5, NODE_SIZE.y),
				"finish": child_position + Vector2(NODE_SIZE.x * 0.5, 0.0),
				"active": selected_branch.has_talent(prerequisite_id)
			})
	talent_graph.set_prerequisite_connections(connections)


func select_talent(
	talent_id: StringName
) -> void:
	if not is_instance_valid(selected_branch):
		return

	selected_talent_id = talent_id

	selected_talent_name_label.text = (
		selected_branch.get_talent_display_name(
			talent_id
		)
	)

	selected_talent_branch_label.text = (
		selected_branch.get_talent_branch_name(
			talent_id
		)
	)

	var description: String = (
		selected_branch.get_talent_description(
			talent_id
		)
	)

	if description.is_empty():
		description = (
			"No description is available for this talent."
		)

	talent_description_label.text = description

	talent_requirements_label.text = (
		selected_branch.get_talent_status_text(
			talent_id
		)
	)

	update_purchase_button()


func update_purchase_button() -> void:
	if not is_instance_valid(selected_branch):
		purchase_talent_button.text = (
			"SELECT A TALENT"
		)
		purchase_talent_button.disabled = true
		return

	if selected_talent_id == &"":
		purchase_talent_button.text = (
			"SELECT A TALENT"
		)
		purchase_talent_button.disabled = true
		return

	if selected_branch.has_talent(
		selected_talent_id
	):
		purchase_talent_button.text = "PURCHASED"
		purchase_talent_button.disabled = true
		return

	if selected_branch.can_purchase_talent(
		selected_talent_id
	):
		var talent_cost: int = (
			selected_branch.get_talent_cost(
				selected_talent_id
			)
		)

		purchase_talent_button.text = (
			"PURCHASE TALENT — %d TP"
			% talent_cost
		)

		purchase_talent_button.disabled = false
		return

	purchase_talent_button.text = (
		selected_branch.get_talent_status_text(
			selected_talent_id
		)
	)

	purchase_talent_button.disabled = true


func purchase_selected_talent() -> void:
	if not is_instance_valid(selected_branch):
		return

	if selected_talent_id == &"":
		return

	selected_branch.purchase_talent(
		selected_talent_id
	)


func reset_talent_details() -> void:
	selected_talent_id = &""

	selected_talent_name_label.text = (
		"SELECT A TALENT"
	)

	selected_talent_branch_label.text = ""

	talent_description_label.text = (
		"Select a talent node to view its description."
	)

	talent_requirements_label.text = ""

	purchase_talent_button.text = (
		"SELECT A TALENT"
	)

	purchase_talent_button.disabled = true


func update_empty_state() -> void:
	selected_branch = null

	talent_points_label.text = (
		"No equipped branches"
	)

	clear_talent_nodes()
	reset_talent_details()
	update_selected_branch_buttons()

	talent_tree_label.text = (
		"NO BRANCH SELECTED"
	)


func _on_branch_talent_points_changed(
	_available_points: int,
	_total_points_earned: int
) -> void:
	update_talent_points_label()
	rebuild_talent_tree()
	update_purchase_button()


func _on_branch_talent_changed(
	talent_id: StringName,
	_is_purchased: bool
) -> void:
	update_talent_points_label()
	rebuild_talent_tree()

	if selected_talent_id == talent_id:
		select_talent(talent_id)


func open_screen() -> void:
	var previous_slot_id: StringName = &""
	if is_instance_valid(selected_branch) and selected_branch.has_method("get_slot_id"):
		previous_slot_id = selected_branch.get_slot_id()
	find_available_branches()
	connect_branch_signals()
	var branch_in_previous_slot = _find_branch_by_slot_id(previous_slot_id)

	if (
		not is_instance_valid(selected_branch)
		or not available_branches.has(
			selected_branch
		)
	):
		if is_instance_valid(branch_in_previous_slot):
			select_branch(branch_in_previous_slot)
		elif not available_branches.is_empty():
			select_branch(
				available_branches[0]
			)
		else:
			update_empty_state()
	else:
		update_selected_branch_buttons()
		update_talent_points_label()
		reset_talent_details()
		rebuild_talent_tree()

	show()


func close_screen() -> void:
	hide()


func _find_branch_by_slot_id(slot_id: StringName):
	if slot_id == &"":
		return null
	for branch in available_branches:
		if branch.has_method("get_slot_id") and branch.get_slot_id() == slot_id:
			return branch
	return null


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
	_slot_id: StringName,
	_branch_id: StringName
) -> void:
	if visible:
		open_screen()


func _on_runtime_apex_slot_changed(
	_branch_id: StringName
) -> void:
	if visible:
		open_screen()


func _get_branch_slot_label(branch: Node) -> String:
	var slot_index: int = get_branch_slot_index(branch)
	if BranchSlotRules.is_apex_slot(slot_index):
		return "APEX"
	return "SLOT %d" % slot_index
