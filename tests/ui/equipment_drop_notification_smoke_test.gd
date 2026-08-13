extends Node


const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")


var failures: Array[String] = []
var presented_ids: Array[StringName] = []


func _ready() -> void:
	var inventory := get_node("/root/Inventory") as InventoryService
	var equipment := get_node("/root/Equipment") as EquipmentService
	equipment.clear_runtime_state_for_testing()
	inventory.clear_runtime_state_for_testing()
	EquipmentLoot.clear_runtime_state_for_testing()
	await run_test(inventory)
	equipment.clear_runtime_state_for_testing()
	inventory.clear_runtime_state_for_testing()
	EquipmentLoot.clear_runtime_state_for_testing()

	if failures.is_empty():
		print("EQUIPMENT DROP NOTIFICATION SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("EQUIPMENT DROP NOTIFICATION SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func run_test(inventory: InventoryService) -> void:
	var world: Node = MAIN_WORLD_SCENE.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await get_tree().process_frame
	var notification := world.get_node(
		"UI/EquipmentDropNotification"
	) as EquipmentDropNotification
	var seed_notification := world.get_node(
		"UI/BranchSeedDropNotification"
	) as BranchSeedDropNotification
	notification.notification_presented.connect(_on_notification_presented)
	var panel := notification.get_node("NotificationPanel") as Control
	expect(
		is_equal_approx(panel.anchor_left, 0.5)
		and is_equal_approx(panel.anchor_right, 0.5)
		and is_equal_approx(panel.anchor_top, 0.5)
		and is_equal_approx(panel.anchor_bottom, 0.5)
		and panel.offset_left < 0.0
		and panel.offset_right > 0.0,
		"Equipment notification is not semantically centered."
	)

	var items: Array[ItemInstance] = []
	for item_index in range(7):
		var rarity_id: StringName = (
			ItemRarityRules.EPIC
			if item_index == 0
			else ItemRarityRules.COMMON
		)
		var item := create_item(
			StringName("notification_item_%d" % item_index),
			rarity_id,
			item_index + 1
		)
		items.append(item)
		expect(inventory.add_item(item), "Notification fixture item was rejected.")

	EquipmentLoot.equipment_item_dropped.emit(
		items[0].instance_id,
		&"ancient_bark_colossus",
		Vector2.ZERO
	)
	expect(
		notification.visible
		and notification.current_instance_id == items[0].instance_id
		and notification.item_name_label.text == "Living Bark"
		and notification.rarity_label.text.contains("EPIC")
		and notification.rarity_label.text.contains("Item Level 1")
		and notification.affix_list_label.text.contains("Branch Damage: +10%")
		and notification.source_label.text == "Dropped by Ancient Bark Colossus"
		and notification.hint_label.text == "Available in TREE"
		and notification.rarity_label.get_theme_color("font_color") == ItemRarityRules.get_rarity_color(ItemRarityRules.EPIC),
		"Epic equipment notification content or color is wrong."
	)
	expect(
		not get_tree().paused
		and notification.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Equipment notification paused or captured input."
	)

	for item_index in range(1, items.size()):
		EquipmentLoot.equipment_item_dropped.emit(
			items[item_index].instance_id,
			&"missing_enemy",
			Vector2.ZERO
		)
	expect(
		notification.get_pending_notification_count() == 5,
		"Notification queue is not bounded to five pending rewards."
	)
	EquipmentLoot.equipment_item_dropped.emit(
		&"missing_instance",
		&"bark_beetle",
		Vector2.ZERO
	)
	expect(
		notification.get_pending_notification_count() == 5,
		"Unknown instance ID entered the notification queue."
	)

	while notification.current_instance_id != &"":
		notification.hide_presentation()
	expect(
		presented_ids == [
			items[0].instance_id,
			items[2].instance_id,
			items[3].instance_id,
			items[4].instance_id,
			items[5].instance_id,
			items[6].instance_id
		],
		"Notification queue order or oldest-pending overflow policy is wrong."
	)
	expect(
		not notification.source_label.visible,
		"Unknown enemy source was not hidden."
	)

	EquipmentLoot.equipment_item_dropped.emit(
		items[0].instance_id,
		&"ancient_bark_colossus",
		Vector2.ZERO
	)
	seed_notification.call(
		"_on_branch_seed_dropped",
		&"thorn_crown",
		&"ancient_bark_colossus",
		Vector2.ZERO
	)
	var equipment_rect: Rect2 = notification.notification_panel.get_global_rect()
	var seed_panel := seed_notification.get_node("NotificationPanel") as Control
	expect(
		notification.visible
		and seed_notification.visible
		and not equipment_rect.intersects(seed_panel.get_global_rect())
		and not get_tree().paused,
		"Equipment and Branch Seed notifications overlap, conflict, or pause."
	)

	notification.hide_presentation()
	seed_notification.call("hide_presentation")
	world.queue_free()
	await get_tree().process_frame


func create_item(
	instance_id: StringName,
	rarity_id: StringName,
	item_level: int
) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.definition_id = &"living_bark"
	item.item_level = item_level
	item.rarity_id = rarity_id
	item.affix_rolls.append(ItemAffixRoll.new(&"branch_damage", 0.10))
	return item


func _on_notification_presented(instance_id: StringName) -> void:
	presented_ids.append(instance_id)


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
