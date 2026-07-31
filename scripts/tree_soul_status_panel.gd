extends Panel


var tree_node: Node

var orb_label: Label
var soul_name_label: Label
var rank_label: Label
var description_label: Label
var bonuses_label: Label
var next_rank_label: Label
var rank_progress_bar: ProgressBar


func _ready() -> void:
	visible = false

	create_interface()

	tree_node = get_tree().get_first_node_in_group(
		"tree"
	)

	if tree_node != null:
		tree_node.age_changed.connect(
			_on_tree_age_changed
		)

	TreeSouls.soul_selected.connect(
		_on_soul_selected
	)

	TreeSouls.soul_rank_changed.connect(
		_on_soul_rank_changed
	)

	TreeSouls.soul_cleared.connect(
		_on_soul_cleared
	)

	refresh_panel()


func create_interface() -> void:
	var margin_container := MarginContainer.new()

	margin_container.add_theme_constant_override(
		"margin_left",
		18
	)
	margin_container.add_theme_constant_override(
		"margin_top",
		18
	)
	margin_container.add_theme_constant_override(
		"margin_right",
		18
	)
	margin_container.add_theme_constant_override(
		"margin_bottom",
		18
	)

	add_child(
		margin_container
	)

	margin_container.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var main_container := VBoxContainer.new()

	main_container.add_theme_constant_override(
		"separation",
		10
	)

	margin_container.add_child(
		main_container
	)

	orb_label = Label.new()
	orb_label.text = "●"
	orb_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	orb_label.add_theme_font_size_override(
		"font_size",
		38
	)
	main_container.add_child(
		orb_label
	)

	soul_name_label = Label.new()
	soul_name_label.text = "TREE SOUL"
	soul_name_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	soul_name_label.add_theme_font_size_override(
		"font_size",
		24
	)
	main_container.add_child(
		soul_name_label
	)

	rank_label = Label.new()
	rank_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	rank_label.add_theme_font_size_override(
		"font_size",
		18
	)
	main_container.add_child(
		rank_label
	)

	description_label = Label.new()
	description_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	description_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	description_label.add_theme_font_size_override(
		"font_size",
		15
	)
	main_container.add_child(
		description_label
	)

	var separator := HSeparator.new()
	main_container.add_child(
		separator
	)

	bonuses_label = Label.new()
	bonuses_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	bonuses_label.add_theme_font_size_override(
		"font_size",
		16
	)
	main_container.add_child(
		bonuses_label
	)

	var progress_spacer := Control.new()
	progress_spacer.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	main_container.add_child(
		progress_spacer
	)

	next_rank_label = Label.new()
	next_rank_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	main_container.add_child(
		next_rank_label
	)

	rank_progress_bar = ProgressBar.new()
	rank_progress_bar.custom_minimum_size = Vector2(
		0.0,
		24.0
	)
	rank_progress_bar.min_value = 0.0
	rank_progress_bar.max_value = 100.0
	rank_progress_bar.show_percentage = false
	main_container.add_child(
		rank_progress_bar
	)


func refresh_panel() -> void:
	var tree_age: int = get_tree_age()

	if not TreeSouls.has_selected_soul():
		refresh_without_selected_soul(
			tree_age
		)
		return

	refresh_selected_soul(
		tree_age
	)


func refresh_without_selected_soul(
	tree_age: int
) -> void:
	var awakening_age: int = get_awakening_age()

	orb_label.text = "●"
	orb_label.add_theme_color_override(
		"font_color",
		Color(0.45, 0.45, 0.45, 1.0)
	)

	soul_name_label.text = "TREE SOUL"
	rank_label.text = "INACTIVE"
	bonuses_label.text = "No Soul selected."

	if tree_age < awakening_age:
		description_label.text = (
			"Soul awakens at Age %d."
			% awakening_age
		)

		next_rank_label.text = (
			"%d Age remaining"
			% max(awakening_age - tree_age, 0)
		)

		rank_progress_bar.value = clamp(
			float(tree_age)
			/ float(max(awakening_age, 1))
			* 100.0,
			0.0,
			100.0
		)

		return

	description_label.text = (
		"Choose a Tree Soul for this prestige run."
	)
	next_rank_label.text = "Soul selection available"
	rank_progress_bar.value = 100.0


func refresh_selected_soul(
	tree_age: int
) -> void:
	var soul_definition: TreeSoulDefinition = (
		TreeSouls.selected_soul
	)

	var soul_rank: int = TreeSouls.current_rank

	orb_label.text = "●"
	orb_label.add_theme_color_override(
		"font_color",
		soul_definition.soul_color
	)

	soul_name_label.text = (
		soul_definition.display_name
	)

	soul_name_label.add_theme_color_override(
		"font_color",
		soul_definition.soul_color
	)

	rank_label.text = (
		"RANK %d"
		% soul_rank
	)

	description_label.text = (
		soul_definition.description
	)

	bonuses_label.text = get_bonuses_text(
		soul_definition,
		soul_rank
	)

	var next_rank_age: int = (
		soul_definition.get_next_rank_age(
			tree_age
		)
	)

	var age_remaining: int = (
		soul_definition
		.get_age_remaining_until_next_rank(
			tree_age
		)
	)

	next_rank_label.text = (
		"Next Rank at Age %d · %d remaining"
		% [
			next_rank_age,
			age_remaining
		]
	)

	rank_progress_bar.value = get_rank_progress(
		soul_definition,
		soul_rank,
		tree_age
	)


func get_bonuses_text(
	soul_definition: TreeSoulDefinition,
	soul_rank: int
) -> String:
	var result: String = ""

	for bonus in soul_definition.bonuses:
		if not is_instance_valid(bonus):
			continue

		var current_value: float = (
			bonus.get_value_for_rank(
				soul_rank,
				soul_definition.soft_cap_rank,
				soul_definition.post_soft_cap_multiplier
			)
		)

		var line: String = get_bonus_line(
			bonus.modifier_id,
			current_value
		)

		if result.is_empty():
			result = line
		else:
			result += "\n" + line

	return result


func get_bonus_line(
	modifier_id: StringName,
	value: float
) -> String:
	var bonus_name: String = str(
		modifier_id
	)

	if modifier_id == RunModifierIds.BRANCH_DAMAGE:
		bonus_name = "Branch Damage"
	elif modifier_id == RunModifierIds.ATTACK_SPEED:
		bonus_name = "Attack Speed"
	elif modifier_id == RunModifierIds.TREE_MAX_HEALTH:
		bonus_name = "Maximum HP"
	elif modifier_id == RunModifierIds.TREE_REGEN_RATE:
		return (
			"HP Regeneration: +%.3f%% Max HP/s"
			% (value * 100.0)
		)
	elif modifier_id == RunModifierIds.ESSENCE_GAIN:
		bonus_name = "Essence Gain"
	elif modifier_id == RunModifierIds.HEALING_POWER:
		bonus_name = "Healing Power"

	return (
		"%s: +%.2f%%"
		% [
			bonus_name,
			value * 100.0
		]
	)


func get_rank_progress(
	soul_definition: TreeSoulDefinition,
	soul_rank: int,
	tree_age: int
) -> float:
	var current_rank_age: int = (
		soul_definition.get_age_for_rank(
			soul_rank
		)
	)

	var next_rank_age: int = (
		soul_definition.get_age_for_rank(
			soul_rank + 1
		)
	)

	var required_age: int = max(
		next_rank_age - current_rank_age,
		1
	)

	var gained_age: int = clamp(
		tree_age - current_rank_age,
		0,
		required_age
	)

	return (
		float(gained_age)
		/ float(required_age)
		* 100.0
	)


func get_tree_age() -> int:
	if tree_node == null:
		return 1

	return int(tree_node.age)


func get_awakening_age() -> int:
	var awakening_age: int = 20

	for soul_definition in (
		TreeSouls.get_available_souls()
	):
		awakening_age = min(
			awakening_age,
			soul_definition.awakening_age
		)

	return awakening_age


func _on_tree_age_changed(
	_new_age: int
) -> void:
	refresh_panel()


func _on_soul_selected(
	_soul_definition: TreeSoulDefinition,
	_soul_rank: int
) -> void:
	refresh_panel()


func _on_soul_rank_changed(
	_old_rank: int,
	_new_rank: int
) -> void:
	refresh_panel()


func _on_soul_cleared() -> void:
	refresh_panel()
