class_name EquipmentStatService
extends Node


signal equipment_stats_changed()


const EQUIPMENT_SOURCE_ID: StringName = &"equipment"


var total_affix_values: Dictionary = {}
var equipment: EquipmentService


func _ready() -> void:
	equipment = get_node_or_null("/root/Equipment") as EquipmentService
	if not is_instance_valid(equipment):
		push_error("EquipmentStatService requires Equipment.")
		return
	if not equipment.equipment_slot_changed.is_connected(
		_on_equipment_slot_changed
	):
		equipment.equipment_slot_changed.connect(
			_on_equipment_slot_changed
		)
	rebuild_from_equipment()


func rebuild_from_equipment() -> void:
	total_affix_values.clear()
	for stat_id in EquipmentStatRules.get_supported_stat_ids():
		total_affix_values[stat_id] = 0.0

	if is_instance_valid(equipment):
		for slot_id in EquipmentSlotRules.get_supported_slot_ids():
			var item: ItemInstance = equipment.get_equipped_item(slot_id)
			if item == null or not item.is_valid_data():
				continue
			for affix in item.affix_rolls:
				if (
					affix == null
					or not EquipmentStatRules.is_supported_stat_id(
						affix.stat_id
					)
				):
					continue
				total_affix_values[affix.stat_id] = (
					get_total_affix_value(affix.stat_id)
					+ affix.value
				)

	_apply_run_modifiers()
	equipment_stats_changed.emit()


func get_total_affix_value(stat_id: StringName) -> float:
	return float(total_affix_values.get(stat_id, 0.0))


func get_all_total_affix_values() -> Dictionary:
	return total_affix_values.duplicate(true)


func _apply_run_modifiers() -> void:
	RunModifiers.clear_source(EQUIPMENT_SOURCE_ID)
	var maximum_health: float = get_total_affix_value(
		EquipmentStatRules.MAXIMUM_HEALTH
	)
	var flat_regeneration: float = get_total_affix_value(
		EquipmentStatRules.HEALTH_REGENERATION
	)
	var branch_damage_bonus: float = get_total_affix_value(
		EquipmentStatRules.BRANCH_DAMAGE
	)
	var attack_speed_bonus: float = get_total_affix_value(
		EquipmentStatRules.ATTACK_SPEED
	)
	if not is_zero_approx(maximum_health):
		RunModifiers.set_additive_modifier(
			RunModifierIds.TREE_MAX_HEALTH,
			EQUIPMENT_SOURCE_ID,
			maximum_health
		)
	if not is_zero_approx(flat_regeneration):
		RunModifiers.set_additive_modifier(
			RunModifierIds.TREE_FLAT_REGEN,
			EQUIPMENT_SOURCE_ID,
			flat_regeneration
		)
	if not is_zero_approx(branch_damage_bonus):
		RunModifiers.set_multiplier_modifier(
			RunModifierIds.BRANCH_DAMAGE,
			EQUIPMENT_SOURCE_ID,
			max(1.0 + branch_damage_bonus, 0.0)
		)
	if not is_zero_approx(attack_speed_bonus):
		RunModifiers.set_multiplier_modifier(
			RunModifierIds.ATTACK_SPEED,
			EQUIPMENT_SOURCE_ID,
			max(1.0 + attack_speed_bonus, 0.0)
		)


func _on_equipment_slot_changed(
	_slot_id: StringName,
	_previous_instance_id: StringName,
	_new_instance_id: StringName
) -> void:
	rebuild_from_equipment()
