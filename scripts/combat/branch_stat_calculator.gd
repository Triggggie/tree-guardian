class_name BranchStatCalculator
extends RefCounted


static func apply_branch_power(
	base_power: float
) -> float:
	var safe_base_power: float = max(
		base_power,
		0.0
	)

	return max(
		RunModifiers.apply_modifier(
			safe_base_power,
			RunModifierIds.BRANCH_POWER
		),
		0.0
	)


static func get_modified_action_speed(
	base_action_speed: float
) -> float:
	var safe_base_action_speed: float = max(
		base_action_speed,
		0.0
	)

	return max(
		RunModifiers.apply_modifier(
			safe_base_action_speed,
			RunModifierIds.ACTION_SPEED
		),
		0.0
	)


static func get_modified_cooldown(
	base_cooldown: float,
	minimum_cooldown: float = 0.0
) -> float:
	var safe_base_cooldown: float = max(
		base_cooldown,
		0.001
	)

	var safe_minimum_cooldown: float = max(
		minimum_cooldown,
		0.0
	)

	var base_action_speed: float = (
		1.0 / safe_base_cooldown
	)

	var modified_action_speed: float = (
		get_modified_action_speed(
			base_action_speed
		)
	)

	if modified_action_speed <= 0.0:
		return max(
			safe_base_cooldown,
			safe_minimum_cooldown
		)

	return max(
		1.0 / modified_action_speed,
		safe_minimum_cooldown
	)
