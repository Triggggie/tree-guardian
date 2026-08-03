class_name BranchSeedDropDefinition
extends Resource


@export var branch_definition: BranchDefinition

@export_range(0.0, 1.0, 0.0001)
var drop_chance: float = 0.0


func is_valid_definition() -> bool:
	if not is_instance_valid(branch_definition):
		return false

	if not branch_definition.is_valid_definition():
		return false

	if not branch_definition.is_legendary_branch():
		return false

	if drop_chance < 0.0 or drop_chance > 1.0:
		return false

	return true
