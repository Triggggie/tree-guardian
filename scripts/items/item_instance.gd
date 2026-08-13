class_name ItemInstance
extends RefCounted


var instance_id: StringName = &""
var definition_id: StringName = &""
var item_level: int = 1
var rarity_id: StringName = ItemRarityRules.COMMON
var affix_rolls: Array[ItemAffixRoll] = []
var is_locked: bool = false


func is_valid_data() -> bool:
	if instance_id == &"" or definition_id == &"":
		return false

	if item_level < 1:
		return false

	if not ItemRarityRules.is_valid_rarity_id(rarity_id):
		return false

	for affix_roll in affix_rolls:
		if affix_roll == null or not affix_roll.is_valid_data():
			return false

	return true
