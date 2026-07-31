class_name BranchStatCalculator
extends RefCounted


static func apply_branch_damage(
	base_damage: float
) -> float:
	var safe_base_damage: float = max(
		base_damage,
		0.0
	)

	return max(
		RunModifiers.apply_modifier(
			safe_base_damage,
			RunModifierIds.BRANCH_DAMAGE
		),
		0.0
	)


static func apply_healing_power(
	base_healing: float
) -> float:
	var safe_base_healing: float = max(
		base_healing,
		0.0
	)

	return max(
		RunModifiers.apply_modifier(
			safe_base_healing,
			RunModifierIds.HEALING_POWER
		),
		0.0
	)


static func get_modified_attack_speed(
	base_attack_speed: float
) -> float:
	var safe_base_attack_speed: float = max(
		base_attack_speed,
		0.0
	)

	return max(
		RunModifiers.apply_modifier(
			safe_base_attack_speed,
			RunModifierIds.ATTACK_SPEED
		),
		0.0
	)


static func get_modified_attack_cooldown(
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

	var base_attack_speed: float = (
		1.0 / safe_base_cooldown
	)

	var modified_attack_speed: float = (
		get_modified_attack_speed(
			base_attack_speed
		)
	)

	if modified_attack_speed <= 0.0:
		return max(
			safe_base_cooldown,
			safe_minimum_cooldown
		)

	return max(
		1.0 / modified_attack_speed,
		safe_minimum_cooldown
	)


# Dočasné migrační metody.
# Současné větve je ještě používají a převedeme je
# postupně v dalších malých krocích.

static func apply_branch_power(
	base_power: float
) -> float:
	return apply_branch_damage(
		base_power
	)


static func get_modified_action_speed(
	base_action_speed: float
) -> float:
	return get_modified_attack_speed(
		base_action_speed
	)


static func get_modified_cooldown(
	base_cooldown: float,
	minimum_cooldown: float = 0.0
) -> float:
	return get_modified_attack_cooldown(
		base_cooldown,
		minimum_cooldown
	)
