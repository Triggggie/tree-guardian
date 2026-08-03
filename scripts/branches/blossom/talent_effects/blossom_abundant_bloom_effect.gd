class_name BlossomAbundantBloomEffect
extends RefCounted


const EFFECT_ID: StringName = &"abundant_bloom"


var healing_multiplier: float = 1.50


func configure(
	configured_healing_multiplier: float
) -> void:
	healing_multiplier = max(
		configured_healing_multiplier,
		0.0
	)


func get_effect_id() -> StringName:
	return EFFECT_ID


func apply_healing(
	healing_value: float
) -> float:
	return max(
		healing_value,
		0.0
	) * healing_multiplier
