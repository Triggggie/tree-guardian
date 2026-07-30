class_name TalentTreeDefinition
extends Resource


@export_category("Identity")

@export var talent_tree_id: StringName = &""

@export var display_name: String = "Talent Tree"

@export_multiline
var description: String = ""


@export_category("Talents")

@export var talents: Array[TalentDefinition] = []


func get_talent_by_id(
	talent_id: StringName
) -> TalentDefinition:
	for talent in talents:
		if talent == null:
			continue

		if talent.talent_id == talent_id:
			return talent

	return null


func get_talent_ids() -> Array[StringName]:
	var talent_ids: Array[StringName] = []

	for talent in talents:
		if talent == null:
			continue

		talent_ids.append(
			talent.talent_id
		)

	return talent_ids


func is_valid_definition() -> bool:
	if talent_tree_id == &"":
		return false

	if display_name.strip_edges().is_empty():
		return false

	if talents.is_empty():
		return false

	var talents_by_id: Dictionary = {}

	for talent in talents:
		if talent == null:
			return false

		if not talent.is_valid_definition():
			return false

		if talents_by_id.has(
			talent.talent_id
		):
			return false

		talents_by_id[
			talent.talent_id
		] = talent

	for talent in talents:
		for prerequisite_id in (
			talent.prerequisite_ids
		):
			if not talents_by_id.has(
				prerequisite_id
			):
				return false

		for conflicting_id in (
			talent.conflicting_ids
		):
			if not talents_by_id.has(
				conflicting_id
			):
				return false

	return true
