class_name EquipmentLootRules
extends RefCounted


const COMMON_WEIGHT: float = 78.0
const UNCOMMON_WEIGHT: float = 20.0
const EPIC_WEIGHT: float = 2.0
const LEGENDARY_WEIGHT: float = 0.0

const COMMON_VALUE_MULTIPLIER: float = 1.0
const UNCOMMON_VALUE_MULTIPLIER: float = 1.25
const EPIC_VALUE_MULTIPLIER: float = 1.50

const MINIMUM_VARIANCE: float = 0.90
const MAXIMUM_VARIANCE: float = 1.10


static func get_item_level(
	global_wave: int,
	item_level_bonus: int = 0
) -> int:
	var base_item_level: int = 1 + int(floor(
		float(max(global_wave, 1) - 1) / 10.0
	))
	return max(base_item_level + max(item_level_bonus, 0), 1)


static func get_rarity_weight(rarity_id: StringName) -> float:
	match rarity_id:
		ItemRarityRules.COMMON:
			return COMMON_WEIGHT
		ItemRarityRules.UNCOMMON:
			return UNCOMMON_WEIGHT
		ItemRarityRules.EPIC:
			return EPIC_WEIGHT
		ItemRarityRules.LEGENDARY:
			return LEGENDARY_WEIGHT
	return 0.0


static func get_rarity_value_multiplier(rarity_id: StringName) -> float:
	match rarity_id:
		ItemRarityRules.COMMON:
			return COMMON_VALUE_MULTIPLIER
		ItemRarityRules.UNCOMMON:
			return UNCOMMON_VALUE_MULTIPLIER
		ItemRarityRules.EPIC:
			return EPIC_VALUE_MULTIPLIER
	return 0.0


static func get_affix_count(rarity_id: StringName) -> int:
	match rarity_id:
		ItemRarityRules.COMMON:
			return 1
		ItemRarityRules.UNCOMMON, ItemRarityRules.EPIC:
			return 2
	return 0


static func get_affix_pool_for_slot(slot_id: StringName) -> Array[StringName]:
	match slot_id:
		EquipmentSlotRules.BARK_SLOT_ID:
			return [
				EquipmentStatRules.BRANCH_DAMAGE,
				EquipmentStatRules.ATTACK_SPEED
			]
		EquipmentSlotRules.ROOTS_SLOT_ID:
			return [
				EquipmentStatRules.MAXIMUM_HEALTH,
				EquipmentStatRules.HEALTH_REGENERATION
			]
		EquipmentSlotRules.HEARTWOOD_SLOT_ID:
			return [
				EquipmentStatRules.MAXIMUM_HEALTH,
				EquipmentStatRules.BRANCH_DAMAGE
			]
		EquipmentSlotRules.CANOPY_SLOT_ID:
			return [
				EquipmentStatRules.BRANCH_DAMAGE,
				EquipmentStatRules.ATTACK_SPEED
			]
		EquipmentSlotRules.SAP_SLOT_ID:
			return [
				EquipmentStatRules.HEALTH_REGENERATION,
				EquipmentStatRules.ATTACK_SPEED
			]
	return []


static func roll_rarity(
	minimum_rarity_id: StringName,
	random_number_generator: RandomNumberGenerator
) -> StringName:
	if (
		not ItemRarityRules.is_valid_rarity_id(minimum_rarity_id)
		or not is_instance_valid(random_number_generator)
	):
		return &""

	var minimum_rank: int = ItemRarityRules.get_rarity_rank(
		minimum_rarity_id
	)
	var eligible_rarities: Array[StringName] = []
	var total_weight: float = 0.0

	for rarity_id in ItemRarityRules.get_supported_rarity_ids():
		if ItemRarityRules.get_rarity_rank(rarity_id) < minimum_rank:
			continue
		var weight: float = get_rarity_weight(rarity_id)
		if weight <= 0.0:
			continue
		eligible_rarities.append(rarity_id)
		total_weight += weight

	if eligible_rarities.is_empty() or total_weight <= 0.0:
		return &""

	var selected_weight: float = random_number_generator.randf() * total_weight
	var cumulative_weight: float = 0.0
	for rarity_id in eligible_rarities:
		cumulative_weight += get_rarity_weight(rarity_id)
		if selected_weight < cumulative_weight:
			return rarity_id
	return eligible_rarities.back()


static func calculate_affix_value(
	stat_id: StringName,
	item_level: int,
	rarity_id: StringName,
	variance_factor: float
) -> float:
	var safe_item_level: int = max(item_level, 1)
	var rarity_multiplier: float = get_rarity_value_multiplier(rarity_id)
	if rarity_multiplier <= 0.0:
		return 0.0
	var safe_variance: float = clamp(
		variance_factor,
		MINIMUM_VARIANCE,
		MAXIMUM_VARIANCE
	)
	var calculated_value: float = 0.0

	match stat_id:
		EquipmentStatRules.MAXIMUM_HEALTH:
			calculated_value = (
				8.0 + 2.0 * safe_item_level
			) * rarity_multiplier * safe_variance
			return max(roundf(calculated_value), 1.0)
		EquipmentStatRules.HEALTH_REGENERATION:
			calculated_value = (
				0.15 + 0.04 * safe_item_level
			) * rarity_multiplier * safe_variance
			return max(_round_to_step(calculated_value, 0.05), 0.05)
		EquipmentStatRules.BRANCH_DAMAGE:
			calculated_value = (
				0.03 + 0.004 * safe_item_level
			) * rarity_multiplier * safe_variance
			return max(_round_to_step(calculated_value, 0.005), 0.005)
		EquipmentStatRules.ATTACK_SPEED:
			calculated_value = (
				0.03 + 0.003 * safe_item_level
			) * rarity_multiplier * safe_variance
			return max(_round_to_step(calculated_value, 0.005), 0.005)
	return 0.0


static func _round_to_step(value: float, step: float) -> float:
	if step <= 0.0:
		return value
	return roundf(value / step) * step
