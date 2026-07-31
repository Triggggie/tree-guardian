class_name TreeSoulBonusDefinition
extends Resource


enum ApplicationMode {
	ADDITIVE,
	MULTIPLIER_BONUS
}


@export_category("Modifier")

@export var modifier_id: StringName = &""

@export var application_mode: ApplicationMode = (
	ApplicationMode.MULTIPLIER_BONUS
)


@export_category("Rank Values")

# Hodnota aktivní od Rank 1.
# Například 0.08 znamená +8 %.
@export_range(0.0, 1000000.0, 0.00001)
var base_value: float = 0.0

# Hodnota přidaná za každý další Rank.
# Například 0.0075 znamená +0.75 %.
@export_range(0.0, 1000000.0, 0.00001)
var value_per_rank: float = 0.0


func get_value_for_rank(
	soul_rank: int,
	soft_cap_rank: int,
	post_soft_cap_multiplier: float
) -> float:
	if soul_rank <= 0:
		return 0.0

	var safe_soft_cap_rank: int = max(
		soft_cap_rank,
		1
	)

	var safe_post_soft_cap_multiplier: float = max(
		post_soft_cap_multiplier,
		0.0
	)

	var full_strength_rank_steps: int = max(
		min(
			soul_rank,
			safe_soft_cap_rank
		)
		- 1,
		0
	)

	var reduced_strength_rank_steps: int = max(
		soul_rank
		- safe_soft_cap_rank,
		0
	)

	return (
		base_value
		+ float(full_strength_rank_steps)
		* value_per_rank
		+ float(reduced_strength_rank_steps)
		* value_per_rank
		* safe_post_soft_cap_multiplier
	)


func get_run_modifier_value_for_rank(
	soul_rank: int,
	soft_cap_rank: int,
	post_soft_cap_multiplier: float
) -> float:
	var current_bonus: float = get_value_for_rank(
		soul_rank,
		soft_cap_rank,
		post_soft_cap_multiplier
	)

	if (
		application_mode
		== ApplicationMode.MULTIPLIER_BONUS
	):
		return 1.0 + current_bonus

	return current_bonus


func is_valid_definition() -> bool:
	if modifier_id == &"":
		return false

	if base_value < 0.0:
		return false

	if value_per_rank < 0.0:
		return false

	return true
