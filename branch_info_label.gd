extends Label


var strength_branch: Node


func _ready() -> void:
	strength_branch = get_tree().get_first_node_in_group(
		"strength_branch"
	)

	if strength_branch == null:
		text = "Strength Branch nenalezena"
		return

	strength_branch.level_changed.connect(
		_on_level_changed
	)

	update_label()


func _process(_delta: float) -> void:
	if is_instance_valid(strength_branch):
		update_label()


func _on_level_changed(_new_level: int) -> void:
	update_label()


func update_label() -> void:
	text = (
		"Strength Branch\n"
		+ "Level %d\n" % strength_branch.branch_level
		+ "XP %d / %d\n" % [
			strength_branch.current_xp,
			strength_branch.xp_required_per_level
		]
		+ "Damage %.0f" % strength_branch.get_current_damage()
	)
