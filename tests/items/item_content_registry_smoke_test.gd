extends Node


var failures: Array[String] = []


func _ready() -> void:
	test_production_registry()
	test_index_rebuild()
	test_validator()

	if failures.is_empty():
		print("ITEM CONTENT REGISTRY SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print("ITEM CONTENT REGISTRY SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func test_production_registry() -> void:
	var items: Array[ItemDefinition] = GameContent.get_items()
	expect(items.size() == 5, "Production registry does not contain exactly five items.")
	expect(
		items.map(func(item: ItemDefinition) -> StringName: return item.item_id) == [
			&"living_bark", &"deep_roots", &"elder_heartwood",
			&"verdant_canopy", &"luminous_sap"
		],
		"Production item registry order is invalid."
	)
	expect(GameContent.get_item(&"living_bark") == items[0], "Living Bark lookup failed.")
	expect(GameContent.get_item(&"deep_roots") == items[1], "Deep Roots lookup failed.")
	expect(
		GameContent.get_item(&"elder_heartwood").equipment_slot_id == &"heartwood"
		and GameContent.get_item(&"verdant_canopy").equipment_slot_id == &"canopy"
		and GameContent.get_item(&"luminous_sap").equipment_slot_id == &"sap",
		"New production ItemDefinition lookup or slot is wrong."
	)
	expect(GameContent.get_item(&"missing_item") == null, "Unknown item lookup did not return null.")


func test_index_rebuild() -> void:
	var registry := ContentRegistry.new()
	var item := create_definition(&"fixture_item", "Fixture Item", &"bark")
	registry.items = [item]
	registry.rebuild_indexes()
	expect(registry.get_item_definition(&"fixture_item") == item, "Initial item index rebuild failed.")
	item.item_id = &"renamed_fixture"
	registry.invalidate_indexes()
	expect(registry.get_item_definition(&"fixture_item") == null, "Invalidated item index retained an old ID.")
	expect(registry.get_item_definition(&"renamed_fixture") == item, "Lazy item index rebuild failed.")


func test_validator() -> void:
	var valid_registry := ContentRegistry.new()
	valid_registry.items = [create_definition(&"one", "One", &"bark"), create_definition(&"two", "Two", &"roots")]
	expect(ContentValidator.validate_registry(valid_registry).is_empty(), "Validator rejected valid item content.")

	var duplicate_registry := ContentRegistry.new()
	duplicate_registry.items = [create_definition(&"duplicate", "First", &"bark"), create_definition(&"duplicate", "Second", &"roots")]
	var duplicate_errors: Array[String] = ContentValidator.validate_registry(duplicate_registry)
	expect("Duplicate Item ID 'duplicate'." in duplicate_errors, "Validator did not report a duplicate item ID.")

	var invalid_registry := ContentRegistry.new()
	invalid_registry.items = [null, create_definition(&"invalid_slot", "Invalid Slot", &"soul_relic")]
	var invalid_errors: Array[String] = ContentValidator.validate_registry(invalid_registry)
	expect("Item entry 0 is empty." in invalid_errors, "Validator accepted a null item definition.")
	expect("Item entry 1 is invalid." in invalid_errors, "Validator accepted an invalid item definition.")


func create_definition(
	item_id: StringName,
	display_name: String,
	slot_id: StringName
) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.item_id = item_id
	definition.display_name = display_name
	definition.equipment_slot_id = slot_id
	return definition


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	if message not in failures:
		failures.append(message)
	push_error(message)
