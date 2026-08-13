extends Node


var failures: Array[String] = []


func _ready() -> void:
	test_instance_independence()
	test_invalid_instances()

	if failures.is_empty():
		print("ITEM INSTANCE SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print("ITEM INSTANCE SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func test_instance_independence() -> void:
	var definition: ItemDefinition = GameContent.get_item(&"living_bark")
	var instance_a := ItemInstance.new()
	instance_a.instance_id = &"item_instance_001"
	instance_a.definition_id = &"living_bark"
	instance_a.item_level = 12
	instance_a.rarity_id = ItemRarityRules.EPIC
	instance_a.affix_rolls.append(ItemAffixRoll.new(&"maximum_health", 15.0))
	var instance_b := ItemInstance.new()
	instance_b.instance_id = &"item_instance_002"
	instance_b.definition_id = &"living_bark"
	instance_b.item_level = 4
	instance_b.rarity_id = ItemRarityRules.COMMON
	instance_b.affix_rolls.append(ItemAffixRoll.new(&"health_regeneration", 0.5))
	instance_b.is_locked = true

	expect(instance_a.is_valid_data() and instance_b.is_valid_data(), "Valid item instances were rejected.")
	expect(GameContent.get_item(instance_a.definition_id) == definition, "Instance A does not resolve its shared definition.")
	expect(GameContent.get_item(instance_b.definition_id) == definition, "Instance B does not resolve its shared definition.")
	expect(instance_a.instance_id != instance_b.instance_id, "Concrete item instance IDs are not independent.")
	expect(instance_a.item_level != instance_b.item_level, "Item Levels are not independent.")
	expect(instance_a.rarity_id != instance_b.rarity_id, "Rarities are not independent.")
	expect(instance_a.affix_rolls != instance_b.affix_rolls, "Affix arrays are shared.")
	expect(not instance_a.is_locked and instance_b.is_locked, "Initial lock states are not independent.")

	instance_a.is_locked = true
	instance_a.affix_rolls[0].value = 20.0
	expect(instance_b.is_locked, "Changing instance A changed instance B lock state.")
	expect(is_equal_approx(instance_b.affix_rolls[0].value, 0.5), "Changing instance A changed instance B affix value.")
	expect(
		definition.item_id == &"living_bark"
		and definition.display_name == "Living Bark"
		and definition.equipment_slot_id == &"bark",
		"Mutable ItemInstance state changed shared ItemDefinition content."
	)


func test_invalid_instances() -> void:
	var fixture := create_valid_fixture()
	fixture.instance_id = &""
	expect(not fixture.is_valid_data(), "ItemInstance accepted an empty instance ID.")
	fixture = create_valid_fixture()
	fixture.definition_id = &""
	expect(not fixture.is_valid_data(), "ItemInstance accepted an empty definition ID.")
	fixture = create_valid_fixture()
	fixture.item_level = 0
	expect(not fixture.is_valid_data(), "ItemInstance accepted Item Level 0.")
	fixture = create_valid_fixture()
	fixture.rarity_id = &"rare"
	expect(not fixture.is_valid_data(), "ItemInstance accepted an unknown rarity.")
	fixture = create_valid_fixture()
	fixture.affix_rolls.append(ItemAffixRoll.new())
	expect(not fixture.is_valid_data(), "ItemInstance accepted an empty affix stat ID.")


func create_valid_fixture() -> ItemInstance:
	var fixture := ItemInstance.new()
	fixture.instance_id = &"fixture_instance"
	fixture.definition_id = &"living_bark"
	fixture.item_level = 1
	fixture.rarity_id = ItemRarityRules.COMMON
	return fixture


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	if message not in failures:
		failures.append(message)
	push_error(message)
