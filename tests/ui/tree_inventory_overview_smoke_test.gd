extends Node


const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")


var failures: Array[String] = []


func _ready() -> void:
	var inventory := get_node("/root/Inventory") as InventoryService
	var equipment := get_node("/root/Equipment") as EquipmentService
	equipment.clear_runtime_state_for_testing()
	inventory.clear_runtime_state_for_testing()
	await run_test(inventory, equipment)
	equipment.clear_runtime_state_for_testing()
	inventory.clear_runtime_state_for_testing()
	if failures.is_empty():
		print("TREE INVENTORY OVERVIEW SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("TREE INVENTORY OVERVIEW SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func run_test(inventory: InventoryService, equipment: EquipmentService) -> void:
	var world: Node = MAIN_WORLD_SCENE.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var screen: Control = world.get_node("UI/TreeScreen") as Control
	var overview_panel := screen.get_node("MainPanel/InventoryOverviewPanel") as Panel
	var tree_canvas := screen.get_node("MainPanel/TreeCanvas") as Panel
	var inventory_button := screen.get_node("MainPanel/InventoryButton") as Button
	var empty_label := screen.get_node("MainPanel/InventoryOverviewPanel/EmptyLabel") as Label
	var count_label := screen.get_node("MainPanel/InventoryOverviewPanel/ItemCountLabel") as Label
	var selected_label := screen.get_node("MainPanel/EquipmentDetailPanel/SelectedItemLabel") as Label
	var current_label := screen.get_node("MainPanel/EquipmentDetailPanel/CurrentlyEquippedLabel") as Label

	screen.call("open_inventory_overview")
	expect(
		inventory_button.disabled
		and overview_panel.visible
		and not tree_canvas.visible
		and empty_label.visible
		and empty_label.text == "No equipment in inventory.\nDrops from enemies will appear here.",
		"Inventory entry point or empty state is wrong."
	)

	var items: Array[ItemInstance] = [
		create_item(&"bark_epic", &"living_bark", 14, ItemRarityRules.EPIC, &"branch_damage", 0.13),
		create_item(&"bark_common", &"living_bark", 3, ItemRarityRules.COMMON, &"attack_speed", 0.05),
		create_item(&"roots_uncommon", &"deep_roots", 8, ItemRarityRules.UNCOMMON, &"maximum_health", 20.0),
		create_item(&"heartwood_common", &"elder_heartwood", 6, ItemRarityRules.COMMON, &"branch_damage", 0.07),
		create_item(&"canopy_common", &"verdant_canopy", 7, ItemRarityRules.COMMON, &"attack_speed", 0.08),
		create_item(&"sap_common", &"luminous_sap", 9, ItemRarityRules.COMMON, &"health_regeneration", 0.55)
	]
	items[1].is_locked = true
	for item in items:
		expect(inventory.add_item(item), "Inventory overview fixture add failed.")
	await get_tree().process_frame
	var cards: Dictionary = screen.get("equipment_candidate_buttons_by_instance_id") as Dictionary
	var item_grid := screen.get_node(
		"MainPanel/InventoryOverviewPanel/ScrollContainer/ItemGrid"
	) as GridContainer
	expect(
		cards.size() == 6 and count_label.text == "Items: 6  Owned: 6"
		and item_grid.columns == 5,
		"ALL inventory grid did not show all concrete instances compactly."
	)
	expect(
		cards.has(&"bark_epic") and cards.has(&"bark_common")
		and (cards[&"bark_common"] as Button).text.contains("LOCKED"),
		"Same-definition instance identity or locked marker is wrong."
	)
	var first_card := screen.get_node(
		"MainPanel/InventoryOverviewPanel/ScrollContainer/ItemGrid"
	).get_child(0) as Button
	expect(first_card == cards[&"bark_epic"], "Inventory sorting is not rarity-first and Item-Level descending.")
	expect(
		first_card.custom_minimum_size.x <= 240.0
		and first_card.text.contains("BARK")
		and first_card.text.contains("ILvl 14")
		and not first_card.text.contains("Branch Damage")
		and first_card.get_theme_color("font_color") == ItemRarityRules.get_rarity_color(ItemRarityRules.EPIC),
		"Compact tile fallback, rarity, ILvl, or no-affix presentation is wrong."
	)
	var bark_definition: ItemDefinition = GameContent.get_item(&"living_bark")
	var fixture_icon := GradientTexture1D.new()
	bark_definition.icon = fixture_icon
	screen.call("select_inventory_filter", &"bark")
	cards = screen.get("equipment_candidate_buttons_by_instance_id") as Dictionary
	expect((cards[&"bark_epic"] as Button).icon == fixture_icon, "Actual ItemDefinition icon was not used.")
	bark_definition.icon = null

	for slot_id in EquipmentSlotRules.get_supported_slot_ids():
		expect(screen.call("select_inventory_filter", slot_id), "Inventory slot filter was rejected.")
		cards = screen.get("equipment_candidate_buttons_by_instance_id") as Dictionary
		var expected_count: int = 2 if slot_id == &"bark" else 1
		expect(cards.size() == expected_count, "%s filter returned the wrong cards." % slot_id)
	screen.call("select_inventory_filter", &"")
	cards = screen.get("equipment_candidate_buttons_by_instance_id") as Dictionary

	expect(screen.call("select_equipment_candidate", &"bark_epic"), "Global Inventory item selection failed.")
	expect(
		selected_label.text.contains("Living Bark")
		and selected_label.text.contains("Epic")
		and selected_label.text.contains("Item Level 14")
		and selected_label.text.contains("Bark")
		and selected_label.text.contains("Branch Damage: +13%"),
		"Global Inventory selected detail is incomplete."
	)
	expect(screen.call("equip_selected_equipment"), "Global Inventory equip failed.")
	cards = screen.get("equipment_candidate_buttons_by_instance_id") as Dictionary
	expect(
		equipment.get_equipped_instance_id(&"bark") == &"bark_epic"
		and inventory.get_item_count() == 6
		and not cards.has(&"bark_epic") and cards.has(&"bark_common")
		and not (cards[&"bark_common"] as Button).text.contains("EQUIPPED"),
		"Equipped item was not hidden from Grid while remaining Inventory-owned."
	)
	expect(screen.call("select_equipment_slot", &"bark"), "Equipped Bark Tree tile selection failed.")
	expect(current_label.text.contains("Living Bark"), "Equipped Tree tile did not expose item detail.")
	expect(screen.call("unequip_selected_equipment"), "Global Inventory unequip failed.")
	expect(
		inventory.has_item(&"bark_epic")
		and equipment.get_equipped_instance_id(&"bark") == &"",
		"Global Inventory unequip removed the item or retained equipment state."
	)
	screen.call("open_inventory_overview")
	screen.call("select_inventory_filter", &"")

	var selected_before_drop: StringName = screen.get("selected_equipment_instance_id")
	var live_item := create_item(
		&"live_sap_drop", &"luminous_sap", 12, ItemRarityRules.UNCOMMON,
		&"attack_speed", 0.10
	)
	expect(inventory.add_item(live_item), "Live Inventory item_added fixture failed.")
	cards = screen.get("equipment_candidate_buttons_by_instance_id") as Dictionary
	expect(
		cards.has(live_item.instance_id)
		and screen.get("selected_equipment_instance_id") == selected_before_drop,
		"Open Inventory did not live-refresh or preserve valid selection."
	)

	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func create_item(
	instance_id: StringName,
	definition_id: StringName,
	item_level: int,
	rarity_id: StringName,
	stat_id: StringName,
	value: float
) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.definition_id = definition_id
	item.item_level = item_level
	item.rarity_id = rarity_id
	item.affix_rolls.append(ItemAffixRoll.new(stat_id, value))
	return item


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
