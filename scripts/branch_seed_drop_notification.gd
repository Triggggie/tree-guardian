class_name BranchSeedDropNotification
extends Control


const TITLE_TEXT: String = "LEGENDARY BRANCH SEED UNLOCKED"
const HINT_TEXT: String = "Available in TREE during Preparation"
const FADE_IN_DURATION: float = 0.22
const FADE_OUT_DURATION: float = 0.30
const SLIDE_OFFSET: float = 18.0


@export_range(0.05, 30.0, 0.05)
var display_duration: float = 4.0


var branch_seed_service: BranchSeedService
var presentation_tween: Tween
var notification_panel: PanelContainer
var title_label: Label
var branch_name_label: Label
var tier_label: Label
var source_label: Label
var hint_label: Label
var panel_rest_y: float = 0.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	create_interface()
	bind_branch_seed_service(BranchSeeds)


func _exit_tree() -> void:
	_disconnect_branch_seed_service()


func bind_branch_seed_service(service: BranchSeedService) -> void:
	if branch_seed_service == service:
		return

	_disconnect_branch_seed_service()
	branch_seed_service = service

	if (
		is_instance_valid(branch_seed_service)
		and not branch_seed_service.branch_seed_dropped.is_connected(
			_on_branch_seed_dropped
		)
	):
		branch_seed_service.branch_seed_dropped.connect(
			_on_branch_seed_dropped
		)


func create_interface() -> void:
	notification_panel = PanelContainer.new()
	notification_panel.name = "NotificationPanel"
	notification_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_panel.anchor_left = 0.5
	notification_panel.anchor_top = 0.0
	notification_panel.anchor_right = 0.5
	notification_panel.anchor_bottom = 0.0
	notification_panel.offset_left = -360.0
	notification_panel.offset_top = 330.0
	notification_panel.offset_right = 360.0
	notification_panel.offset_bottom = 570.0
	notification_panel.add_theme_stylebox_override(
		"panel",
		create_notification_panel_style()
	)
	add_child(notification_panel)
	panel_rest_y = notification_panel.position.y

	var margin_container := MarginContainer.new()
	margin_container.name = "Content"
	margin_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin_container.add_theme_constant_override("margin_left", 28)
	margin_container.add_theme_constant_override("margin_top", 20)
	margin_container.add_theme_constant_override("margin_right", 28)
	margin_container.add_theme_constant_override("margin_bottom", 20)
	notification_panel.add_child(margin_container)

	var main_container := VBoxContainer.new()
	main_container.name = "Labels"
	main_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_container.add_theme_constant_override("separation", 6)
	margin_container.add_child(main_container)

	title_label = create_centered_label("TitleLabel", 22)
	title_label.text = TITLE_TEXT
	title_label.add_theme_color_override(
		"font_color",
		Color(0.96, 0.78, 0.32, 1.0)
	)
	main_container.add_child(title_label)

	branch_name_label = create_centered_label("BranchNameLabel", 30)
	branch_name_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.91, 0.58, 1.0)
	)
	main_container.add_child(branch_name_label)

	tier_label = create_centered_label("TierLabel", 19)
	main_container.add_child(tier_label)

	source_label = create_centered_label("SourceLabel", 17)
	main_container.add_child(source_label)

	hint_label = create_centered_label("HintLabel", 16)
	hint_label.text = HINT_TEXT
	hint_label.add_theme_color_override(
		"font_color",
		Color(0.78, 0.82, 0.76, 1.0)
	)
	main_container.add_child(hint_label)


func create_centered_label(label_name: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = label_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	return label


func create_notification_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.04, 0.025, 0.97)
	style.border_color = Color(0.78, 0.58, 0.18, 0.98)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	return style


func _on_branch_seed_dropped(
	branch_id: StringName,
	enemy_id: StringName,
	_world_position: Vector2
) -> void:
	var branch_definition: BranchDefinition = GameContent.get_branch(branch_id)
	if (
		not is_instance_valid(branch_definition)
		or not branch_definition.is_valid_definition()
		or not branch_definition.is_legendary_branch()
	):
		push_warning(
			"Branch Seed notification ignored unknown or invalid Branch '%s'."
			% branch_id
		)
		return

	var tier_text: String = (
		branch_definition.get_legendary_tier_display_name()
	)
	if tier_text.is_empty():
		push_warning(
			"Branch Seed notification ignored Branch '%s' with invalid Tier."
			% branch_id
		)
		return

	branch_name_label.text = branch_definition.display_name
	tier_label.text = tier_text
	hint_label.text = HINT_TEXT

	var enemy_definition: EnemyDefinition = GameContent.get_enemy(enemy_id)
	if (
		is_instance_valid(enemy_definition)
		and enemy_definition.is_valid_definition()
	):
		source_label.text = "Dropped by %s" % enemy_definition.display_name
		source_label.visible = true
	else:
		source_label.text = ""
		source_label.visible = false

	start_presentation()


func start_presentation() -> void:
	if is_instance_valid(presentation_tween):
		presentation_tween.kill()

	visible = true
	modulate.a = 0.0
	notification_panel.position.y = panel_rest_y - SLIDE_OFFSET

	presentation_tween = create_tween()
	presentation_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	presentation_tween.set_trans(Tween.TRANS_QUAD)
	presentation_tween.set_ease(Tween.EASE_OUT)
	presentation_tween.tween_property(
		self,
		"modulate:a",
		1.0,
		FADE_IN_DURATION
	)
	presentation_tween.parallel().tween_property(
		notification_panel,
		"position:y",
		panel_rest_y,
		FADE_IN_DURATION
	)
	presentation_tween.tween_interval(display_duration)
	presentation_tween.set_ease(Tween.EASE_IN)
	presentation_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		FADE_OUT_DURATION
	)
	presentation_tween.tween_callback(_finish_presentation)


func hide_presentation() -> void:
	if is_instance_valid(presentation_tween):
		presentation_tween.kill()
	presentation_tween = null
	_finish_presentation()


func _finish_presentation() -> void:
	visible = false
	modulate.a = 1.0
	if is_instance_valid(notification_panel):
		notification_panel.position.y = panel_rest_y


func _disconnect_branch_seed_service() -> void:
	if (
		is_instance_valid(branch_seed_service)
		and branch_seed_service.branch_seed_dropped.is_connected(
			_on_branch_seed_dropped
		)
	):
		branch_seed_service.branch_seed_dropped.disconnect(
			_on_branch_seed_dropped
		)
	branch_seed_service = null
