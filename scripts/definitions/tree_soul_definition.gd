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


@export_category("Bonus")

# Stabilní ID bonusu, například:
# branch_power, action_speed,
# maximum_health nebo essence_gain.
@export var modifier_id: StringName = &""

@export_range(0.0, 1000000.0, 0.01)
var base_value: float = 0.0

@export_range(0.0, 1000000.0, 0.01)
var value_per_age: float = 0.0


func get_value_for_age(
	tree_age: int
) -> float:
	var safe_age: int = max(
		tree_age,
		1
	)

	return (
		base_value
		+ value_per_age
		* float(safe_age - 1)
	)


func is_valid_definition() -> bool:
	if tree_soul_id == &"":
		return false

	if display_name.strip_edges().is_empty():
		return false

	if modifier_id == &"":
		return false

	if base_value < 0.0:
		return false

	if value_per_age < 0.0:
		return false

	return true
