class_name UpgradeDefinition
extends Resource


@export_category("Identity")

@export var upgrade_id: StringName = &""

@export var display_name: String = "Upgrade"

@export_multiline
var description: String = ""


@export_category("Presentation")

@export var icon: Texture2D


@export_category("Effect")

@export var effect_id: StringName = &""

@export_range(0.0, 1000000.0, 0.00001)
var value_per_level: float = 0.0


@export_category("Cost")

@export_range(1, 1000000, 1)
var base_cost: int = 1

@export_range(1.0, 5.0, 0.01)
var cost_growth: float = 1.35


@export_category("Limits")

# Hodnota 0 znamená, že maximální level určuje
# runtime pravidlo větve, například Branch Level × 3.
@export_range(0, 1000000, 1)
var maximum_level: int = 0


func get_cost_for_level(
	current_level: int
) -> int:
	var safe_level: int = max(
		current_level,
		0
	)

	var calculated_cost: float = (
		float(base_cost)
		* pow(
			cost_growth,
			safe_level
		)
	)

	return max(
		int(round(calculated_cost)),
		1
	)


func is_valid_definition() -> bool:
	if upgrade_id == &"":
		return false

	if display_name.strip_edges().is_empty():
		return false

	if effect_id == &"":
		return false

	if value_per_level <= 0.0:
		return false

	if base_cost <= 0:
		return false

	if cost_growth < 1.0:
		return false

	if maximum_level < 0:
		return false

	return true
