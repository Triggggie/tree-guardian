class_name BranchDefinition
extends Resource


@export_category("Identity")

@export var branch_id: StringName = &""

@export var display_name: String = "Combat Branch"

@export_multiline
var description: String = ""


@export_category("Presentation")

@export var icon: Texture2D


@export_category("Runtime")

@export var branch_scene: PackedScene


@export_category("Progression")

@export var upgrades: Array[UpgradeDefinition] = []

@export var talent_tree: TalentTreeDefinition


func get_upgrade_by_id(
	upgrade_id: StringName
) -> UpgradeDefinition:
	for upgrade in upgrades:
		if upgrade == null:
			continue

		if upgrade.upgrade_id == upgrade_id:
			return upgrade

	return null


func get_upgrade_ids() -> Array[StringName]:
	var upgrade_ids: Array[StringName] = []

	for upgrade in upgrades:
		if upgrade == null:
			continue

		upgrade_ids.append(
			upgrade.upgrade_id
		)

	return upgrade_ids


func is_valid_definition() -> bool:
	if branch_id == &"":
		return false

	if display_name.strip_edges().is_empty():
		return false

	if branch_scene == null:
		return false

	var upgrades_by_id: Dictionary = {}

	for upgrade in upgrades:
		if upgrade == null:
			return false

		if not upgrade.is_valid_definition():
			return false

		if upgrades_by_id.has(
			upgrade.upgrade_id
		):
			return false

		upgrades_by_id[
			upgrade.upgrade_id
		] = upgrade

	if talent_tree != null:
		if not talent_tree.is_valid_definition():
			return false

	return true
