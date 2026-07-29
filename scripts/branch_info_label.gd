extends Label


var combat_branches: Array[Node] = []


func _ready() -> void:
	find_combat_branches()
	connect_branch_signals()
	update_label()


func find_combat_branches() -> void:
	combat_branches.clear()

	var found_branches: Array[Node] = (
		get_tree().get_nodes_in_group(
			"combat_branch"
		)
	)

	for branch in found_branches:
		if not is_instance_valid(branch):
			continue

		combat_branches.append(branch)

	combat_branches.sort_custom(
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


func connect_branch_signals() -> void:
	for branch in combat_branches:
		if not is_instance_valid(branch):
			continue

		if branch.has_signal("level_changed"):
			branch.level_changed.connect(
				_on_branch_level_changed
			)

		if branch.has_signal("xp_changed"):
			branch.xp_changed.connect(
				_on_branch_xp_changed
			)

		if branch.has_signal("upgrade_changed"):
			branch.upgrade_changed.connect(
				_on_branch_upgrade_changed
			)

		if branch.has_signal(
			"talent_points_changed"
		):
			branch.talent_points_changed.connect(
				_on_talent_points_changed
			)


func update_label() -> void:
	if combat_branches.is_empty():
		text = "Combat Branch nenalezena"
		return

	var branch_sections: Array[String] = []

	for branch in combat_branches:
		if not is_instance_valid(branch):
			continue

		var branch_name: String = "Combat Branch"
		var side_name: String = ""

		if branch.has_method(
			"get_branch_display_name"
		):
			branch_name = (
				branch.get_branch_display_name()
			)

		if branch.has_method(
			"get_branch_side_name"
		):
			side_name = (
				branch.get_branch_side_name()
			)

		var lines: Array[String] = []

		lines.append(
			"%s %s" % [
				side_name,
				branch_name
			]
		)

		if branch.has_method(
			"get_progress_summary_lines"
		):
			var progress_lines: Array = (
				branch.get_progress_summary_lines()
			)

			for progress_line in progress_lines:
				lines.append(
					str(progress_line)
				)

		if branch.has_method(
			"get_stat_summary_lines"
		):
			var stat_lines: Array = (
				branch.get_stat_summary_lines()
			)

			for stat_line in stat_lines:
				lines.append(
					str(stat_line)
				)

		branch_sections.append(
			"\n".join(lines)
		)

	text = "\n\n".join(branch_sections)


func _on_branch_level_changed(
	_new_level: int
) -> void:
	update_label()


func _on_branch_xp_changed(
	_current_xp: int,
	_xp_required: int
) -> void:
	update_label()


func _on_branch_upgrade_changed(
	_upgrade_id: StringName,
	_new_level: int
) -> void:
	update_label()


func _on_talent_points_changed(
	_available_points: int,
	_total_points_earned: int
) -> void:
	update_label()
