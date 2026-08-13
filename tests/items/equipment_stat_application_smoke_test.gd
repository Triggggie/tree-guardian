extends Node


const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")
const THORN_SCENE: PackedScene = preload("res://scenes/branches/thorn_crown_branch.tscn")
const EXTERNAL_SOURCE_ID: StringName = &"equipment_stat_test_external"


var failures: Array[String] = []


func _ready() -> void:
	var inventory := get_node("/root/Inventory") as InventoryService
	var equipment := get_node("/root/Equipment") as EquipmentService
	var equipment_stats := get_node("/root/EquipmentStats") as EquipmentStatService
	equipment.clear_runtime_state_for_testing()
	inventory.clear_runtime_state_for_testing()
	RunModifiers.clear_source(EXTERNAL_SOURCE_ID)
	equipment_stats.rebuild_from_equipment()
	await run_test(inventory, equipment, equipment_stats)
	equipment.clear_runtime_state_for_testing()
	inventory.clear_runtime_state_for_testing()
	RunModifiers.clear_source(EXTERNAL_SOURCE_ID)
	equipment_stats.rebuild_from_equipment()

	if failures.is_empty():
		print("EQUIPMENT STAT APPLICATION SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("EQUIPMENT STAT APPLICATION SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func run_test(
	inventory: InventoryService,
	equipment: EquipmentService,
	equipment_stats: EquipmentStatService
) -> void:
	test_fresh_state(inventory, equipment, equipment_stats)

	var roots_a: ItemInstance = create_item(
		&"equipment_stats_roots_a",
		&"deep_roots",
		10,
		ItemRarityRules.EPIC,
		true,
		[
			ItemAffixRoll.new(&"maximum_health", 20.0),
			ItemAffixRoll.new(&"health_regeneration", 1.5),
			ItemAffixRoll.new(&"branch_damage", 0.05),
			ItemAffixRoll.new(&"branch_damage", 0.05),
			ItemAffixRoll.new(&"future_stat", 999.0)
		]
	)
	var roots_b: ItemInstance = create_item(
		&"equipment_stats_roots_b",
		&"deep_roots",
		99,
		ItemRarityRules.LEGENDARY,
		false,
		[
			ItemAffixRoll.new(&"maximum_health", 40.0),
			ItemAffixRoll.new(&"health_regeneration", 0.5)
		]
	)
	var bark: ItemInstance = create_item(
		&"equipment_stats_bark",
		&"living_bark",
		25,
		ItemRarityRules.COMMON,
		false,
		[
			ItemAffixRoll.new(&"branch_damage", 0.10),
			ItemAffixRoll.new(&"attack_speed", 0.25)
		]
	)
	for item in [roots_a, roots_b, bark]:
		expect(inventory.add_item(item), "Equipment stat fixture could not enter Inventory.")

	var world: Node = MAIN_WORLD_SCENE.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var tree_node: Node = world.get_node("Entities/Tree")
	var controller := world.get_node(
		"Entities/Tree/Systems/TreeBranchLoadoutController"
	) as TreeBranchLoadoutController
	var strength: CombatBranch = controller.get_runtime_branch(&"standard_slot_1")
	var blossom: CombatBranch = controller.get_runtime_branch(&"standard_slot_2")
	var thorn: CombatBranch = THORN_SCENE.instantiate() as CombatBranch
	thorn.slot_index = BranchSlotRules.APEX_SLOT
	thorn.process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(thorn)
	await get_tree().process_frame

	var base_maximum_health: float = float(tree_node.get("max_health"))
	var base_strength_damage: float = float(strength.call("get_current_damage"))
	var base_blossom_damage: float = float(blossom.call("get_current_petal_damage"))
	var base_thorn_damage: float = float(thorn.call("get_current_damage"))
	var base_strength_cooldown: float = float(strength.call("get_current_attack_cooldown"))
	var base_blossom_interval: float = float(blossom.call("get_current_ranged_attack_interval"))
	var base_thorn_cooldown: float = float(thorn.call("get_current_attack_cooldown"))
	var base_healing_interval: float = float(blossom.call("get_current_healing_tick_interval"))

	expect(equipment.equip_item(roots_a.instance_id), "Roots A equip failed.")
	expect(
		is_equal_approx(equipment_stats.get_total_affix_value(&"maximum_health"), 20.0)
		and is_equal_approx(equipment_stats.get_total_affix_value(&"health_regeneration"), 1.5)
		and is_equal_approx(equipment_stats.get_total_affix_value(&"branch_damage"), 0.10)
		and is_zero_approx(equipment_stats.get_total_affix_value(&"future_stat")),
		"Roots aggregation, duplicate aggregation, or unknown-affix ignore is wrong."
	)
	expect(
		is_equal_approx(float(tree_node.get("max_health")), base_maximum_health + 20.0)
		and is_equal_approx(float(tree_node.get("current_health")), base_maximum_health + 20.0),
		"Flat Maximum Health did not apply at full health."
	)
	expect_damage_multiplier(strength, blossom, thorn, base_strength_damage, base_blossom_damage, base_thorn_damage, 1.10, "Roots duplicate damage")

	var damaged_ratio: float = 0.373
	tree_node.set("current_health", float(tree_node.get("max_health")) * damaged_ratio)
	expect(equipment.equip_item(bark.instance_id), "Bark equip failed.")
	expect(
		is_equal_approx(equipment_stats.get_total_affix_value(&"branch_damage"), 0.20)
		and is_equal_approx(equipment_stats.get_total_affix_value(&"attack_speed"), 0.25),
		"Bark + Roots percentage stacking is wrong."
	)
	expect(
		is_equal_approx(
			float(tree_node.get("current_health")) / float(tree_node.get("max_health")),
			damaged_ratio
		),
		"An unrelated equipment stat changed the damaged Tree health ratio."
	)
	expect_damage_multiplier(strength, blossom, thorn, base_strength_damage, base_blossom_damage, base_thorn_damage, 1.20, "Bark + Roots damage")
	expect(
		is_equal_approx(float(strength.call("get_current_attack_cooldown")), base_strength_cooldown / 1.25)
		and is_equal_approx(float(blossom.call("get_current_ranged_attack_interval")), base_blossom_interval / 1.25)
		and is_equal_approx(float(thorn.call("get_current_attack_cooldown")), base_thorn_cooldown / 1.25),
		"Equipment Attack Speed did not use the shared offensive cooldown pipeline."
	)
	expect(
		is_equal_approx((strength.get_node("CooldownTimer") as Timer).wait_time, base_strength_cooldown / 1.25)
		and is_equal_approx((thorn.get_node("CooldownTimer") as Timer).wait_time, base_thorn_cooldown / 1.25),
		"Timer-backed Branch wait_time did not refresh live."
	)
	expect(
		is_equal_approx(float(blossom.call("get_current_healing_tick_interval")), base_healing_interval),
		"Equipment Attack Speed changed Blossom healing timing."
	)

	RunModifiers.set_multiplier_modifier(
		RunModifierIds.BRANCH_DAMAGE,
		EXTERNAL_SOURCE_ID,
		1.20
	)
	RunModifiers.set_additive_modifier(
		RunModifierIds.TREE_REGEN_RATE,
		EXTERNAL_SOURCE_ID,
		0.01
	)
	expect_damage_multiplier(strength, blossom, thorn, base_strength_damage, base_blossom_damage, base_thorn_damage, 1.44, "External source composition")
	var tree_upgrade_flat_regen: float = float(tree_node.get("health_regeneration_per_upgrade"))
	tree_node.set("health_regeneration_upgrade_level", 1)
	var expected_regeneration: float = (
		tree_upgrade_flat_regen
		+ 1.5
		+ float(tree_node.get("max_health")) * 0.01
	)
	expect(
		is_equal_approx(float(tree_node.call("get_current_health_regeneration")), expected_regeneration),
		"Tree upgrade, flat equipment regen, and percentage regen did not compose."
	)
	tree_node.set("current_health", float(tree_node.get("max_health")) - 10.0)
	var health_before_regen: float = float(tree_node.get("current_health"))
	tree_node.call("process_health_regeneration", 1.0)
	expect(
		is_equal_approx(float(tree_node.get("current_health")), health_before_regen + expected_regeneration),
		"Equipment regeneration did not perform actual healing."
	)

	var ratio_before_replacement: float = (
		float(tree_node.get("current_health")) / float(tree_node.get("max_health"))
	)
	expect(equipment.equip_item(roots_b.instance_id), "Roots replacement failed.")
	expect(
		is_equal_approx(float(tree_node.get("max_health")), base_maximum_health + 40.0)
		and is_equal_approx(
			float(tree_node.get("current_health")) / float(tree_node.get("max_health")),
			ratio_before_replacement
		),
		"Replacement did not preserve health ratio or replace flat HP exactly."
	)
	expect(
		is_equal_approx(equipment_stats.get_total_affix_value(&"health_regeneration"), 0.5)
		and is_equal_approx(equipment_stats.get_total_affix_value(&"branch_damage"), 0.10),
		"Replacement retained old Roots affixes."
	)

	for rebuild_index in range(3):
		equipment_stats.rebuild_from_equipment()
	expect(
		is_equal_approx(equipment_stats.get_total_affix_value(&"maximum_health"), 40.0)
		and is_equal_approx(RunModifiers.apply_modifier(10.0, RunModifierIds.BRANCH_DAMAGE), 13.2),
		"Repeated EquipmentStats rebuild multiplied or lost modifiers."
	)
	expect(
		is_equal_approx(
			RunModifiers.get_total_multiplier(RunModifierIds.BRANCH_DAMAGE),
			1.32
		),
		"External modifier source did not survive Equipment rebuild."
	)

	expect(inventory.remove_item(bark.instance_id), "Equipped Bark removal failed.")
	expect(
		equipment.get_equipped_instance_id(&"bark") == &""
		and is_zero_approx(equipment_stats.get_total_affix_value(&"branch_damage"))
		and is_equal_approx(RunModifiers.apply_modifier(10.0, RunModifierIds.BRANCH_DAMAGE), 12.0),
		"Remove-equipped did not remove Equipment stats or preserve external source."
	)

	var ratio_before_unequip: float = (
		float(tree_node.get("current_health")) / float(tree_node.get("max_health"))
	)
	expect(equipment.unequip_slot(&"roots"), "Roots unequip failed.")
	expect(
		is_equal_approx(float(tree_node.get("max_health")), base_maximum_health)
		and is_equal_approx(
			float(tree_node.get("current_health")) / float(tree_node.get("max_health")),
			ratio_before_unequip
		),
		"Unequip did not restore Maximum Health without a heal exploit."
	)

	tree_node.set("is_dead", true)
	tree_node.set("current_health", 0.0)
	expect(equipment.equip_item(roots_a.instance_id), "Dead-tree Roots equip setup failed.")
	expect(
		bool(tree_node.get("is_dead"))
		and is_zero_approx(float(tree_node.get("current_health")))
		and is_equal_approx(float(tree_node.get("max_health")), base_maximum_health + 20.0),
		"Equipment Maximum Health revived a dead Tree."
	)

	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	var recreated_world: Node = MAIN_WORLD_SCENE.instantiate()
	recreated_world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(recreated_world)
	await get_tree().process_frame
	var recreated_tree: Node = recreated_world.get_node("Entities/Tree")
	expect(
		is_equal_approx(float(recreated_tree.get("max_health")), base_maximum_health + 20.0)
		and equipment.get_equipped_item(&"roots") == roots_a,
		"Equipped stats did not survive MainWorld recreation."
	)
	recreated_world.queue_free()
	await get_tree().process_frame


func test_fresh_state(
	inventory: InventoryService,
	equipment: EquipmentService,
	equipment_stats: EquipmentStatService
) -> void:
	expect(
		inventory.get_item_count() == 0
		and equipment.get_equipped_instance_id(&"bark") == &""
		and equipment.get_equipped_instance_id(&"roots") == &"",
		"Production Inventory or Equipment did not start EMPTY."
	)
	for stat_id in EquipmentStatRules.get_supported_stat_ids():
		expect(
			is_zero_approx(equipment_stats.get_total_affix_value(stat_id)),
			"Fresh EquipmentStats contains %s." % stat_id
		)
	expect(
		is_equal_approx(RunModifiers.apply_modifier(10.0, RunModifierIds.BRANCH_DAMAGE), 10.0)
		and is_equal_approx(RunModifiers.apply_modifier(2.0, RunModifierIds.ATTACK_SPEED), 2.0),
		"Fresh EquipmentStats changed gameplay modifiers."
	)


func expect_damage_multiplier(
	strength: CombatBranch,
	blossom: CombatBranch,
	thorn: CombatBranch,
	base_strength_damage: float,
	base_blossom_damage: float,
	base_thorn_damage: float,
	multiplier: float,
	context: String
) -> void:
	expect(
		is_equal_approx(float(strength.call("get_current_damage")), base_strength_damage * multiplier)
		and is_equal_approx(float(blossom.call("get_current_petal_damage")), base_blossom_damage * multiplier)
		and is_equal_approx(float(thorn.call("get_current_damage")), base_thorn_damage * multiplier),
		"%s did not affect Strength, Blossom, and Thorn Crown." % context
	)


func create_item(
	instance_id: StringName,
	definition_id: StringName,
	item_level: int,
	rarity_id: StringName,
	is_locked: bool,
	affixes: Array[ItemAffixRoll]
) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.definition_id = definition_id
	item.item_level = item_level
	item.rarity_id = rarity_id
	item.is_locked = is_locked
	item.affix_rolls.assign(affixes)
	return item


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
