class_name BlossomTwinPetalsEffect
extends RefCounted


const EFFECT_ID: StringName = &"twin_petals"


var owner_branch: Node2D
var damage_multiplier: float = 0.60


func configure(
	configured_owner_branch: Node2D,
	configured_damage_multiplier: float
) -> void:
	owner_branch = configured_owner_branch
	damage_multiplier = max(
		configured_damage_multiplier,
		0.0
	)


func get_effect_id() -> StringName:
	return EFFECT_ID


func find_secondary_target(
	primary_target: Node2D
) -> Node2D:
	if not is_valid_owner_target(primary_target):
		return null

	if not owner_branch.has_method(
		"find_best_target_on_side"
	):
		return null

	var preferred_side: int = int(
		owner_branch.get("facing_side")
	)

	var preferred_target: Node2D = (
		owner_branch.call(
			"find_best_target_on_side",
			preferred_side,
			primary_target
		) as Node2D
	)

	if is_valid_owner_target(preferred_target):
		return preferred_target

	var opposite_side: int = 1

	if preferred_side == 1:
		opposite_side = 0

	var fallback_target: Node2D = (
		owner_branch.call(
			"find_best_target_on_side",
			opposite_side,
			primary_target
		) as Node2D
	)

	if is_valid_owner_target(fallback_target):
		return fallback_target

	return null


func get_secondary_damage(
	primary_damage: float
) -> float:
	return max(
		primary_damage,
		0.0
	) * damage_multiplier


func is_valid_owner_target(
	target: Node
) -> bool:
	if not is_instance_valid(owner_branch):
		return false

	if not owner_branch.has_method(
		"is_valid_ranged_target"
	):
		return false

	return bool(
		owner_branch.call(
			"is_valid_ranged_target",
			target
		)
	)
