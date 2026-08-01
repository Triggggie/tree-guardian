extends Control


const DISPLAY_DURATION: float = 3.0


var soul_name_label: Label
var rank_label: Label
var bonuses_label: Label
var hide_timer: Timer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	create_interface()

	TreeSouls.soul_rank_changed.connect(
		_on_soul_rank_changed
	)

	TreeSouls.soul_cleared.connect(
		_on_soul_cleared
	)


func create_interface() -> void:
	var notification_panel := PanelContainer.new()
	notification_panel.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	notification_panel.anchor_left = 0.5
	notification_panel.anchor_top = 0.0
	notification_panel.anchor_right = 0.5
	notification_panel.anchor_bottom = 0.0
	notification_panel.offset_left = -360.0
	notification_panel.offset_top = 105.0
	notification_panel.offset_right = 360.0
	notification_panel.offset_bottom = 310.0
	notification_panel.add_theme_stylebox_override(
		"panel",
		create_notification_panel_style()
	)
	add_child(notification_panel)

	var margin_container := MarginContainer.new()
	margin_container.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	margin_container.add_theme_constant_override(
		"margin_left",
		24
	)
	margin_container.add_theme_constant_override(
		"margin_top",
		18
	)
	margin_container.add_theme_constant_override(
		"margin_right",
		24
	)
	margin_container.add_theme_constant_override(
		"margin_bottom",
		18
	)
	notification_panel.add_child(
		margin_container
	)

	var main_container := VBoxContainer.new()
	main_container.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	main_container.add_theme_constant_override(
		"separation",
		6
	)
	margin_container.add_child(
		main_container
	)

	var title_label := Label.new()
	title_label.text = "TREE SOUL RANK UP"
	title_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	title_label.add_theme_font_size_override(
		"font_size",
		24
	)
	title_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	main_container.add_child(
		title_label
	)

	soul_name_label = Label.new()
	soul_name_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	soul_name_label.add_theme_font_size_override(
		"font_size",
		20
	)
	soul_name_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
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
	rank_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	main_container.add_child(
		rank_label
	)

	bonuses_label = Label.new()
	bonuses_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)
	bonuses_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	bonuses_label.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	main_container.add_child(
		bonuses_label
	)

	hide_timer = Timer.new()
	hide_timer.wait_time = DISPLAY_DURATION
	hide_timer.one_shot = true
	hide_timer.timeout.connect(
		_on_hide_timer_timeout
	)
	add_child(hide_timer)


func create_notification_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		0.035,
		0.05,
		0.04,
		0.94
	)
	style.border_color = Color(
		0.35,
		0.55,
		0.38,
		0.95
	)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14

	return style


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


func _on_soul_rank_changed(
	old_rank: int,
	new_rank: int
) -> void:
	if old_rank < 1 or new_rank <= old_rank:
		return

	if not TreeSouls.has_selected_soul():
		return

	if not TreeSouls.has_unannounced_rank_up():
		return

	var soul_definition: TreeSoulDefinition = (
		TreeSouls.selected_soul
	)

	if not is_instance_valid(soul_definition):
		return

	if not soul_definition.is_valid_definition():
		return

	soul_name_label.text = soul_definition.display_name
	soul_name_label.add_theme_color_override(
		"font_color",
		soul_definition.soul_color
	)
	rank_label.text = (
		"RANK %d → %d"
		% [
			old_rank,
			new_rank
		]
	)
	bonuses_label.text = get_bonuses_text(
		soul_definition,
		new_rank
	)

	visible = true
	hide_timer.start()
	TreeSouls.mark_current_rank_announced()


func _on_soul_cleared() -> void:
	hide_timer.stop()
	visible = false


func _on_hide_timer_timeout() -> void:
	visible = false
