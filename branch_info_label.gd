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
			branch.level_changed.connect(_on_branch_level_changed)

	update_label()


func _process(_delta: float) -> void:
	update_label()


func _on_branch_level_changed(_new_level: int) -> void:
	update_label()


func update_label() -> void:
	if strength_branches.is_empty():
		text = "Strength Branch nenalezena"
		return

	var lines: Array[String] = []

	for branch in strength_branches:
		if not is_instance_valid(branch):
			continue

		var side_name: String = get_branch_side_name(branch)

		lines.append(
			"%s Strength Branch\n"
			% side_name
			+ "Level %d\n" % branch.branch_level
			+ "XP %d / %d\n" % [
				branch.current_xp,
				branch.xp_required_per_level
			]
			+ "Damage %.0f\n" % branch.get_current_damage()
			+ "Cooldown %.2f s"
			% branch.get_current_attack_cooldown()
		)

	text = "\n\n".join(lines)


func get_branch_side_name(branch: Node) -> String:
	if branch.facing_side == 0:
		return "Left"

	return "Right"
