extends Panel


const BRANCH_SLOT_COUNT: int = 5
const CROWN_SLOT_ARRAY_INDEX: int = 4


@onready var branch_name_label: Label = (
	$VBoxContainer/BranchNameLabel
)

@onready var branch_stats_label: Label = (
	$VBoxContainer/BranchStatsLabel
)

@onready var branch_slot_buttons: Array[Button] = [
	$VBoxContainer/BranchSlotButtons/Slot1Button,
	$VBoxContainer/BranchSlotButtons/Slot2Button,
	$VBoxContainer/BranchSlotButtons/Slot3Button,
	$VBoxContainer/BranchSlotButtons/Slot4Button,
	$VBoxContainer/BranchSlotButtons/Slot5Button
]

@onready var damage_button: Button = (
	$VBoxContainer/DamageButton
)

@onready var attack_speed_button: Button = (
	$VBoxContainer/AttackSpeedButton
)

@onready var range_button: Button = (
	$VBoxContainer/RangeButton
)


var tree_node: Node

var branches_by_slot: Array[Node] = [
	null,
	null,
	null,
	null,
	null
]

var upgrade_buttons: Array[Button] = []

var selected_slot_array_index: int = -1
var selected_branch: Node


func _ready() -> void:
	tree_node = (
		get_tree().get_first_node_in_group("tree")
	)

	upgrade_buttons = [
		damage_button,
		attack_speed_button,
		range_button
	]

	connect_slot_buttons()
	connect_upgrade_buttons()
	connect_tree_signals()

	find_available_branches()
	select_first_available_branch()


func connect_slot_buttons() -> void:
	for slot_array_index in range(
		branch_slot_buttons.size()
	):
		var slot_button: Button = (
			branch_slot_buttons[
				slot_array_index
			]
		)

		slot_button.pressed.connect(
			_on_branch_slot_button_pressed.bind(
				slot_array_index
			)
		)


func connect_upgrade_buttons() -> void:
	for button_index in range(
		upgrade_buttons.size()
	):
		var upgrade_button: Button = (
			upgrade_buttons[button_index]
		)

		upgrade_button.pressed.connect(
			_on_upgrade_button_pressed.bind(
				button_index
			)
		)


func connect_tree_signals() -> void:
	if not is_instance_valid(tree_node):
		return

	if tree_node.has_signal(
		"forest_essence_changed"
	):
		tree_node.forest_essence_changed.connect(
			_on_forest_essence_changed
		)


func find_available_branches() -> void:
	branches_by_slot = [
		null,
		null,
		null,
		null,
		null
	]

	var found_branches: Array[Node] = (
		get_tree().get_nodes_in_group(
			"combat_branch"
		)
	)

	for branch in found_branches:
		if not is_instance_valid(branch):
			continue

		var physical_slot_index: int = (
			get_branch_slot_index(branch)
		)

		var slot_array_index: int = (
			physical_slot_index - 1
		)

		if (
			slot_array_index < 0
			or slot_array_index
			>= BRANCH_SLOT_COUNT
		):
			push_warning(
				"%s has invalid slot_index %d. "
				+ "Valid values are 1–5."
				% [
					branch.name,
					physical_slot_index
				]
			)

			continue

		if is_instance_valid(
			branches_by_slot[
				slot_array_index
			]
		):
			push_warning(
				"Multiple branches use slot %d: "
				+ "%s and %s."
				% [
					physical_slot_index,
					branches_by_slot[
						slot_array_index
					].name,
					branch.name
				]
			)

			continue

		branches_by_slot[
			slot_array_index
		] = branch


func get_branch_slot_index(
	branch: Node
) -> int:
	if not is_instance_valid(branch):
		return -1

	var branch_slot_value = branch.get(
		"slot_index"
	)

	if branch_slot_value == null:
		return -1

	return int(branch_slot_value)


func select_first_available_branch() -> void:
	for slot_array_index in range(
		branches_by_slot.size()
	):
		var branch: Node = (
			branches_by_slot[
				slot_array_index
			]
		)

		if is_instance_valid(branch):
			select_branch(slot_array_index)
			return

	selected_branch = null
	selected_slot_array_index = -1

	update_panel()


func select_branch(
	slot_array_index: int
) -> void:
	if (
		slot_array_index < 0
		or slot_array_index
		>= branches_by_slot.size()
	):
		return

	var branch: Node = (
		branches_by_slot[
			slot_array_index
		]
	)

	if not is_instance_valid(branch):
		return

	selected_slot_array_index = (
		slot_array_index
	)

	selected_branch = branch

	connect_selected_branch_signals()
	update_panel()


func connect_selected_branch_signals() -> void:
	if not is_instance_valid(selected_branch):
		return

	connect_signal_if_needed(
		selected_branch,
		"level_changed",
		"_on_branch_level_changed"
	)

	connect_signal_if_needed(
		selected_branch,
		"xp_changed",
		"_on_branch_xp_changed"
	)

	connect_signal_if_needed(
		selected_branch,
		"upgrade_changed",
		"_on_branch_upgrade_changed"
	)


func connect_signal_if_needed(
	source_node: Node,
	signal_name: StringName,
	method_name: StringName
) -> void:
	if not source_node.has_signal(
		signal_name
	):
		return

	var signal_object: Signal = (
		source_node.get(signal_name)
	)

	var callback := Callable(
		self,
		method_name
	)

	if signal_object.is_connected(
		callback
	):
		return

	signal_object.connect(callback)


func update_panel() -> void:
	update_branch_slot_buttons()

	if not is_instance_valid(
		selected_branch
	):
		branch_name_label.text = "NO BRANCH"
		branch_stats_label.text = ""

		for button in upgrade_buttons:
			button.visible = false
			button.disabled = true

		return

	update_branch_name()
	update_branch_statistics()

	for button in upgrade_buttons:
		button.visible = true

	update_upgrade_buttons()


func update_branch_slot_buttons() -> void:
	for slot_array_index in range(
		branch_slot_buttons.size()
	):
		var slot_button: Button = (
			branch_slot_buttons[
				slot_array_index
			]
		)

		var branch: Node = (
			branches_by_slot[
				slot_array_index
			]
		)

		if not is_instance_valid(branch):
			if (
				slot_array_index
				== CROWN_SLOT_ARRAY_INDEX
			):
				slot_button.text = "CROWN"
			else:
				slot_button.text = "EMPTY"

			slot_button.disabled = true
			continue

		slot_button.text = (
			get_short_branch_name(branch)
		)

		slot_button.disabled = (
			slot_array_index
			== selected_slot_array_index
		)


func get_short_branch_name(
	branch: Node
) -> String:
	var branch_name: String = "BRANCH"

	if branch.has_method(
		"get_branch_display_name"
	):
		branch_name = str(
			branch.get_branch_display_name()
		)

	branch_name = branch_name.replace(
		" Branch",
		""
	)

	return branch_name.to_upper()


func update_branch_name() -> void:
	var branch_name: String = (
		"Combat Branch"
	)

	var side_name: String = ""

	if selected_branch.has_method(
		"get_branch_display_name"
	):
		branch_name = str(
			selected_branch
			.get_branch_display_name()
		)

	if selected_branch.has_method(
		"get_branch_side_name"
	):
		side_name = str(
			selected_branch
			.get_branch_side_name()
		)

	if side_name.is_empty():
		branch_name_label.text = (
			branch_name.to_upper()
		)
	else:
		branch_name_label.text = (
			"%s %s"
			% [
				side_name.to_upper(),
				branch_name.to_upper()
			]
		)


func update_branch_statistics() -> void:
	var lines: Array[String] = []

	lines.append(
		"Forest Essence: %d"
		% get_current_essence()
	)

	if selected_branch.has_method(
		"get_progress_summary_lines"
	):
		var progress_lines: Array = (
			selected_branch
			.get_progress_summary_lines()
		)

		for progress_line in progress_lines:
			lines.append(
				str(progress_line)
			)

	if selected_branch.has_method(
		"get_stat_summary_lines"
	):
		var stat_lines: Array = (
			selected_branch
			.get_stat_summary_lines()
		)

		for stat_line in stat_lines:
			lines.append(
				str(stat_line)
			)

	branch_stats_label.text = (
		"\n".join(lines)
	)


func update_upgrade_buttons() -> void:
	var essence_amount: int = (
		get_current_essence()
	)

	var upgrade_ids: Array = []

	if selected_branch.has_method(
		"get_upgrade_ids"
	):
		upgrade_ids = (
			selected_branch.get_upgrade_ids()
		)

	for button_index in range(
		upgrade_buttons.size()
	):
		var button: Button = (
			upgrade_buttons[button_index]
		)

		if button_index >= upgrade_ids.size():
			button.visible = false
			button.disabled = true
			continue

		button.visible = true

		var upgrade_id: StringName = (
			upgrade_ids[button_index]
		)

		update_upgrade_button(
			button,
			upgrade_id,
			essence_amount
		)


func update_upgrade_button(
	button: Button,
	upgrade_id: StringName,
	essence_amount: int
) -> void:
	var display_name: String = str(
		selected_branch
		.get_upgrade_display_name(
			upgrade_id
		)
	)

	var current_level: int = int(
		selected_branch.get_upgrade_level(
			upgrade_id
		)
	)

	var maximum_level: int = int(
		selected_branch
		.get_upgrade_maximum_level(
			upgrade_id
		)
	)

	if current_level >= maximum_level:
		button.text = (
			"%s Lv.%d — MAX"
			% [
				display_name.to_upper(),
				current_level
			]
		)

		button.disabled = true
		return

	var cost: int = int(
		selected_branch
		.get_upgrade_cost_by_id(
			upgrade_id
		)
	)

	var current_value: String = str(
		selected_branch
		.get_upgrade_current_value_text(
			upgrade_id
		)
	)

	var next_value: String = str(
		selected_branch
		.get_upgrade_next_value_text(
			upgrade_id
		)
	)

	button.text = (
		"%s Lv.%d | %s → %s | %d Essence"
		% [
			display_name.to_upper(),
			current_level,
			current_value,
			next_value,
			cost
		]
	)

	button.disabled = (
		essence_amount < cost
	)


func get_current_essence() -> int:
	if not is_instance_valid(tree_node):
		return 0

	if tree_node.has_method(
		"get_forest_essence"
	):
		return int(
			tree_node.get_forest_essence()
		)

	return 0


func _on_branch_slot_button_pressed(
	slot_array_index: int
) -> void:
	select_branch(slot_array_index)


func _on_upgrade_button_pressed(
	button_index: int
) -> void:
	if not is_instance_valid(
		selected_branch
	):
		return

	if not selected_branch.has_method(
		"get_upgrade_ids"
	):
		return

	var upgrade_ids: Array = (
		selected_branch.get_upgrade_ids()
	)

	if (
		button_index < 0
		or button_index >= upgrade_ids.size()
	):
		return

	var upgrade_id: StringName = (
		upgrade_ids[button_index]
	)

	if selected_branch.has_method(
		"purchase_upgrade"
	):
		selected_branch.purchase_upgrade(
			upgrade_id
		)

	update_panel()


func _on_forest_essence_changed(
	_new_amount: int
) -> void:
	update_panel()


func _on_branch_level_changed(
	_new_level: int
) -> void:
	update_panel()


func _on_branch_xp_changed(
	_current_xp: int,
	_xp_required: int
) -> void:
	update_panel()


func _on_branch_upgrade_changed(
	_upgrade_id: StringName,
	_new_level: int
) -> void:
	update_panel()
