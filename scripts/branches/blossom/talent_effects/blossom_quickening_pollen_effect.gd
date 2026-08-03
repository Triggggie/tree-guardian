class_name BlossomQuickeningPollenEffect
extends RefCounted


const EFFECT_ID: StringName = &"quickening_pollen"


var interval_multiplier: float = 0.80


func configure(
	configured_interval_multiplier: float
) -> void:
	interval_multiplier = max(
		configured_interval_multiplier,
		0.0
	)


func get_effect_id() -> StringName:
	return EFFECT_ID


func apply_interval(
	interval: float,
	minimum_interval: float
) -> float:
	var safe_interval: float = max(
		interval,
		0.0
	)

	var safe_minimum_interval: float = max(
		minimum_interval,
		0.0
	)

	return max(
		safe_interval * interval_multiplier,
		safe_minimum_interval
	)
