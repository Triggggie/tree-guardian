extends Control


var tree_node: Node

var dark_background: ColorRect
var selection_panel: PanelContainer
var soul_buttons: GridContainer


func _ready() -> void:
	visible = false

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
		0.78
	)
	dark_background.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)
	add_child(dark_background)

	dark_background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	selection_panel = PanelContainer.new()
	selection_panel.anchor_left = 0.5
	selection_panel.anchor_top = 0.5
	selection_panel.anchor_right = 0.5
	selection_panel.anchor_bottom = 0.5
	selection_panel.offset_left = -820.0
	selection_panel.offset_top = -290.0
	selection_panel.offset_right = 820.0
	selection_panel.offset_bottom = 290.0
	selection_panel.add_theme_stylebox_override(
		"panel",
		create_selection_panel_style()
	)
	add_child(selection_panel)

	var margin_container := MarginContainer.new()
	margin_container.add_theme_constant_override(
		"margin_left",
		32
	)
	margin_container.add_theme_constant_override(
		"margin_top",
		28
	)
	margin_container.add_theme_constant_override(
		"margin_right",
		32
	)
	margin_container.add_theme_constant_override(
		"margin_bottom",
		28
	)
	selection_panel.add_child(
		margin_container
	)

	var main_container := VBoxContainer.new()
	main_container.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	main_container.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	main_container.add_theme_constant_override(
		"separation",
		14
	)
	margin_container.add_child(
		main_container
	)

	var title_label := Label.new()
	title_label.text = "YOUR TREE SOUL AWAKENS"
	title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title_label.add_theme_font_size_override(
		"font_size",
		34
	)
	title_label.add_theme_color_override(
		"font_color",
		Color(0.92, 1.0, 0.92, 1.0)
	)
	title_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	main_container.add_child(
		title_label
	)

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
	description_label.add_theme_color_override(
		"font_color",
		Color(0.72, 0.78, 0.72, 1.0)
	)
	description_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	main_container.add_child(
		description_label
	)

	var separator := HSeparator.new()
	separator.custom_minimum_size = Vector2(
		0.0,
		12.0
	)
	separator.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	main_container.add_child(
		separator
	)

	soul_buttons = GridContainer.new()
	soul_buttons.columns = 4
	soul_buttons.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	soul_buttons.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	soul_buttons.add_theme_constant_override(
		"h_separation",
		18
	)
	soul_buttons.add_theme_constant_override(
		"v_separation",
		18
	)
	main_container.add_child(
		soul_buttons
	)


func create_selection_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color(
		0.035,
		0.05,
		0.04,
		0.98
	)

	style.border_color = Color(
		0.25,
		0.42,
		0.28,
		1.0
	)

	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2

	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18

	return style


func create_soul_card_style(
	soul_color: Color,
	darkening: float,
	border_width: int,
	border_alpha: float
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	var background_color: Color = (
		soul_color.darkened(
			darkening
		)
	)
	background_color.a = 0.96

	var outline_color: Color = soul_color
	outline_color.a = border_alpha

	style.bg_color = background_color
	style.border_color = outline_color

	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width

	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14

	return style


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
			360.0,
			250.0
		)

		soul_button.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)

		soul_button.size_flags_vertical = (
			Control.SIZE_EXPAND_FILL
		)

		soul_button.clip_contents = true

		soul_button.tooltip_text = (
			soul_definition.description
		)

		soul_button.disabled = (
			not TreeSouls.can_select_soul(
				soul_definition,
				tree_age
			)
		)

		soul_button.add_theme_stylebox_override(
			"normal",
			create_soul_card_style(
				soul_definition.soul_color,
				0.82,
				2,
				0.85
			)
		)

		soul_button.add_theme_stylebox_override(
			"hover",
			create_soul_card_style(
				soul_definition.soul_color,
				0.70,
				3,
				1.0
			)
		)

		soul_button.add_theme_stylebox_override(
			"pressed",
			create_soul_card_style(
				soul_definition.soul_color,
				0.60,
				3,
				1.0
			)
		)

		soul_button.add_theme_stylebox_override(
			"focus",
			create_soul_card_style(
				soul_definition.soul_color,
				0.72,
				3,
				1.0
			)
		)

		soul_button.pressed.connect(
			_on_soul_button_pressed.bind(
				soul_definition.tree_soul_id
			)
		)

		soul_buttons.add_child(
			soul_button
		)

		create_soul_card_content(
			soul_button,
			soul_definition
		)


func create_soul_card_content(
	soul_button: Button,
	soul_definition: TreeSoulDefinition
) -> void:
	var card_content := VBoxContainer.new()

	card_content.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	card_content.add_theme_constant_override(
		"separation",
		8
	)

	soul_button.add_child(
		card_content
	)

	card_content.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	card_content.offset_left = 20.0
	card_content.offset_top = 16.0
	card_content.offset_right = -20.0
	card_content.offset_bottom = -16.0

	var orb_label := Label.new()
	orb_label.text = "●"
	orb_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	orb_label.custom_minimum_size = Vector2(
		0.0,
		42.0
	)
	orb_label.add_theme_font_size_override(
		"font_size",
		36
	)
	orb_label.add_theme_color_override(
		"font_color",
		soul_definition.soul_color
	)
	orb_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	card_content.add_child(
		orb_label
	)

	var soul_name_label := Label.new()
	soul_name_label.text = (
		soul_definition.display_name
	)
	soul_name_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	soul_name_label.add_theme_font_size_override(
		"font_size",
		22
	)
	soul_name_label.add_theme_color_override(
		"font_color",
		soul_definition.soul_color
	)
	soul_name_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	card_content.add_child(
		soul_name_label
	)

	var description_label := Label.new()
	description_label.text = (
		soul_definition.description
	)
	description_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	description_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)
	description_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	description_label.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)
	description_label.add_theme_font_size_override(
		"font_size",
		16
	)
	description_label.add_theme_color_override(
		"font_color",
		Color(0.92, 0.95, 0.92, 1.0)
	)
	description_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	card_content.add_child(
		description_label
	)

	var rank_label := Label.new()
	rank_label.text = "Awakens at Rank 1"
	rank_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	rank_label.add_theme_font_size_override(
		"font_size",
		14
	)
	rank_label.add_theme_color_override(
		"font_color",
		Color(0.65, 0.70, 0.65, 1.0)
	)
	rank_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	card_content.add_child(
		rank_label
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
