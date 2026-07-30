class_name ContentRegistry
extends Resource


@export_category("Branches")

@export var branches: Array[BranchDefinition] = []


@export_category("Tree Souls")

@export var tree_souls: Array[TreeSoulDefinition] = []


@export_category("Enemies")

@export var enemies: Array[EnemyDefinition] = []


@export_category("Stages")

@export var stages: Array[StageDefinition] = []


@export_category("Status Effects")

@export var status_effects: Array[StatusEffectDefinition] = []


var branches_by_id: Dictionary = {}
var tree_souls_by_id: Dictionary = {}
var enemies_by_id: Dictionary = {}
var stages_by_id: Dictionary = {}
var status_effects_by_id: Dictionary = {}

var indexes_ready: bool = false


func rebuild_indexes() -> void:
	branches_by_id.clear()
	tree_souls_by_id.clear()
	enemies_by_id.clear()
	stages_by_id.clear()
	status_effects_by_id.clear()

	index_definitions(
		branches,
		&"branch_id",
		branches_by_id
	)

	index_definitions(
		tree_souls,
		&"tree_soul_id",
		tree_souls_by_id
	)

	index_definitions(
		enemies,
		&"enemy_id",
		enemies_by_id
	)

	index_definitions(
		stages,
		&"stage_id",
		stages_by_id
	)

	index_definitions(
		status_effects,
		&"status_effect_id",
		status_effects_by_id
	)

	indexes_ready = true


func invalidate_indexes() -> void:
	indexes_ready = false


func ensure_indexes() -> void:
	if indexes_ready:
		return

	rebuild_indexes()


func get_branch_definition(
	branch_id: StringName
) -> BranchDefinition:
	ensure_indexes()

	return branches_by_id.get(
		branch_id
	) as BranchDefinition


func get_tree_soul_definition(
	tree_soul_id: StringName
) -> TreeSoulDefinition:
	ensure_indexes()

	return tree_souls_by_id.get(
		tree_soul_id
	) as TreeSoulDefinition


func get_enemy_definition(
	enemy_id: StringName
) -> EnemyDefinition:
	ensure_indexes()

	return enemies_by_id.get(
		enemy_id
	) as EnemyDefinition


func get_stage_definition(
	stage_id: StringName
) -> StageDefinition:
	ensure_indexes()

	return stages_by_id.get(
		stage_id
	) as StageDefinition


func get_status_effect_definition(
	status_effect_id: StringName
) -> StatusEffectDefinition:
	ensure_indexes()

	return status_effects_by_id.get(
		status_effect_id
	) as StatusEffectDefinition


func index_definitions(
	definitions: Array,
	id_property: StringName,
	target_index: Dictionary
) -> void:
	for definition in definitions:
		if not is_instance_valid(definition):
			continue

		var raw_id = definition.get(
			id_property
		)

		if raw_id == null:
			continue

		var definition_id: StringName = (
			StringName(str(raw_id))
		)

		if definition_id == &"":
			continue

		if target_index.has(definition_id):
			push_warning(
				"Duplicate content ID '%s'."
				% definition_id
			)

			continue

		target_index[definition_id] = definition
