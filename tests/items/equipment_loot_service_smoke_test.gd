extends Node


class MockTree:
	extends Node2D
	func calculate_forest_essence_reward(base_reward: int) -> int:
		return base_reward


class MockKiller:
	extends Node
	var received_xp: int = 0
	func add_xp(amount: int) -> void:
		received_xp += amount


const BARK_BEETLE: EnemyDefinition = preload(
	"res://resources/enemies/bark_beetle_definition.tres"
)
const BARK_RUNNER: EnemyDefinition = preload(
	"res://resources/enemies/bark_runner_definition.tres"
)
const BARK_WARDEN: EnemyDefinition = preload(
	"res://resources/enemies/bark_warden_definition.tres"
)
const COLOSSUS: EnemyDefinition = preload(
	"res://resources/enemies/ancient_bark_colossus_definition.tres"
)
const STAGE: StageDefinition = preload(
	"res://resources/stages/guardian_grove_stage.tres"
)


var failures: Array[String] = []
var drop_events: Array[Array] = []


func _ready() -> void:
	var inventory := get_node("/root/Inventory") as InventoryService
	var equipment := get_node("/root/Equipment") as EquipmentService
	var service := get_node("/root/EquipmentLoot") as EquipmentLootService
	_reset_state(inventory, equipment, service)
	service.equipment_item_dropped.connect(_on_equipment_item_dropped)
	test_production_data()
	test_no_drop_and_forced_drop(inventory, equipment, service)
	test_boss_guarantees(inventory, service)
	test_failed_insertion(inventory, service)
	test_unique_ids(inventory, service)
	test_generated_item_application(inventory, equipment, service)
	await test_enemy_death_integration(inventory, service)
	_reset_state(inventory, equipment, service)

	if failures.is_empty():
		print("EQUIPMENT LOOT SERVICE SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("EQUIPMENT LOOT SERVICE SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func test_production_data() -> void:
	expect(
		is_equal_approx(BARK_BEETLE.equipment_drop_chance, 0.01)
		and is_equal_approx(BARK_RUNNER.equipment_drop_chance, 0.01)
		and not BARK_BEETLE.equipment_guaranteed_once_per_wave
		and not BARK_RUNNER.equipment_guaranteed_once_per_wave
		and BARK_BEETLE.equipment_minimum_rarity_id == ItemRarityRules.COMMON
		and BARK_RUNNER.equipment_minimum_rarity_id == ItemRarityRules.COMMON,
		"Production normal-enemy equipment reward data is wrong."
	)
	expect(
		BARK_WARDEN.equipment_guaranteed_once_per_wave
		and is_zero_approx(BARK_WARDEN.equipment_drop_chance)
		and BARK_WARDEN.equipment_minimum_rarity_id == ItemRarityRules.UNCOMMON
		and BARK_WARDEN.equipment_item_level_bonus == 2,
		"Bark Warden equipment reward data is wrong."
	)
	expect(
		COLOSSUS.equipment_guaranteed_once_per_wave
		and is_zero_approx(COLOSSUS.equipment_drop_chance)
		and COLOSSUS.equipment_minimum_rarity_id == ItemRarityRules.EPIC
		and COLOSSUS.equipment_item_level_bonus == 4,
		"Ancient Bark Colossus equipment reward data is wrong."
	)


func test_no_drop_and_forced_drop(
	inventory: InventoryService,
	equipment: EquipmentService,
	service: EquipmentLootService
) -> void:
	var no_drop: EnemyDefinition = BARK_BEETLE.duplicate(true)
	no_drop.equipment_drop_chance = 0.0
	no_drop.equipment_guaranteed_once_per_wave = false
	var count_before: int = inventory.get_item_count()
	var events_before: int = drop_events.size()
	expect(
		service.process_enemy_defeat(no_drop, STAGE, 1, Vector2.ZERO) == null
		and inventory.get_item_count() == count_before
		and drop_events.size() == events_before,
		"Zero-chance normal enemy granted equipment."
	)

	var forced: EnemyDefinition = BARK_BEETLE.duplicate(true)
	forced.equipment_drop_chance = 1.0
	service.set_random_seed_for_testing(17)
	var item: ItemInstance = service.process_enemy_defeat(
		forced, STAGE, 11, Vector2(12.0, 34.0)
	)
	expect(
		item != null
		and inventory.get_item(item.instance_id) == item
		and item.item_level == 2
		and drop_events.size() == events_before + 1,
		"Forced normal equipment drop failed."
	)
	expect(
		equipment.get_equipped_instance_id(&"bark") == &""
		and equipment.get_equipped_instance_id(&"roots") == &"",
		"Equipment loot auto-equipped an item."
	)


func test_boss_guarantees(
	inventory: InventoryService,
	service: EquipmentLootService
) -> void:
	var count_before: int = inventory.get_item_count()
	service.set_random_seed_for_testing(23)
	var first_warden: ItemInstance = service.process_enemy_defeat(
		BARK_WARDEN, STAGE, 50, Vector2.LEFT
	)
	var second_warden: ItemInstance = service.process_enemy_defeat(
		BARK_WARDEN, STAGE, 50, Vector2.RIGHT
	)
	expect(
		first_warden != null
		and first_warden.item_level == 7
		and ItemRarityRules.get_rarity_rank(first_warden.rarity_id) >= ItemRarityRules.get_rarity_rank(ItemRarityRules.UNCOMMON)
		and second_warden == null
		and inventory.get_item_count() == count_before + 1,
		"Wave 50 left/right encounter guarantee is wrong."
	)
	expect(
		service.process_enemy_defeat(BARK_WARDEN, STAGE, 50, Vector2.ZERO) == null,
		"Retry duplicated the claimed Wave 50 guarantee."
	)
	var later_warden: ItemInstance = service.process_enemy_defeat(
		BARK_WARDEN, STAGE, 150, Vector2.ZERO
	)
	expect(
		later_warden != null and later_warden.item_level == 17,
		"A different global Wave did not receive a new guarantee."
	)

	count_before = inventory.get_item_count()
	var first_colossus: ItemInstance = service.process_enemy_defeat(
		COLOSSUS, STAGE, 100, Vector2.LEFT
	)
	var second_colossus: ItemInstance = service.process_enemy_defeat(
		COLOSSUS, STAGE, 100, Vector2.RIGHT
	)
	expect(
		first_colossus != null
		and first_colossus.item_level == 14
		and first_colossus.rarity_id == ItemRarityRules.EPIC
		and second_colossus == null
		and inventory.get_item_count() == count_before + 1,
		"Wave 100 Epic encounter guarantee is wrong."
	)


func test_failed_insertion(
	inventory: InventoryService,
	service: EquipmentLootService
) -> void:
	var test_wave: int = 250
	var count_before: int = inventory.get_item_count()
	service.set_inventory_add_override_for_testing(_reject_inventory_item)
	expect(
		service.process_enemy_defeat(BARK_WARDEN, STAGE, test_wave, Vector2.ZERO) == null
		and not service.is_guarantee_claimed_for_testing(STAGE.stage_id, test_wave, BARK_WARDEN.enemy_id)
		and inventory.get_item_count() == count_before,
		"Failed Inventory insertion claimed or stored a guaranteed reward."
	)
	service.set_inventory_add_override_for_testing(Callable())
	var retry_item: ItemInstance = service.process_enemy_defeat(
		BARK_WARDEN, STAGE, test_wave, Vector2.ZERO
	)
	expect(
		retry_item != null
		and service.is_guarantee_claimed_for_testing(STAGE.stage_id, test_wave, BARK_WARDEN.enemy_id),
		"Guarantee was unavailable after a failed Inventory insertion."
	)


func test_unique_ids(
	inventory: InventoryService,
	service: EquipmentLootService
) -> void:
	var forced: EnemyDefinition = BARK_BEETLE.duplicate(true)
	forced.equipment_drop_chance = 1.0
	var existing_ids: Dictionary = {}
	var count_before: int = inventory.get_item_count()
	for item_index in range(100):
		var item: ItemInstance = service.process_enemy_defeat(
			forced, STAGE, item_index + 1, Vector2.ZERO
		)
		expect(item != null and not existing_ids.has(item.instance_id), "Generated instance ID collided.")
		if item != null:
			existing_ids[item.instance_id] = true
	expect(
		existing_ids.size() == 100
		and inventory.get_item_count() == count_before + 100,
		"Inventory did not retain 100 unique generated items."
	)


func test_generated_item_application(
	inventory: InventoryService,
	equipment: EquipmentService,
	service: EquipmentLootService
) -> void:
	var forced: EnemyDefinition = BARK_BEETLE.duplicate(true)
	forced.equipment_drop_chance = 1.0
	forced.equipment_minimum_rarity_id = ItemRarityRules.UNCOMMON
	var bark_item: ItemInstance
	var roots_item: ItemInstance
	for item_index in range(20):
		var item: ItemInstance = service.process_enemy_defeat(
			forced, STAGE, 40, Vector2.ZERO
		)
		if item == null:
			continue
		var definition: ItemDefinition = GameContent.get_item(item.definition_id)
		if definition.equipment_slot_id == EquipmentSlotRules.BARK_SLOT_ID:
			bark_item = item
		elif definition.equipment_slot_id == EquipmentSlotRules.ROOTS_SLOT_ID:
			roots_item = item
		if bark_item != null and roots_item != null:
			break
	expect(bark_item != null and roots_item != null, "Could not generate both production slots.")
	if bark_item == null or roots_item == null:
		return
	expect(
		equipment.equip_item(bark_item.instance_id)
		and equipment.equip_item(roots_item.instance_id),
		"Generated items could not be equipped."
	)
	expect(
		EquipmentStats.get_total_affix_value(EquipmentStatRules.MAXIMUM_HEALTH) > 0.0
		and EquipmentStats.get_total_affix_value(EquipmentStatRules.HEALTH_REGENERATION) > 0.0
		and EquipmentStats.get_total_affix_value(EquipmentStatRules.BRANCH_DAMAGE) > 0.0
		and EquipmentStats.get_total_affix_value(EquipmentStatRules.ATTACK_SPEED) > 0.0
		and RunModifiers.apply_modifier(100.0, RunModifierIds.TREE_MAX_HEALTH) > 100.0
		and RunModifiers.apply_modifier(10.0, RunModifierIds.BRANCH_DAMAGE) > 10.0,
		"Generated affixes did not enter the EquipmentStats gameplay pipeline."
	)
	equipment.clear_runtime_state_for_testing()
	EquipmentStats.rebuild_from_equipment()


func test_enemy_death_integration(
	inventory: InventoryService,
	service: EquipmentLootService
) -> void:
	var fixture := Node2D.new()
	add_child(fixture)
	var tree_node := MockTree.new()
	fixture.add_child(tree_node)
	tree_node.add_to_group("tree")
	var tracker := EnemyTracker.new()
	fixture.add_child(tracker)
	var lane_registry := LaneRegistry.new()
	fixture.add_child(lane_registry)

	var forced: EnemyDefinition = BARK_BEETLE.duplicate(true)
	forced.enemy_id = &"forced_equipment_reward_enemy"
	forced.equipment_drop_chance = 1.0
	var enemy: Node = forced.enemy_scene.instantiate()
	expect(bool(enemy.call("configure_from_definition", forced)), "Reward enemy rejected its definition.")
	expect(bool(enemy.call("configure_stage_context", STAGE, 31)), "Reward enemy rejected Wave context.")
	fixture.add_child(enemy)
	await get_tree().process_frame
	var killer := MockKiller.new()
	fixture.add_child(killer)
	var count_before: int = inventory.get_item_count()
	var events_before: int = drop_events.size()
	enemy.call("die", killer)
	expect(
		inventory.get_item_count() == count_before + 1
		and drop_events.size() == events_before + 1
		and int(enemy.get("reward_global_wave")) == 31
		and bool(enemy.get("is_dying"))
		and killer.received_xp == forced.experience_reward,
		"Production enemy death path did not preserve XP and grant equipment."
	)
	fixture.queue_free()
	await get_tree().process_frame
	service.clear_runtime_state_for_testing()


func _reject_inventory_item(_item: ItemInstance) -> bool:
	return false


func _on_equipment_item_dropped(
	instance_id: StringName,
	enemy_id: StringName,
	world_position: Vector2
) -> void:
	drop_events.append([instance_id, enemy_id, world_position])


func _reset_state(
	inventory: InventoryService,
	equipment: EquipmentService,
	service: EquipmentLootService
) -> void:
	equipment.clear_runtime_state_for_testing()
	inventory.clear_runtime_state_for_testing()
	EquipmentStats.rebuild_from_equipment()
	service.clear_runtime_state_for_testing()
	drop_events.clear()


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
