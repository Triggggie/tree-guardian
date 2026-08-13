extends Node


const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")
const BARK_BEETLE: EnemyDefinition = preload(
	"res://resources/enemies/bark_beetle_definition.tres"
)

var failures: Array[String] = []


func _ready() -> void:
	var inventory := get_node("/root/Inventory") as InventoryService
	var equipment := get_node("/root/Equipment") as EquipmentService
	equipment.clear_runtime_state_for_testing()
	inventory.clear_runtime_state_for_testing()
	EquipmentLoot.clear_runtime_state_for_testing()
	await run_test(inventory, equipment)
	equipment.clear_runtime_state_for_testing()
	inventory.clear_runtime_state_for_testing()
	EquipmentLoot.clear_runtime_state_for_testing()

	if failures.is_empty():
		print("TREE EQUIPMENT INVENTORY SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("TREE EQUIPMENT INVENTORY SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func run_test(
	inventory: InventoryService,
	equipment: EquipmentService
) -> void:
	var world: Node = MAIN_WORLD_SCENE.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var manager: Node = world.get_node("WaveManager")
	var director := world.get_node("WaveDirector") as WaveDirector
	var tree_node: Node = world.get_node("Entities/Tree")
	var screen: Control = world.get_node("UI/TreeScreen") as Control
	var detail_panel := screen.get_node("MainPanel/DetailPanel") as Panel
	var seed_panel := screen.get_node("MainPanel/SeedPanel") as Panel
	var equipment_detail := screen.get_node("MainPanel/EquipmentDetailPanel") as Panel
	var inventory_panel := screen.get_node("MainPanel/EquipmentInventoryPanel") as Panel
	var bark_button := screen.get_node("MainPanel/TreeCanvas/BarkButton") as Button
	var roots_button := screen.get_node("MainPanel/TreeCanvas/RootsButton") as Button
	var slot_one_button := screen.get_node("MainPanel/TreeCanvas/Slot1Button") as Button
	var apex_button := screen.get_node("MainPanel/TreeCanvas/ApexButton") as Button
	var current_label := screen.get_node("MainPanel/EquipmentDetailPanel/CurrentlyEquippedLabel") as Label
	var selected_label := screen.get_node("MainPanel/EquipmentDetailPanel/SelectedItemLabel") as Label
	var status_label := screen.get_node("MainPanel/EquipmentDetailPanel/StatusLabel") as Label
	var empty_label := screen.get_node("MainPanel/EquipmentInventoryPanel/EmptyLabel") as Label
	var equip_button := screen.get_node("MainPanel/EquipmentDetailPanel/EquipButton") as Button
	var unequip_button := screen.get_node("MainPanel/EquipmentDetailPanel/UnequipButton") as Button

	expect(screen.visible and manager.is_preparation_active(), "TREE is not open in initial Preparation.")
	expect(bark_button.text == "BARK\nEMPTY" and roots_button.text == "ROOTS\nEMPTY", "Initial equipment buttons are not EMPTY.")
	expect(bark_button.position.y > apex_button.position.y and bark_button.position.y < roots_button.position.y and roots_button.position.y > slot_one_button.position.y, "Bark/Roots buttons are not placed at trunk/roots positions.")
	expect(screen.call("select_equipment_slot", &"bark"), "Bark selection failed.")
	expect(not detail_panel.visible and not seed_panel.visible and equipment_detail.visible and inventory_panel.visible, "Equipment mode visibility is wrong.")
	expect(empty_label.visible and empty_label.text == "No Bark items in inventory." and equip_button.disabled and unequip_button.disabled, "Empty Bark inventory state is wrong.")
	expect(screen.call("select_equipment_slot", &"roots"), "Roots empty selection failed.")
	expect(empty_label.text == "No Roots items in inventory." and equip_button.disabled and unequip_button.disabled, "Empty Roots inventory state is wrong.")

	var forced_drop_enemy: EnemyDefinition = BARK_BEETLE.duplicate(true)
	forced_drop_enemy.equipment_drop_chance = 1.0
	EquipmentLoot.set_random_seed_for_testing(311)
	var generated_ids: Array[StringName] = []
	var generated_bark: ItemInstance
	screen.call("select_equipment_slot", &"bark")
	for drop_index in range(10):
		var dropped_item: ItemInstance = EquipmentLoot.process_enemy_defeat(
			forced_drop_enemy,
			GameContent.get_stage(&"guardian_grove"),
			1,
			Vector2.ZERO
		)
		if dropped_item == null:
			continue
		generated_ids.append(dropped_item.instance_id)
		var dropped_definition: ItemDefinition = GameContent.get_item(
			dropped_item.definition_id
		)
		if dropped_definition.equipment_slot_id == EquipmentSlotRules.BARK_SLOT_ID:
			generated_bark = dropped_item
			break
	var live_drop_buttons: Dictionary = screen.get(
		"equipment_candidate_buttons_by_instance_id"
	) as Dictionary
	expect(
		generated_bark != null
		and live_drop_buttons.has(generated_bark.instance_id),
		"Open TREE did not live-refresh from an equipment loot item_added signal."
	)
	for generated_id in generated_ids:
		inventory.remove_item(generated_id)
	EquipmentLoot.clear_runtime_state_for_testing()
	expect(empty_label.visible, "TREE did not return to empty Bark inventory after fixture cleanup.")

	var bark_a: ItemInstance = create_item(&"test_bark_epic_001", &"living_bark", 12, ItemRarityRules.EPIC, &"maximum_health", 15.0)
	var bark_b: ItemInstance = create_item(&"test_bark_common_002", &"living_bark", 4, ItemRarityRules.COMMON, &"health_regeneration", 0.5)
	var roots_a: ItemInstance = create_item(&"test_roots_uncommon_001", &"deep_roots", 8, ItemRarityRules.UNCOMMON, &"health_regeneration", 1.0)
	bark_a.affix_rolls.append(ItemAffixRoll.new(&"branch_damage", 0.10))
	bark_a.affix_rolls.append(ItemAffixRoll.new(&"attack_speed", 0.15))
	bark_a.affix_rolls.append(ItemAffixRoll.new(&"future_stat", 2.0))
	inventory.add_item(bark_b)
	inventory.add_item(roots_a)
	inventory.add_item(bark_a)
	expect(screen.call("select_equipment_slot", &"bark"), "Bark populated selection failed.")
	var candidate_buttons: Dictionary = screen.get("equipment_candidate_buttons_by_instance_id") as Dictionary
	expect(candidate_buttons.size() == 2 and candidate_buttons.has(bark_a.instance_id) and candidate_buttons.has(bark_b.instance_id) and not candidate_buttons.has(roots_a.instance_id), "Bark inventory filtering or same-definition identity is wrong.")
	var candidate_ids: Array[StringName] = []
	for child in screen.get_node("MainPanel/EquipmentInventoryPanel/ScrollContainer/CandidateList").get_children():
		if child is Button and not child.is_queued_for_deletion():
			for instance_id in candidate_buttons:
				if candidate_buttons[instance_id] == child:
					candidate_ids.append(StringName(instance_id))
	expect(candidate_ids == [bark_a.instance_id, bark_b.instance_id], "Inventory UI sorting is not rarity/Item Level deterministic.")

	expect(screen.call("select_equipment_candidate", bark_a.instance_id), "Bark A candidate selection failed.")
	expect(selected_label.text.contains("Living Bark") and selected_label.text.contains("Epic") and selected_label.text.contains("Item Level 12") and selected_label.text.contains("Maximum Health: +15") and selected_label.text.contains("Branch Damage: +10%") and selected_label.text.contains("Attack Speed: +15%") and selected_label.text.contains("Future Stat: +2"), "Selected Bark A factual detail or affix formatting is incomplete.")
	expect(not selected_label.text.contains("Power") and not selected_label.text.contains("Tier"), "Equipment comparison invented Power or Branch Tier.")
	expect(not equip_button.disabled and (candidate_buttons[bark_a.instance_id] as Button).get_theme_color("font_color") == ItemRarityRules.get_rarity_color(ItemRarityRules.EPIC), "Bark A Equip or rarity color is wrong.")
	expect(screen.call("equip_selected_equipment"), "Bark A UI equip failed.")
	expect(equipment.get_equipped_item(&"bark") == bark_a and bark_button.text == "BARK\nLiving Bark" and current_label.text.contains("Item Level 12") and equip_button.disabled and equip_button.text == "EQUIPPED" and not unequip_button.disabled, "Bark A equipped UI did not live-refresh.")

	expect(screen.call("select_equipment_candidate", bark_b.instance_id), "Bark B candidate selection failed.")
	expect(current_label.text.contains("Epic") and selected_label.text.contains("Common") and selected_label.text.contains("Item Level 4") and selected_label.text.contains("Health Regeneration: +0.5/s"), "Side-by-side factual replacement comparison is wrong.")
	expect(screen.call("equip_selected_equipment"), "Bark replacement UI equip failed.")
	expect(equipment.get_equipped_item(&"bark") == bark_b and inventory.get_item(bark_a.instance_id) == bark_a and inventory.get_item(bark_b.instance_id) == bark_b, "Replacement removed or copied an inventory item.")
	candidate_buttons = screen.get("equipment_candidate_buttons_by_instance_id") as Dictionary
	expect(not (candidate_buttons[bark_a.instance_id] as Button).text.contains("EQUIPPED") and (candidate_buttons[bark_b.instance_id] as Button).text.contains("EQUIPPED"), "Replacement EQUIPPED markers are stale.")
	expect(screen.call("unequip_selected_equipment"), "Bark UI unequip failed.")
	expect(equipment.get_equipped_instance_id(&"bark") == &"" and inventory.has_item(bark_b.instance_id) and bark_button.text == "BARK\nEMPTY" and not equip_button.disabled and unequip_button.disabled, "Bark unequip UI or inventory preservation is wrong.")

	expect(screen.call("select_equipment_slot", &"roots"), "Roots populated selection failed.")
	candidate_buttons = screen.get("equipment_candidate_buttons_by_instance_id") as Dictionary
	expect(candidate_buttons.size() == 1 and candidate_buttons.has(roots_a.instance_id) and not candidate_buttons.has(bark_a.instance_id), "Roots inventory filter leaked Bark items.")
	expect(screen.call("select_equipment_candidate", roots_a.instance_id) and screen.call("equip_selected_equipment"), "Roots UI equip failed.")
	expect(equipment.get_equipped_item(&"roots") == roots_a and roots_button.text == "ROOTS\nDeep Roots" and equipment.get_equipped_instance_id(&"bark") == &"", "Roots equip changed Bark or failed to refresh.")

	screen.call("select_slot", &"standard_slot_1")
	expect(detail_panel.visible and seed_panel.visible and not equipment_detail.visible and not inventory_panel.visible, "Branch mode did not restore original panels.")
	expect(screen.call("open_branch_picker"), "Branch picker no longer opens after Equipment mode.")
	screen.call("select_equipment_slot", &"bark")
	expect(not (screen.get_node("BranchPicker") as Panel).visible, "Equipment mode left BranchPicker open.")
	screen.call("select_slot", &"apex_slot")
	expect(screen.get("selection_mode") == 0 and detail_panel.visible, "Apex did not restore Branch mode.")

	expect(manager.continue_from_preparation(), "Could not leave Preparation for live equipment test.")
	var live_wave: int = director.current_wave
	var health_ratio_before: float = float(tree_node.get("current_health")) / float(tree_node.get("max_health"))
	var maximum_health_before: float = float(tree_node.get("max_health"))
	screen.call("select_equipment_slot", &"bark")
	screen.call("select_equipment_candidate", bark_a.instance_id)
	expect(screen.call("equip_selected_equipment"), "Live Wave Bark equip failed.")
	expect(director.current_wave == live_wave and not get_tree().paused and is_equal_approx(float(tree_node.get("max_health")), maximum_health_before + 15.0) and is_equal_approx(float(tree_node.get("current_health")) / float(tree_node.get("max_health")), health_ratio_before), "Live equip paused/reset the Wave or failed ratio-preserving Maximum Health refresh.")
	expect(screen.call("unequip_selected_equipment") and director.current_wave == live_wave and not get_tree().paused and is_equal_approx(float(tree_node.get("max_health")), maximum_health_before) and is_equal_approx(float(tree_node.get("current_health")) / float(tree_node.get("max_health")), health_ratio_before), "Live unequip paused/reset the Wave or changed the Tree health ratio.")

	manager.set("tree_defeated", true)
	screen.call("select_equipment_candidate", bark_a.instance_id)
	expect(equip_button.disabled and unequip_button.disabled and status_label.text.contains("Tree is defeated."), "Defeated TREE equipment controls are not disabled.")
	expect(not screen.call("equip_selected_equipment") and not screen.call("unequip_selected_equipment"), "Defeated TREE mutated equipment.")
	manager.set("tree_defeated", false)
	inventory.remove_item(bark_a.instance_id)
	expect(screen.get("selected_equipment_instance_id") == &"" and equip_button.disabled, "Removed selected item left stale UI selection.")

	director.cancel_cycle(true)
	manager.remove_remaining_enemies()
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
