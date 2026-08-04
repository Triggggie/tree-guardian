class_name BranchSeedLootEntryDefinition
extends Resource


@export var branch_definition: BranchDefinition

@export_range(0.0001, 1000000.0, 0.0001)
var weight: float = 1.0


func get_branch_id() -> StringName:
	if not is_instance_valid(branch_definition):
		return &""

	return branch_definition.branch_id


func get_legendary_tier() -> int:
	if not is_instance_valid(branch_definition):
		return BranchDefinition.LEGENDARY_TIER_NONE

	return branch_definition.get_legendary_tier()


func get_legendary_tier_display_name() -> String:
	if not is_instance_valid(branch_definition):
		return ""

	return branch_definition.get_legendary_tier_display_name()


func is_valid_definition() -> bool:
	return (
		is_instance_valid(branch_definition)
		and branch_definition.is_valid_definition()
		and branch_definition.is_legendary_branch()
		and get_legendary_tier() in [
			BranchDefinition.LEGENDARY_TIER_1,
			BranchDefinition.LEGENDARY_TIER_2,
			BranchDefinition.LEGENDARY_TIER_3
		]
		and weight > 0.0
	)
