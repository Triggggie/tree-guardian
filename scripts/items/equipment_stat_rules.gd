class_name EquipmentStatRules
extends RefCounted


const MAXIMUM_HEALTH: StringName = &"maximum_health"
const HEALTH_REGENERATION: StringName = &"health_regeneration"
const BRANCH_DAMAGE: StringName = &"branch_damage"
const ATTACK_SPEED: StringName = &"attack_speed"

const SUPPORTED_STAT_IDS: Array[StringName] = [
	MAXIMUM_HEALTH,
	HEALTH_REGENERATION,
	BRANCH_DAMAGE,
	ATTACK_SPEED
]


static func is_supported_stat_id(stat_id: StringName) -> bool:
	return stat_id in SUPPORTED_STAT_IDS


static func get_stat_display_name(stat_id: StringName) -> String:
	match stat_id:
		MAXIMUM_HEALTH:
			return "Maximum Health"
		HEALTH_REGENERATION:
			return "Health Regeneration"
		BRANCH_DAMAGE:
			return "Branch Damage"
		ATTACK_SPEED:
			return "Attack Speed"
	return ""


static func is_percentage_stat(stat_id: StringName) -> bool:
	return stat_id in [BRANCH_DAMAGE, ATTACK_SPEED]


static func format_stat_value(
	stat_id: StringName,
	value: float
) -> String:
	if not is_supported_stat_id(stat_id):
		return ""
	var display_value: float = value * 100.0 if is_percentage_stat(stat_id) else value
	var suffix: String = "%" if is_percentage_stat(stat_id) else ""
	if stat_id == HEALTH_REGENERATION:
		suffix = "/s"
	var sign_text: String = "+" if display_value >= 0.0 else "-"
	return "%s%s%s" % [
		sign_text,
		_format_number(absf(display_value)),
		suffix
	]


static func get_supported_stat_ids() -> Array[StringName]:
	return SUPPORTED_STAT_IDS.duplicate()


static func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return String.num(value, 2)
