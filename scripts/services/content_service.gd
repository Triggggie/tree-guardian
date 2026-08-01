class_name ContentService
extends Node


const DEFAULT_REGISTRY: ContentRegistry = preload(
	"res://resources/content_registry.tres"
)


var registry: ContentRegistry


func _ready() -> void:
	registry = DEFAULT_REGISTRY

	registry.rebuild_indexes()

	var validation_errors: Array[String] = (
		ContentValidator.validate_registry(
			registry
		)
	)

	for validation_error in validation_errors:
		push_error(
			validation_error
		)


func get_branches() -> Array[BranchDefinition]:
	if registry == null:
		return []

	return registry.branches


func get_branch(
	branch_id: StringName
) -> BranchDefinition:
	if registry == null:
		return null

	return registry.get_branch_definition(
		branch_id
	)


func get_upgrades(
	branch_id: StringName
) -> Array[UpgradeDefinition]:
	if registry == null:
		return []

	return registry.get_upgrade_definitions_for_branch(
		branch_id
	)


func get_upgrade(
	branch_id: StringName,
	upgrade_id: StringName
) -> UpgradeDefinition:
	if registry == null:
		return null

	return registry.get_upgrade_definition(
		branch_id,
		upgrade_id
	)


func get_talent_tree(
	talent_tree_id: StringName
) -> TalentTreeDefinition:
	if registry == null:
		return null

	return registry.get_talent_tree_definition(
		talent_tree_id
	)


func get_talents(
	branch_id: StringName
) -> Array[TalentDefinition]:
	if registry == null:
		return []

	return registry.get_talent_definitions_for_branch(
		branch_id
	)


func get_talent(
	branch_id: StringName,
	talent_id: StringName
) -> TalentDefinition:
	if registry == null:
		return null

	return registry.get_talent_definition(
		branch_id,
		talent_id
	)


func get_tree_souls() -> Array[TreeSoulDefinition]:
	if registry == null:
		return []

	return registry.tree_souls


func get_tree_soul(
	tree_soul_id: StringName
) -> TreeSoulDefinition:
	if registry == null:
		return null

	return registry.get_tree_soul_definition(
		tree_soul_id
	)


func get_enemies() -> Array[EnemyDefinition]:
	if registry == null:
		return []

	return registry.enemies


func get_enemy(
	enemy_id: StringName
) -> EnemyDefinition:
	if registry == null:
		return null

	return registry.get_enemy_definition(
		enemy_id
	)


func get_stages() -> Array[StageDefinition]:
	if registry == null:
		return []

	return registry.stages


func get_stage(
	stage_id: StringName
) -> StageDefinition:
	if registry == null:
		return null

	return registry.get_stage_definition(
		stage_id
	)


func get_waves(
	stage_id: StringName
) -> Array[WaveDefinition]:
	if registry == null:
		return []

	return registry.get_wave_definitions_for_stage(
		stage_id
	)


func get_wave(
	stage_id: StringName,
	wave_id: StringName
) -> WaveDefinition:
	if registry == null:
		return null

	return registry.get_wave_definition(
		stage_id,
		wave_id
	)
