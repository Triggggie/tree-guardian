class_name TreeSoulDefinition
extends Resource


@export_category("Identity")

@export var tree_soul_id: StringName = &""

@export var display_name: String = "Tree Soul"

@export_multiline
var description: String = ""


@export_category("Presentation")

@export var soul_color: Color = Color(
	1.0,
	1.0,
	1.0,
	1.0
)

@export var icon: Texture2D


@export_category("Progression")

# Age, při kterém se Soul probudí a získá Rank 1.
@export_range(1, 1000000, 1)
var awakening_age: int = 20

# Počet Age potřebný pro každý další Rank.
@export_range(1, 1000000, 1)
var age_per_rank: int = 100

# Od tohoto Ranku se růst bonusů zpomalí.
@export_range(1, 1000000, 1)
var soft_cap_rank: int = 50

# Síla růstu za Rank po dosažení soft capu.
# Hodnota 0.5 znamená poloviční růst.
@export_range(0.0, 1.0, 0.01)
var post_soft_cap_multiplier: float = 0.5


@export_category("Bonuses")

@export var bonuses: Array[TreeSoulBonusDefinition] = []


func get_rank_for_age(
	tree_age: int
) -> int:
	if tree_age < awakening_age:
		return 0

	var safe_age_per_rank: int = max(
		age_per_rank,
		1
	)

	return (
		1
		+ int(
			floor(
				float(tree_age - awakening_age)
				/ float(safe_age_per_rank)
			)
		)
	)


func get_age_for_rank(
	soul_rank: int
) -> int:
	if soul_rank <= 1:
		return awakening_age

	return (
		awakening_age
		+ (soul_rank - 1)
		* max(
			age_per_rank,
			1
		)
	)


func get_next_rank_age(
	tree_age: int
) -> int:
	var current_rank: int = get_rank_for_age(
		tree_age
	)

	if current_rank <= 0:
		return awakening_age

	return get_age_for_rank(
		current_rank + 1
	)


func get_age_remaining_until_next_rank(
	tree_age: int
) -> int:
	return max(
		get_next_rank_age(tree_age)
		- tree_age,
		0
	)


func is_valid_definition() -> bool:
	if tree_soul_id == &"":
		return false

	if display_name.strip_edges().is_empty():
		return false

	if awakening_age < 1:
		return false

	if age_per_rank < 1:
		return false

	if soft_cap_rank < 1:
		return false

	if post_soft_cap_multiplier < 0.0:
		return false

	if post_soft_cap_multiplier > 1.0:
		return false

	if bonuses.is_empty():
		return false

	var used_modifier_ids: Dictionary = {}

	for bonus in bonuses:
		if not is_instance_valid(bonus):
			return false

		if not bonus.is_valid_definition():
			return false

		if used_modifier_ids.has(
			bonus.modifier_id
		):
			return false

		used_modifier_ids[
			bonus.modifier_id
		] = true

	return true
