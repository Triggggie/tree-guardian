extends Node


const BARK_BEETLE: EnemyDefinition = preload(
	"res://resources/enemies/bark_beetle_definition.tres"
)


var failures: Array[String] = []


func _ready() -> void:
	test_item_levels()
	test_rarity_rules()
	test_affix_rules()
	test_value_formulas()
	test_generator()

	if failures.is_empty():
		print("EQUIPMENT LOOT RULES SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("EQUIPMENT LOOT RULES SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func test_item_levels() -> void:
	expect(
		EquipmentLootRules.get_item_level(1) == 1
		and EquipmentLootRules.get_item_level(10) == 1
		and EquipmentLootRules.get_item_level(11) == 2
		and EquipmentLootRules.get_item_level(50, 2) == 7
		and EquipmentLootRules.get_item_level(100, 4) == 14,
		"Equipment Item Level formula is wrong."
	)


func test_rarity_rules() -> void:
	expect(
		is_equal_approx(EquipmentLootRules.get_rarity_weight(ItemRarityRules.COMMON), 78.0)
		and is_equal_approx(EquipmentLootRules.get_rarity_weight(ItemRarityRules.UNCOMMON), 20.0)
		and is_equal_approx(EquipmentLootRules.get_rarity_weight(ItemRarityRules.EPIC), 2.0)
		and is_zero_approx(EquipmentLootRules.get_rarity_weight(ItemRarityRules.LEGENDARY)),
		"Equipment rarity weights are wrong."
	)
	expect(
		is_equal_approx(EquipmentLootRules.get_rarity_value_multiplier(ItemRarityRules.COMMON), 1.0)
		and is_equal_approx(EquipmentLootRules.get_rarity_value_multiplier(ItemRarityRules.UNCOMMON), 1.25)
		and is_equal_approx(EquipmentLootRules.get_rarity_value_multiplier(ItemRarityRules.EPIC), 1.5),
		"Equipment rarity value multipliers are wrong."
	)
	var rng := RandomNumberGenerator.new()
	for seed_value in range(1, 50):
		rng.seed = seed_value
		var uncommon_or_better: StringName = EquipmentLootRules.roll_rarity(
			ItemRarityRules.UNCOMMON,
			rng
		)
		expect(
			uncommon_or_better in [ItemRarityRules.UNCOMMON, ItemRarityRules.EPIC],
			"Minimum Uncommon generated a lower or unsupported rarity."
		)
		rng.seed = seed_value
		expect(
			EquipmentLootRules.roll_rarity(ItemRarityRules.EPIC, rng) == ItemRarityRules.EPIC,
			"Minimum Epic did not deterministically generate Epic."
		)
	rng.seed = 1
	expect(
		EquipmentLootRules.roll_rarity(ItemRarityRules.LEGENDARY, rng) == &""
		and ItemRarityRules.is_valid_rarity_id(ItemRarityRules.LEGENDARY),
		"Loot V1 generated Legendary or invalidated the future rarity."
	)


func test_affix_rules() -> void:
	expect(
		EquipmentLootRules.get_affix_count(ItemRarityRules.COMMON) == 1
		and EquipmentLootRules.get_affix_count(ItemRarityRules.UNCOMMON) == 2
		and EquipmentLootRules.get_affix_count(ItemRarityRules.EPIC) == 2
		and EquipmentLootRules.get_affix_count(ItemRarityRules.LEGENDARY) == 0,
		"Equipment affix counts are wrong."
	)
	expect(
		EquipmentLootRules.get_affix_pool_for_slot(&"roots") == [
			EquipmentStatRules.MAXIMUM_HEALTH,
			EquipmentStatRules.HEALTH_REGENERATION
		]
		and EquipmentLootRules.get_affix_pool_for_slot(&"bark") == [
			EquipmentStatRules.BRANCH_DAMAGE,
			EquipmentStatRules.ATTACK_SPEED
		],
		"Bark or Roots affix pool is wrong."
	)


func test_value_formulas() -> void:
	var stat_ids: Array[StringName] = EquipmentStatRules.get_supported_stat_ids()
	for stat_id in stat_ids:
		var low_value: float = EquipmentLootRules.calculate_affix_value(
			stat_id, 1, ItemRarityRules.COMMON, 1.0
		)
		var high_value: float = EquipmentLootRules.calculate_affix_value(
			stat_id, 10, ItemRarityRules.COMMON, 1.0
		)
		var uncommon_value: float = EquipmentLootRules.calculate_affix_value(
			stat_id, 10, ItemRarityRules.UNCOMMON, 1.0
		)
		var epic_value: float = EquipmentLootRules.calculate_affix_value(
			stat_id, 10, ItemRarityRules.EPIC, 1.0
		)
		expect(
			low_value > 0.0 and high_value > low_value,
			"Item Level did not increase %s." % stat_id
		)
		expect(
			epic_value > uncommon_value and uncommon_value > high_value,
			"Rarity did not increase generated %s." % stat_id
		)
	expect(
		is_equal_approx(EquipmentLootRules.calculate_affix_value(&"maximum_health", 7, ItemRarityRules.UNCOMMON, 1.0), 28.0)
		and absf(fmod(EquipmentLootRules.calculate_affix_value(&"health_regeneration", 7, ItemRarityRules.UNCOMMON, 1.0), 0.05)) < 0.0001
		and absf(fmod(EquipmentLootRules.calculate_affix_value(&"branch_damage", 7, ItemRarityRules.UNCOMMON, 1.0), 0.005)) < 0.0001,
		"Equipment value rounding is wrong."
	)


func test_generator() -> void:
	var generator := EquipmentItemGenerator.new()
	var enemy: EnemyDefinition = BARK_BEETLE.duplicate(true)
	enemy.equipment_minimum_rarity_id = ItemRarityRules.UNCOMMON
	var rng := RandomNumberGenerator.new()
	var found_slots: Dictionary = {}
	for item_index in range(100):
		rng.seed = item_index + 10
		var item: ItemInstance = generator.generate_item(
			StringName("generator_test_%03d" % item_index),
			enemy,
			50,
			rng
		)
		expect(item != null and item.is_valid_data(), "Generator returned an invalid item.")
		if item == null:
			continue
		var definition: ItemDefinition = GameContent.get_item(item.definition_id)
		expect(is_instance_valid(definition), "Generated item definition is unknown.")
		if not is_instance_valid(definition):
			continue
		found_slots[definition.equipment_slot_id] = true
		var expected_pool: Array[StringName] = EquipmentLootRules.get_affix_pool_for_slot(
			definition.equipment_slot_id
		)
		var rolled_ids: Array[StringName] = []
		for affix in item.affix_rolls:
			rolled_ids.append(affix.stat_id)
			expect(affix.stat_id in expected_pool and affix.value > 0.0, "Generator rolled an invalid affix.")
		expect(rolled_ids.size() == 2 and rolled_ids[0] != rolled_ids[1], "Generator did not produce two distinct affixes.")
		expect(item.item_level == 5 and item.rarity_id in [ItemRarityRules.UNCOMMON, ItemRarityRules.EPIC] and not item.is_locked, "Generated item metadata is wrong.")
	expect(found_slots.has(&"bark") and found_slots.has(&"roots"), "Seeded generator coverage missed Bark or Roots.")


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
