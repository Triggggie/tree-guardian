class_name BranchSeedLootPoolDefinition
extends Resource


@export_category("Identity")
@export var loot_pool_id: StringName = &""
@export var display_name: String = "Branch Seed Loot Pool"

@export_category("Pool")
@export var entries: Array[BranchSeedLootEntryDefinition] = []

@export_category("Encounter Tier Limits")
@export_range(0, 3, 1)
var miniboss_maximum_tier: int = 1

@export_range(0, 3, 1)
var boss_maximum_tier: int = 1

@export_category("Pity Thresholds")
@export_range(1, 1000000, 1)
var tier_1_pity_threshold: int = 12

@export_range(1, 1000000, 1)
var tier_2_pity_threshold: int = 18

@export_range(1, 1000000, 1)
var tier_3_pity_threshold: int = 24


func get_maximum_tier_for_encounter(
	encounter_rank_id: StringName
) -> int:
	match encounter_rank_id:
		EnemyDefinition.ENCOUNTER_RANK_MINIBOSS:
			return miniboss_maximum_tier
		EnemyDefinition.ENCOUNTER_RANK_BOSS:
			return boss_maximum_tier

	return BranchDefinition.LEGENDARY_TIER_NONE


func get_pity_threshold(legendary_tier: int) -> int:
	match legendary_tier:
		BranchDefinition.LEGENDARY_TIER_1:
			return tier_1_pity_threshold
		BranchDefinition.LEGENDARY_TIER_2:
			return tier_2_pity_threshold
		BranchDefinition.LEGENDARY_TIER_3:
			return tier_3_pity_threshold

	return 0


func get_entries_for_tier(
	legendary_tier: int
) -> Array[BranchSeedLootEntryDefinition]:
	var matching_entries: Array[BranchSeedLootEntryDefinition] = []

	for entry in entries:
		if not is_instance_valid(entry):
			continue

		if entry.get_legendary_tier() == legendary_tier:
			matching_entries.append(entry)

	return matching_entries


func is_valid_definition() -> bool:
	if loot_pool_id == &"" or display_name.strip_edges().is_empty():
		return false

	if miniboss_maximum_tier < 0 or miniboss_maximum_tier > 3:
		return false

	if boss_maximum_tier < 0 or boss_maximum_tier > 3:
		return false

	if boss_maximum_tier < miniboss_maximum_tier:
		return false

	if (
		tier_1_pity_threshold < 1
		or tier_2_pity_threshold < 1
		or tier_3_pity_threshold < 1
	):
		return false

	var used_branch_ids: Dictionary = {}

	for entry in entries:
		if not is_instance_valid(entry) or not entry.is_valid_definition():
			return false

		var branch_id: StringName = entry.get_branch_id()
		if used_branch_ids.has(branch_id):
			return false

		if entry.get_legendary_tier() > boss_maximum_tier:
			return false

		used_branch_ids[branch_id] = true

	return true
