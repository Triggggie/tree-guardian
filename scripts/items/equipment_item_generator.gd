class_name EquipmentItemGenerator
extends RefCounted


func generate_item(
	instance_id: StringName,
	enemy_definition: EnemyDefinition,
	global_wave: int,
	random_number_generator: RandomNumberGenerator
) -> ItemInstance:
	if (
		instance_id == &""
		or not is_instance_valid(enemy_definition)
		or not enemy_definition.is_valid_definition()
		or global_wave < 1
		or not is_instance_valid(random_number_generator)
	):
		return null

	var eligible_definitions: Array[ItemDefinition] = (
		_get_eligible_item_definitions()
	)
	if eligible_definitions.is_empty():
		return null

	var selected_definition: ItemDefinition = eligible_definitions[
		random_number_generator.randi_range(
			0,
			eligible_definitions.size() - 1
		)
	]
	var rarity_id: StringName = EquipmentLootRules.roll_rarity(
		enemy_definition.equipment_minimum_rarity_id,
		random_number_generator
	)
	if rarity_id == &"":
		return null

	var item_level: int = EquipmentLootRules.get_item_level(
		global_wave,
		enemy_definition.equipment_item_level_bonus
	)
	var affix_pool: Array[StringName] = (
		EquipmentLootRules.get_affix_pool_for_slot(
			selected_definition.equipment_slot_id
		)
	)
	var affix_count: int = EquipmentLootRules.get_affix_count(rarity_id)
	if affix_count < 1 or affix_pool.size() < affix_count:
		return null

	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.definition_id = selected_definition.item_id
	item.item_level = item_level
	item.rarity_id = rarity_id
	item.is_locked = false

	var remaining_affixes: Array[StringName] = affix_pool.duplicate()
	for _affix_index in range(affix_count):
		var selected_index: int = random_number_generator.randi_range(
			0,
			remaining_affixes.size() - 1
		)
		var stat_id: StringName = remaining_affixes[selected_index]
		remaining_affixes.remove_at(selected_index)
		var variance_factor: float = random_number_generator.randf_range(
			EquipmentLootRules.MINIMUM_VARIANCE,
			EquipmentLootRules.MAXIMUM_VARIANCE
		)
		var value: float = EquipmentLootRules.calculate_affix_value(
			stat_id,
			item_level,
			rarity_id,
			variance_factor
		)
		if value <= 0.0:
			return null
		item.affix_rolls.append(ItemAffixRoll.new(stat_id, value))

	return item if item.is_valid_data() else null


func _get_eligible_item_definitions() -> Array[ItemDefinition]:
	var definitions: Array[ItemDefinition] = []
	for definition in GameContent.get_items():
		if (
			not is_instance_valid(definition)
			or not definition.is_valid_definition()
			or not EquipmentSlotRules.is_valid_slot_id(
				definition.equipment_slot_id
			)
		):
			continue
		definitions.append(definition)
	return definitions
