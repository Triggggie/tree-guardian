extends Panel


@onready var branch_name_label: Label = (
	$VBoxContainer/BranchNameLabel
)

@onready var branch_stats_label: Label = (
	$VBoxContainer/BranchStatsLabel
)

@onready var branch_select_button: Button = (
	$VBoxContainer/BranchSelectButton
)

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
var available_branches: Array[Node] = []
var upgrade_buttons: Array[Button] = []

var selected_branch_index: int = 0
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

	branch_select_button.pressed.connect(
		_on_branch_select_button_pressed
	)

	for button_index in range(
		upgrade_buttons.size()
	):
		upgrade_buttons[
			button_index
		].pressed.connect(
			_on_upgrade_button_pressed.bind(
				button_index
			)
		)

	if (
		is_instance_valid(tree_node)
		and tree_node.has_signal(
			"forest_essence_changed"
		)
	):
		tree_node.forest_essence_changed.connect(
			_on_forest_essence_changed
		)

	find_available_branches()
	select_branch(0)


func find_available_branches() -> void:
	available_branches.clear()

	var found_branches: Array[Node] = (
		get_tree().get_nodes_in_group(
			"combat_branch"
		)
	)

	for branch in found_branches:
		if not is_instance_valid(branch):
			continue

		available_branches.append(branch)

	available_branches.sort_custom(
		func(
			first_branch: Node,
			second_branch: Node
		) -> bool:
			if (
				first_branch is Node2D
				and second_branch is Node2D
			):
				return (
					first_branch.global_position.x
					< second_branch.global_position.x
				)

			return false
	)


func select_branch(branch_index: int) -> void:
	if available_branches.is_empty():
		selected_branch = null
		update_panel()
		return

	selected_branch_index = wrapi(
		branch_index,
		0,
		available_branches.size()
	)

	selected_branch = available_branches[
		selected_branch_index
	]

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

	connect_signal_if_needed(
		selected_branch,
		"talent_points_changed",
		"_on_talent_points_changed"
	)


func connect_signal_if_needed(
	source_node: Node,
	signal_name: StringName,
	method_name: StringName
) -> void:
	if not source_node.has_signal(signal_name):
		return

	var signal_object: Signal = (
		source_node.get(signal_name)
	)

	var callback := Callable(
		self,
		method_name
	)

	if signal_object.is_connected(callback):
		return

	signal_object.connect(callback)


func update_panel() -> void:
	if not is_instance_valid(selected_branch):
		branch_name_label.text = "NO BRANCH"
		branch_stats_label.text = ""

		branch_select_button.disabled = true

		for button in upgrade_buttons:
			button.visible = false
			button.disabled = true

		return

	branch_select_button.disabled = (
		available_branches.size() <= 1
	)

	branch_select_button.text = (
		"SELECT NEXT BRANCH"
	)

	update_branch_name()
	update_branch_statistics()
	update_upgrade_buttons()


func update_branch_name() -> void:
	var branch_name: String = "Combat Branch"
	var side_name: String = ""

	if selected_branch.has_method(
		"get_branch_display_name"
	):
		branch_name = (
			selected_branch.get_branch_display_name()
		)

	if selected_branch.has_method(
		"get_branch_side_name"
	):
		side_name = (
			selected_branch.get_branch_side_name()
		)

	branch_name_label.text = (
		"%s %s" % [
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
	var display_name: String = (
		selected_branch
		.get_upgrade_display_name(
			upgrade_id
		)
	)

	var current_level: int = (
		selected_branch.get_upgrade_level(
			upgrade_id
		)
	)

	var maximum_level: int = (
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

	var cost: int = (
		selected_branch.get_upgrade_cost_by_id(
			upgrade_id
		)
	)

	var current_value: String = (
		selected_branch
		.get_upgrade_current_value_text(
			upgrade_id
		)
	)

	var next_value: String = (
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
		return tree_node.get_forest_essence()

	return 0


func _on_branch_select_button_pressed() -> void:
	select_branch(
		selected_branch_index + 1
	)


func _on_upgrade_button_pressed(
	button_index: int
) -> void:
	if not is_instance_valid(selected_branch):
		return

	if not selected_branch.has_method(
		"get_upgrade_ids"
	):
		return

	var upgrade_ids: Array = (
		selected_branch.get_upgrade_ids()
	)

	if button_index >= upgrade_ids.size():
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


func _on_talent_points_changed(
	_available_points: int,
	_total_points_earned: int
) -> void:
	update_panel()
