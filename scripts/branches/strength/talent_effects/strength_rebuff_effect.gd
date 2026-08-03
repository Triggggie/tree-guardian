class_name StrengthRebuffEffect
extends RefCounted


const EFFECT_ID: StringName = &"rebuff"


var owner_branch: Node2D
var knockback_distance: float = 35.0


func configure(
	configured_owner_branch: Node2D,
	configured_knockback_distance: float
) -> void:
	owner_branch = configured_owner_branch
	knockback_distance = configured_knockback_distance


func get_effect_id() -> StringName:
	return EFFECT_ID


func apply_after_resolved_hit(
	target: Node2D
) -> void:
	if not is_instance_valid(owner_branch):
		return

	if not owner_branch.has_method(
		"is_valid_attack_target"
	):
		return

	if not bool(
		owner_branch.call(
			"is_valid_attack_target",
			target
		)
	):
		return

	if not target.has_method(
		"apply_knockback"
	):
		return

	target.call(
		"apply_knockback",
		knockback_distance
	)
