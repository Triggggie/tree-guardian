extends Control


var tree_node: Node

var dark_background: ColorRect
var selection_panel: PanelContainer
var soul_buttons: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	mouse_filter = Control.MOUSE_FILTER_STOP

	create_interface()

	tree_node = get_tree().get_first_node_in_group(
		"tree"
	)

	if tree_node == null:
		visible = false
		return

	tree_node.age_changed.connect(
		_on_tree_age_changed
	)

	TreeSouls.soul_selected.connect(
		_on_soul_selected
	)

	refresh_for_age(
		int(tree_node.age)
	)


func create_interface() -> void:
	dark_background = ColorRect.new()
	dark_background.color = Color(
		0.0,
		0.0,
		0.0,
		0.72
	)
	dark_background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	add_child(dark_background)

	selection_panel = PanelContainer.new()
	selection_panel.anchor_left = 0.5
	selection_panel.anchor_top = 0.5
	selection_panel.anchor_right = 0.5
	selection_panel.anchor_bottom = 0.5
	selection_panel.offset_left = -700.0
	selection_panel.offset_top = -230.0
	selection_panel.offset_right = 700.0
	selection_panel.offset_bottom = 230.0
	add_child(selection_panel)

	var main_container := VBoxContainer.new()
	main_container.add_theme_constant_override(
		"separation",
		18
	)
	selection_panel.add_child(main_container)

	var title_label := Label.new()
	title_label.text = "YOUR TREE SOUL AWAKENS"
	title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title_label.add_theme_font_size_override(
		"font_size",
		32
	)
	main_container.add_child(title_label)

	var description_label := Label.new()
	description_label.text = (
		"Choose one Soul for this prestige run."
	)
	description_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	description_label.add_theme_font_size_override(
		"font_size",
		18
	)
	main_container.add_child(description_label)

	soul_buttons = HBoxContainer.new()
	soul_buttons.alignment = (
		BoxContainer.ALIGNMENT_CENTER
	)
	soul_buttons.add_theme_constant_override(
		"separation",
		16
	)
	main_container.add_child(soul_buttons)


func refresh_for_age(
	tree_age: int
) -> void:
	if TreeSouls.has_selected_soul():
		visible = false
		return

	var selection_available: bool = false

	for soul_definition in (
		TreeSouls.get_available_souls()
	):
		if TreeSouls.can_select_soul(
			soul_definition,
			tree_age
		):
			selection_available = true
			break

	visible = selection_available

	if not selection_available:
		return

	rebuild_soul_buttons(
		tree_age
	)


func rebuild_soul_buttons(
	tree_age: int
) -> void:
	for old_button in soul_buttons.get_children():
		soul_buttons.remove_child(
			old_button
		)
		old_button.queue_free()

	for soul_definition in (
		TreeSouls.get_available_souls()
	):
		var soul_button := Button.new()

		soul_button.custom_minimum_size = Vector2(
			300.0,
			180.0
		)

		soul_button.text = (
			soul_definition.display_name
			+ "\n\n"
			+ soul_definition.description
		)

		soul_button.tooltip_text = (
			soul_definition.description
		)

		soul_button.disabled = (
			not TreeSouls.can_select_soul(
				soul_definition,
				tree_age
			)
		)

		soul_button.add_theme_color_override(
			"font_color",
			soul_definition.soul_color
		)

		soul_button.pressed.connect(
			_on_soul_button_pressed.bind(
				soul_definition.tree_soul_id
			)
		)

		soul_buttons.add_child(
			soul_button
		)


func _on_tree_age_changed(
	new_age: int
) -> void:
	refresh_for_age(
		new_age
	)


func _on_soul_button_pressed(
	tree_soul_id: StringName
) -> void:
	if tree_node == null:
		return

	TreeSouls.select_soul_by_id(
		tree_soul_id,
		int(tree_node.age)
	)


func _on_soul_selected(
	_soul_definition: TreeSoulDefinition,
	_soul_rank: int
) -> void:
	visible = false
