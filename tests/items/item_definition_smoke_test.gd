extends Node


var failures: Array[String] = []


func _ready() -> void:
	test_equipment_slot_rules()
	test_item_rarity_rules()
	test_production_definitions()
	test_invalid_definitions()
	test_branch_tier_separation()

	if failures.is_empty():
		print("ITEM DEFINITION SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print("ITEM DEFINITION SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func test_equipment_slot_rules() -> void:
	var slot_ids: Array[StringName] = EquipmentSlotRules.get_supported_slot_ids()
	expect(slot_ids == [&"bark", &"roots"], "Supported equipment slots are not Bark and Roots only.")
	expect(EquipmentSlotRules.get_slot_display_name(&"bark") == "Bark", "Bark display name is invalid.")
	expect(EquipmentSlotRules.get_slot_display_name(&"roots") == "Roots", "Roots display name is invalid.")
	expect(not EquipmentSlotRules.is_valid_slot_id(&"canopy"), "Canopy is active in Foundation V1.")
	expect(EquipmentSlotRules.get_slot_display_name(&"missing") == "", "Unknown slot has a display name.")


func test_item_rarity_rules() -> void:
	var rarity_ids: Array[StringName] = ItemRarityRules.get_supported_rarity_ids()
	var expected_names: Array[String] = ["Common", "Uncommon", "Epic", "Legendary"]
	var colors: Array[Color] = []
	expect(rarity_ids == [&"common", &"uncommon", &"epic", &"legendary"], "Equipment rarity IDs are invalid.")
	expect(rarity_ids.size() == 4, "Foundation V1 does not expose exactly four rarities.")
	for rarity_index in range(rarity_ids.size()):
		var rarity_id: StringName = rarity_ids[rarity_index]
		expect(ItemRarityRules.is_valid_rarity_id(rarity_id), "Supported rarity is invalid.")
		expect(ItemRarityRules.get_rarity_display_name(rarity_id) == expected_names[rarity_index], "Rarity display name is invalid.")
		var color: Color = ItemRarityRules.get_rarity_color(rarity_id)
		expect(color.a > 0.0, "Supported rarity has no color mapping.")
		expect(color not in colors, "Rarity colors are not distinct.")
		colors.append(color)
	expect(not ItemRarityRules.is_valid_rarity_id(&"rare"), "Rare is a valid Foundation V1 rarity.")
	expect(not ItemRarityRules.is_valid_rarity_id(&"ancient"), "Ancient is a valid Foundation V1 rarity.")
	expect(not ItemRarityRules.is_valid_rarity_id(&""), "Empty rarity is valid.")


func test_production_definitions() -> void:
	var living_bark: ItemDefinition = GameContent.get_item(&"living_bark")
	var deep_roots: ItemDefinition = GameContent.get_item(&"deep_roots")
	expect(
		is_instance_valid(living_bark)
		and living_bark.item_id == &"living_bark"
		and living_bark.display_name == "Living Bark"
		and living_bark.equipment_slot_id == &"bark"
		and living_bark.icon == null
		and living_bark.is_valid_definition(),
		"Living Bark definition is invalid."
	)
	expect(
		is_instance_valid(deep_roots)
		and deep_roots.item_id == &"deep_roots"
		and deep_roots.display_name == "Deep Roots"
		and deep_roots.equipment_slot_id == &"roots"
		and deep_roots.icon == null
		and deep_roots.is_valid_definition(),
		"Deep Roots definition is invalid."
	)


func test_invalid_definitions() -> void:
	var definition := ItemDefinition.new()
	definition.display_name = "Fixture"
	definition.equipment_slot_id = &"bark"
	expect(not definition.is_valid_definition(), "ItemDefinition accepted an empty ID.")
	definition.item_id = &"fixture"
	definition.display_name = "  "
	expect(not definition.is_valid_definition(), "ItemDefinition accepted an empty display name.")
	definition.display_name = "Fixture"
	definition.equipment_slot_id = &"heartwood"
	expect(not definition.is_valid_definition(), "ItemDefinition accepted an unsupported slot.")


func test_branch_tier_separation() -> void:
	var thorn_crown: BranchDefinition = GameContent.get_branch(&"thorn_crown")
	expect(ItemRarityRules.LEGENDARY != StringName("tier_3"), "Legendary equipment aliases Branch Tier III.")
	expect(
		is_instance_valid(thorn_crown)
		and thorn_crown.is_legendary_branch()
		and thorn_crown.get_legendary_tier_display_name() == "Tier I"
		and ItemRarityRules.get_rarity_display_name(ItemRarityRules.LEGENDARY) == "Legendary",
		"Equipment rarity and Legendary Branch Tier APIs are not separate."
	)
	for rarity_id in ItemRarityRules.get_supported_rarity_ids():
		expect(not ItemRarityRules.get_rarity_display_name(rarity_id).begins_with("Tier "), "Equipment rarity exposes Branch Tier text.")


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	if message not in failures:
		failures.append(message)
	push_error(message)
