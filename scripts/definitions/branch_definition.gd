class_name BranchDefinition
extends Resource


const CATEGORY_STANDARD: StringName = &"standard"
const CATEGORY_LEGENDARY: StringName = &"legendary"
const LEGENDARY_TIER_NONE: int = 0
const LEGENDARY_TIER_1: int = 1
const LEGENDARY_TIER_2: int = 2
const LEGENDARY_TIER_3: int = 3


@export_category("Identity")

@export var branch_id: StringName = &""

@export var display_name: String = "Combat Branch"

@export_multiline
var description: String = ""


@export_category("Classification")

@export var category_id: StringName = CATEGORY_STANDARD

@export_range(0, 3, 1)
var legendary_tier: int = LEGENDARY_TIER_NONE


@export_category("Presentation")

@export var icon: Texture2D


@export_category("Runtime")

@export var branch_scene: PackedScene


@export_category("Targeting")

@export var targeting_profile: TargetingProfile


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


func is_standard_branch() -> bool:
	return category_id == CATEGORY_STANDARD


func is_legendary_branch() -> bool:
	return category_id == CATEGORY_LEGENDARY


func get_legendary_tier() -> int:
	return legendary_tier


func is_legendary_tier(checked_tier: int) -> bool:
	return is_legendary_branch() and legendary_tier == checked_tier


func get_legendary_tier_display_name() -> String:
	if not is_legendary_branch():
		return ""

	match legendary_tier:
		LEGENDARY_TIER_1:
			return "Tier I"
		LEGENDARY_TIER_2:
			return "Tier II"
		LEGENDARY_TIER_3:
			return "Tier III"

	return ""


func get_category_display_name() -> String:
	if is_standard_branch():
		return "Standard"

	if is_legendary_branch():
		return "Legendary"

	return "Unknown"


func is_valid_definition() -> bool:
	if branch_id == &"":
		return false

	if not (
		is_standard_branch()
		or is_legendary_branch()
	):
		return false

	if is_standard_branch() and legendary_tier != LEGENDARY_TIER_NONE:
		return false

	if is_legendary_branch() and legendary_tier not in [
		LEGENDARY_TIER_1,
		LEGENDARY_TIER_2,
		LEGENDARY_TIER_3
	]:
		return false

	if display_name.strip_edges().is_empty():
		return false

	if branch_scene == null:
		return false

	if targeting_profile == null:
		return false

	if not targeting_profile.is_valid_definition():
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
