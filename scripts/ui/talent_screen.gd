extends Control


const TALENT_NODE_BUTTON_SCENE: PackedScene = preload(
	"res://scenes/ui/TalentNodeButton.tscn"
)


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
	/TalentTreePanel/TalentTreeArea
	/TalentTreeLabel
)

@onready var talent_nodes: Control = (
	$MarginContainer/MainPanel/MainVBox/ContentHBox
	/TalentTreePanel/TalentTreeArea
	/TalentNodes
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


func _ready() -> void:
	close_button.pressed.connect(
		close_screen
	)

	purchase_talent_button.pressed.connect(
		purchase_selected_talent
	)

	old_strength_branch_button.visible = false
	old_blossom_branch_button.visible = false

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
		"SLOT %d — %s"
		% [
			get_branch_slot_index(branch),
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
		"SLOT %d — %s  |  Talent Points: %d"
		% [
			get_branch_slot_index(
				selected_branch
			),
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
		"SLOT %d — %s TALENT TREE"
		% [
			get_branch_slot_index(
				selected_branch
			),
			get_branch_short_name(
				selected_branch
			)
		]
	)

	for talent_index in range(
		talent_ids.size()
	):
		var talent_id: StringName = (
			talent_ids[talent_index]
		)

		create_talent_node(
			talent_id,
			talent_index,
			talent_ids.size()
		)


func clear_talent_nodes() -> void:
	for child in talent_nodes.get_children():
		child.queue_free()


func create_talent_node(
	talent_id: StringName,
	talent_index: int,
	talent_count: int
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

	var available_width: float = (
		talent_nodes.size.x
	)

	if available_width <= 0.0:
		available_width = 900.0

	var horizontal_spacing: float = (
		available_width
		/ float(talent_count + 1)
	)

	var button_size: Vector2 = Vector2(
		170.0,
		80.0
	)

	var button_center_x: float = (
		horizontal_spacing
		* float(talent_index + 1)
	)

	talent_button.position = Vector2(
		button_center_x
		- button_size.x * 0.5,
		140.0
	)

	talent_button.size = button_size

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
	find_available_branches()
	connect_branch_signals()

	if (
		not is_instance_valid(selected_branch)
		or not available_branches.has(
			selected_branch
		)
	):
		if not available_branches.is_empty():
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
