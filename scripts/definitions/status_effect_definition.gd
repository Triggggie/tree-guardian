class_name StatusEffectDefinition
extends Resource


const PERIODIC_DAMAGE: StringName = &"periodic_damage"


enum StackMode {
	REFRESH_DURATION,
	ADD_DURATION,
	STACK_INTENSITY,
	REPLACE
}


@export_category("Identity")

@export var status_effect_id: StringName = &""

@export var display_name: String = "Status Effect"

@export_multiline
var description: String = ""


@export_category("Presentation")

@export var icon: Texture2D


@export_category("Duration")

@export var is_permanent: bool = false

@export_range(0.0, 3600.0, 0.05)
var base_duration: float = 1.0


@export_category("Stacking")

@export var stack_mode: StackMode = (
	StackMode.REFRESH_DURATION
)

@export_range(1, 100, 1)
var maximum_stacks: int = 1


@export_category("Effects")

# Stabilní ID modifikátorů aplikovaných po dobu
# trvání status efektu.
@export var modifier_ids: Array[StringName] = []

# Volitelný opakovaný efekt, například poison_damage.
@export var periodic_effect_id: StringName = &""

@export_range(0.0, 1000000000.0, 0.01)
var base_periodic_value: float = 0.0

@export_range(0.05, 3600.0, 0.05)
var tick_interval: float = 1.0


func is_valid_definition() -> bool:
	if status_effect_id == &"":
		return false

	if display_name.strip_edges().is_empty():
		return false

	if not is_permanent and base_duration <= 0.0:
		return false

	if maximum_stacks < 1:
		return false

	if stack_mode not in [
		StackMode.REFRESH_DURATION,
		StackMode.ADD_DURATION,
		StackMode.STACK_INTENSITY,
		StackMode.REPLACE
	]:
		return false

	if has_invalid_or_duplicate_ids(
		modifier_ids
	):
		return false

	if (
		periodic_effect_id != &""
		and (
			tick_interval <= 0.0
			or base_periodic_value <= 0.0
		)
	):
		return false

	if periodic_effect_id == &"" and base_periodic_value != 0.0:
		return false

	return true


func has_invalid_or_duplicate_ids(
	ids: Array[StringName]
) -> bool:
	var unique_ids: Dictionary = {}

	for checked_id in ids:
		if checked_id == &"":
			return true

		if unique_ids.has(checked_id):
			return true

		unique_ids[checked_id] = true

	return false
