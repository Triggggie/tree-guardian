class_name ItemRarityRules
extends RefCounted


const COMMON: StringName = &"common"
const UNCOMMON: StringName = &"uncommon"
const EPIC: StringName = &"epic"
const LEGENDARY: StringName = &"legendary"

const SUPPORTED_RARITY_IDS: Array[StringName] = [
	COMMON,
	UNCOMMON,
	EPIC,
	LEGENDARY
]


static func is_valid_rarity_id(rarity_id: StringName) -> bool:
	return rarity_id in SUPPORTED_RARITY_IDS


static func get_rarity_display_name(rarity_id: StringName) -> String:
	match rarity_id:
		COMMON:
			return "Common"
		UNCOMMON:
			return "Uncommon"
		EPIC:
			return "Epic"
		LEGENDARY:
			return "Legendary"

	return ""


static func get_rarity_color(rarity_id: StringName) -> Color:
	match rarity_id:
		COMMON:
			return Color(0.65, 0.65, 0.65)
		UNCOMMON:
			return Color(0.30, 0.78, 0.36)
		EPIC:
			return Color(0.68, 0.36, 0.88)
		LEGENDARY:
			return Color(0.95, 0.70, 0.20)

	return Color.TRANSPARENT


static func get_rarity_rank(rarity_id: StringName) -> int:
	return SUPPORTED_RARITY_IDS.find(rarity_id)


static func get_supported_rarity_ids() -> Array[StringName]:
	return SUPPORTED_RARITY_IDS.duplicate()
