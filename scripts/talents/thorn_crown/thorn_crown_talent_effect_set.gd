class_name ThornCrownTalentEffectSet
extends RefCounted


const EFFECT_BARBED_CORE: StringName = &"thorn_crown_barbed_core"
const EFFECT_TWIN_TORMENT: StringName = &"thorn_crown_twin_torment"
const EFFECT_OVERGROWTH: StringName = &"thorn_crown_overgrowth"


var active_effect_ids: Dictionary = {}
var warned_unsupported_effect_ids: Dictionary = {}
var attack_cycle_count: int = 0
var cycle_damage_multiplier: float = 1.0
var cycle_radius_multiplier: float = 1.0


func set_active_effect_ids(effect_ids: Array[StringName]) -> void:
	var next_effect_ids: Dictionary = {}
	for effect_id in effect_ids:
		if effect_id in get_supported_effect_ids():
			next_effect_ids[effect_id] = true
			continue
		if effect_id == &"" or warned_unsupported_effect_ids.has(effect_id):
			continue
		warned_unsupported_effect_ids[effect_id] = true
		push_warning(
			"ThornCrownTalentEffectSet: Unsupported effect ID '%s' was ignored."
			% effect_id
		)

	if active_effect_ids == next_effect_ids:
		return
	active_effect_ids = next_effect_ids
	reset_runtime_state()


func get_supported_effect_ids() -> Array[StringName]:
	return [EFFECT_BARBED_CORE, EFFECT_TWIN_TORMENT, EFFECT_OVERGROWTH]


func has_active_effect(effect_id: StringName) -> bool:
	return active_effect_ids.has(effect_id)


func begin_attack_cycle(has_left_target: bool, has_right_target: bool) -> bool:
	cycle_damage_multiplier = 1.0
	cycle_radius_multiplier = 1.0
	if not has_left_target and not has_right_target:
		return false

	attack_cycle_count += 1
	if has_active_effect(EFFECT_TWIN_TORMENT) and has_left_target and has_right_target:
		cycle_damage_multiplier *= 1.25
	if has_active_effect(EFFECT_OVERGROWTH) and attack_cycle_count % 3 == 0:
		cycle_damage_multiplier *= 1.30
		cycle_radius_multiplier *= 1.50
	return true


func get_cycle_damage_multiplier() -> float:
	return cycle_damage_multiplier


func get_cycle_radius_multiplier() -> float:
	return cycle_radius_multiplier


func get_primary_damage_multiplier() -> float:
	return 1.40 if has_active_effect(EFFECT_BARBED_CORE) else 1.0


func reset_runtime_state() -> void:
	attack_cycle_count = 0
	cycle_damage_multiplier = 1.0
	cycle_radius_multiplier = 1.0
