class_name TalentDefinition
extends Resource


@export_category("Identity")

@export var talent_id: StringName = &""

@export var display_name: String = "Talent"

@export_multiline
var description: String = ""


@export_category("Presentation")

@export var icon: Texture2D


@export_category("Requirements")

@export_range(1, 1000, 1)
var required_branch_level: int = 1

@export_range(1, 100, 1)
var talent_point_cost: int = 1


@export_category("Relationships")

@export var prerequisite_ids: Array[StringName] = []

@export var conflicting_ids: Array[StringName] = []


@export_category("Effects")

# Stabilní ID efektů, které talent aktivuje.
# Jejich skutečné provedení bude později řešit
# obecný systém efektů a modifikátorů.
@export var effect_ids: Array[StringName] = []


func is_valid_definition() -> bool:
	if talent_id == &"":
		return false

	if display_name.strip_edges().is_empty():
		return false

	if required_branch_level < 1:
		return false

	if talent_point_cost < 1:
		return false

	if talent_id in prerequisite_ids:
		return false

	if talent_id in conflicting_ids:
		return false

	if has_duplicate_ids(
		prerequisite_ids
	):
		return false

	if has_duplicate_ids(
		conflicting_ids
	):
		return false

	return true


func has_duplicate_ids(
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
