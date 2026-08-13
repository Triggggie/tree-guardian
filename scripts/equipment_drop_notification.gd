class_name EquipmentDropNotification
extends Control


signal notification_presented(instance_id: StringName)


const TITLE_TEXT: String = "EQUIPMENT FOUND"
const HINT_TEXT: String = "Available in TREE"
const MAXIMUM_PENDING_NOTIFICATIONS: int = 5
const FADE_IN_DURATION: float = 0.20
const FADE_OUT_DURATION: float = 0.30
const SLIDE_OFFSET: float = 18.0


@export_range(0.05, 30.0, 0.05)
var display_duration: float = 2.5


var equipment_loot_service: EquipmentLootService
var pending_notifications: Array[Dictionary] = []
var current_instance_id: StringName = &""
var presentation_tween: Tween
var notification_panel: PanelContainer
var notification_style: StyleBoxFlat
var title_label: Label
var item_name_label: Label
var rarity_label: Label
var affix_list_label: Label
var source_label: Label
var hint_label: Label
var panel_rest_y: float = 0.0


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	create_interface()
	bind_equipment_loot_service(EquipmentLoot)


func _exit_tree() -> void:
	_disconnect_equipment_loot_service()


func bind_equipment_loot_service(service: EquipmentLootService) -> void:
	if equipment_loot_service == service:
		return
	_disconnect_equipment_loot_service()
	equipment_loot_service = service
	if (
		is_instance_valid(equipment_loot_service)
		and not equipment_loot_service.equipment_item_dropped.is_connected(
			_on_equipment_item_dropped
		)
	):
		equipment_loot_service.equipment_item_dropped.connect(
			_on_equipment_item_dropped
		)


func create_interface() -> void:
	notification_panel = PanelContainer.new()
	notification_panel.name = "NotificationPanel"
	notification_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notification_panel.anchor_left = 1.0
	notification_panel.anchor_top = 0.0
	notification_panel.anchor_right = 1.0
	notification_panel.anchor_bottom = 0.0
	notification_panel.offset_left = -520.0
	notification_panel.offset_top = 110.0
	notification_panel.offset_right = -40.0
	notification_panel.offset_bottom = 380.0
	notification_style = create_notification_panel_style()
	notification_panel.add_theme_stylebox_override("panel", notification_style)
	add_child(notification_panel)
	panel_rest_y = notification_panel.position.y

	var margin_container := MarginContainer.new()
	margin_container.name = "Content"
	margin_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin_container.add_theme_constant_override("margin_left", 24)
	margin_container.add_theme_constant_override("margin_top", 18)
	margin_container.add_theme_constant_override("margin_right", 24)
	margin_container.add_theme_constant_override("margin_bottom", 18)
	notification_panel.add_child(margin_container)

	var main_container := VBoxContainer.new()
	main_container.name = "Labels"
	main_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_container.add_theme_constant_override("separation", 5)
	margin_container.add_child(main_container)

	title_label = create_centered_label("TitleLabel", 20)
	title_label.text = TITLE_TEXT
	main_container.add_child(title_label)
	item_name_label = create_centered_label("ItemNameLabel", 27)
	main_container.add_child(item_name_label)
	rarity_label = create_centered_label("RarityLabel", 18)
	main_container.add_child(rarity_label)
	affix_list_label = create_centered_label("AffixListLabel", 17)
	main_container.add_child(affix_list_label)
	source_label = create_centered_label("SourceLabel", 16)
	main_container.add_child(source_label)
	hint_label = create_centered_label("HintLabel", 15)
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
	style.bg_color = Color(0.035, 0.045, 0.035, 0.97)
	style.border_color = ItemRarityRules.get_rarity_color(
		ItemRarityRules.COMMON
	)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	return style


func _on_equipment_item_dropped(
	instance_id: StringName,
	enemy_id: StringName,
	world_position: Vector2
) -> void:
	if not _is_valid_inventory_item(instance_id):
		return
	if pending_notifications.size() >= MAXIMUM_PENDING_NOTIFICATIONS:
		pending_notifications.pop_front()
	pending_notifications.append({
		"instance_id": instance_id,
		"enemy_id": enemy_id,
		"world_position": world_position
	})
	if current_instance_id == &"":
		_show_next_notification()


func _show_next_notification() -> void:
	current_instance_id = &""
	while not pending_notifications.is_empty():
		var notification: Dictionary = pending_notifications.pop_front()
		var instance_id := StringName(notification.get("instance_id", &""))
		var item: ItemInstance = Inventory.get_item(instance_id)
		if item == null or not item.is_valid_data():
			continue
		var definition: ItemDefinition = GameContent.get_item(item.definition_id)
		if not is_instance_valid(definition) or not definition.is_valid_definition():
			continue
		current_instance_id = instance_id
		_apply_item_presentation(
			item,
			definition,
			StringName(notification.get("enemy_id", &""))
		)
		start_presentation()
		notification_presented.emit(current_instance_id)
		return
	visible = false


func _apply_item_presentation(
	item: ItemInstance,
	definition: ItemDefinition,
	enemy_id: StringName
) -> void:
	var rarity_name: String = ItemRarityRules.get_rarity_display_name(
		item.rarity_id
	)
	var rarity_color: Color = ItemRarityRules.get_rarity_color(item.rarity_id)
	item_name_label.text = definition.display_name
	item_name_label.add_theme_color_override("font_color", rarity_color)
	rarity_label.text = "%s • Item Level %d" % [
		rarity_name.to_upper(),
		item.item_level
	]
	rarity_label.add_theme_color_override("font_color", rarity_color)
	notification_style.border_color = rarity_color

	var affix_lines: Array[String] = []
	for affix in item.affix_rolls:
		if (
			affix == null
			or not EquipmentStatRules.is_supported_stat_id(affix.stat_id)
		):
			continue
		affix_lines.append("%s: %s" % [
			EquipmentStatRules.get_stat_display_name(affix.stat_id),
			EquipmentStatRules.format_stat_value(affix.stat_id, affix.value)
		])
	affix_list_label.text = "\n".join(affix_lines)
	affix_list_label.visible = not affix_lines.is_empty()

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
	hint_label.text = HINT_TEXT


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
	presentation_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)
	presentation_tween.parallel().tween_property(
		notification_panel,
		"position:y",
		panel_rest_y,
		FADE_IN_DURATION
	)
	presentation_tween.tween_interval(display_duration)
	presentation_tween.set_ease(Tween.EASE_IN)
	presentation_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)
	presentation_tween.tween_callback(_finish_presentation)


func hide_presentation() -> void:
	if is_instance_valid(presentation_tween):
		presentation_tween.kill()
	presentation_tween = null
	_finish_presentation()


func get_pending_notification_count() -> int:
	return pending_notifications.size()


func _finish_presentation() -> void:
	visible = false
	modulate.a = 1.0
	if is_instance_valid(notification_panel):
		notification_panel.position.y = panel_rest_y
	presentation_tween = null
	current_instance_id = &""
	_show_next_notification()


func _is_valid_inventory_item(instance_id: StringName) -> bool:
	if instance_id == &"":
		return false
	var item: ItemInstance = Inventory.get_item(instance_id)
	return item != null and item.is_valid_data()


func _disconnect_equipment_loot_service() -> void:
	if (
		is_instance_valid(equipment_loot_service)
		and equipment_loot_service.equipment_item_dropped.is_connected(
			_on_equipment_item_dropped
		)
	):
		equipment_loot_service.equipment_item_dropped.disconnect(
			_on_equipment_item_dropped
		)
	equipment_loot_service = null
