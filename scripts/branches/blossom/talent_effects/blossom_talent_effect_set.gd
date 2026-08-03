class_name BlossomTalentEffectSet
extends RefCounted


var owner_branch: Node2D
var abundant_bloom_effect: BlossomAbundantBloomEffect
var quickening_pollen_effect: BlossomQuickeningPollenEffect
var twin_petals_effect: BlossomTwinPetalsEffect

var active_effect_ids: Dictionary = {}
var warned_unsupported_effect_ids: Dictionary = {}


func _init() -> void:
	abundant_bloom_effect = BlossomAbundantBloomEffect.new()
	quickening_pollen_effect = BlossomQuickeningPollenEffect.new()
	twin_petals_effect = BlossomTwinPetalsEffect.new()


func configure(
	configured_owner_branch: Node2D,
	abundant_healing_multiplier: float,
	quickening_interval_multiplier: float,
	twin_petal_damage_multiplier: float
) -> void:
	owner_branch = configured_owner_branch

	abundant_bloom_effect.configure(
		abundant_healing_multiplier
	)

	quickening_pollen_effect.configure(
		quickening_interval_multiplier
	)

	twin_petals_effect.configure(
		owner_branch,
		twin_petal_damage_multiplier
	)


func set_active_effect_ids(
	effect_ids: Array[StringName]
) -> void:
	active_effect_ids.clear()

	var supported_effect_ids: Dictionary = {}

	for supported_effect_id in get_supported_effect_ids():
		supported_effect_ids[supported_effect_id] = true

	for effect_id in effect_ids:
		if effect_id == &"":
			continue

		if supported_effect_ids.has(effect_id):
			active_effect_ids[effect_id] = true
			continue

		if warned_unsupported_effect_ids.has(effect_id):
			continue

		warned_unsupported_effect_ids[effect_id] = true
		push_warning(
			"BlossomTalentEffectSet: Unsupported effect ID "
			+ "'%s' was ignored."
			% effect_id
		)


func get_supported_effect_ids() -> Array[StringName]:
	return [
		abundant_bloom_effect.get_effect_id(),
		quickening_pollen_effect.get_effect_id(),
		twin_petals_effect.get_effect_id()
	]


func has_active_effect(
	effect_id: StringName
) -> bool:
	return active_effect_ids.has(effect_id)


func apply_healing_per_tick(
	healing_value: float
) -> float:
	if not has_active_effect(
		abundant_bloom_effect.get_effect_id()
	):
		return healing_value

	return abundant_bloom_effect.apply_healing(
		healing_value
	)


func apply_healing_tick_interval(
	interval: float,
	minimum_interval: float
) -> float:
	if not has_active_effect(
		quickening_pollen_effect.get_effect_id()
	):
		return max(
			max(interval, 0.0),
			max(minimum_interval, 0.0)
		)

	return quickening_pollen_effect.apply_interval(
		interval,
		minimum_interval
	)


func find_secondary_petal_target(
	primary_target: Node2D
) -> Node2D:
	if not has_active_effect(
		twin_petals_effect.get_effect_id()
	):
		return null

	return twin_petals_effect.find_secondary_target(
		primary_target
	)


func get_secondary_petal_damage(
	primary_damage: float
) -> float:
	if not has_active_effect(
		twin_petals_effect.get_effect_id()
	):
		return 0.0

	return twin_petals_effect.get_secondary_damage(
		primary_damage
	)


func reset_runtime_state() -> void:
	pass
