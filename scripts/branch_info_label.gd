extends Label


var strength_branches: Array[Node] = []


func _ready() -> void:
	strength_branches = get_tree().get_nodes_in_group(
		"strength_branch"
	)

	if strength_branches.is_empty():
		text = "Strength Branch nenalezena"
		return

	for branch in strength_branches:
		if branch.has_signal("level_changed"):
			branch.level_changed.connect(
				_on_branch_level_changed
			)

		if branch.has_signal("upgrade_changed"):
			branch.upgrade_changed.connect(
				_on_branch_upgrade_changed
			)

		if branch.has_signal("talent_points_changed"):
			branch.talent_points_changed.connect(
				_on_talent_points_changed
			)

	update_label()


func _process(_delta: float) -> void:
	update_label()


func _on_branch_level_changed(
	_new_level: int
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


func update_label() -> void:
	if strength_branches.is_empty():
		text = "Strength Branch nenalezena"
		return

	var lines: Array[String] = []

	for branch in strength_branches:
		if not is_instance_valid(branch):
			continue

		var side_name: String = (
			get_branch_side_name(branch)
		)

		var cooldown: float = (
			branch.get_current_attack_cooldown()
		)

		var attack_speed: float = 0.0

		if cooldown > 0.0:
			attack_speed = 1.0 / cooldown

		var talent_points: int = 0

		if branch.has_method(
			"get_available_talent_points"
		):
			talent_points = (
				branch.get_available_talent_points()
			)

		lines.append(
			"%s Strength Branch\n"
			% side_name
			+ "Level %d\n"
			% branch.branch_level
			+ "XP %d / %d\n"
			% [
				branch.current_xp,
				branch.xp_required_per_level
			]
			+ "Damage %.0f\n"
			% branch.get_current_damage()
			+ "Attack Speed %.2f /s\n"
			% attack_speed
			+ "Range %.0f\n"
			% branch.get_current_attack_range()
			+ "Talent Points %d"
			% talent_points
		)

	text = "\n\n".join(lines)


func get_branch_side_name(
	branch: Node
) -> String:
	if branch.facing_side == 0:
		return "Left"

	return "Right"
