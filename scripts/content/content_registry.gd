class_name ContentRegistry
extends Resource


@export_category("Branches")

@export var branches: Array[BranchDefinition] = []


@export_category("Items")

@export var items: Array[ItemDefinition] = []


@export_category("Tree Souls")

@export var tree_souls: Array[TreeSoulDefinition] = []


@export_category("Enemies")

@export var enemies: Array[EnemyDefinition] = []


@export_category("Stages")

@export var stages: Array[StageDefinition] = []


@export_category("Status Effects")

@export var status_effects: Array[StatusEffectDefinition] = []


var branches_by_id: Dictionary = {}
var items_by_id: Dictionary = {}
var upgrades_by_branch_id: Dictionary = {}
var talent_trees_by_id: Dictionary = {}
var talents_by_branch_id: Dictionary = {}
var tree_souls_by_id: Dictionary = {}
var enemies_by_id: Dictionary = {}
var stages_by_id: Dictionary = {}
var waves_by_stage_id: Dictionary = {}
var status_effects_by_id: Dictionary = {}

var indexes_ready: bool = false


func rebuild_indexes() -> void:
	indexes_ready = false

	branches_by_id.clear()
	items_by_id.clear()
	upgrades_by_branch_id.clear()
	talent_trees_by_id.clear()
	talents_by_branch_id.clear()
	tree_souls_by_id.clear()
	enemies_by_id.clear()
	stages_by_id.clear()
	waves_by_stage_id.clear()
	status_effects_by_id.clear()

	index_definitions(
		branches,
		&"branch_id",
		branches_by_id
	)

	index_definitions(
		items,
		&"item_id",
		items_by_id
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

	index_branch_content()
	index_stage_waves()

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


func get_item_definition(
	item_id: StringName
) -> ItemDefinition:
	ensure_indexes()

	return items_by_id.get(
		item_id
	) as ItemDefinition


func get_upgrade_definition(
	branch_id: StringName,
	upgrade_id: StringName
) -> UpgradeDefinition:
	ensure_indexes()

	var scoped_index: Dictionary = (
		upgrades_by_branch_id.get(
			branch_id,
			{}
		)
	)

	return scoped_index.get(
		upgrade_id
	) as UpgradeDefinition


func get_talent_tree_definition(
	talent_tree_id: StringName
) -> TalentTreeDefinition:
	ensure_indexes()

	return talent_trees_by_id.get(
		talent_tree_id
	) as TalentTreeDefinition


func get_talent_definition(
	branch_id: StringName,
	talent_id: StringName
) -> TalentDefinition:
	ensure_indexes()

	var scoped_index: Dictionary = (
		talents_by_branch_id.get(
			branch_id,
			{}
		)
	)

	return scoped_index.get(
		talent_id
	) as TalentDefinition


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


func get_wave_definition(
	stage_id: StringName,
	wave_id: StringName
) -> WaveDefinition:
	ensure_indexes()

	var scoped_index: Dictionary = (
		waves_by_stage_id.get(
			stage_id,
			{}
		)
	)

	return scoped_index.get(
		wave_id
	) as WaveDefinition


func get_status_effect_definition(
	status_effect_id: StringName
) -> StatusEffectDefinition:
	ensure_indexes()

	return status_effects_by_id.get(
		status_effect_id
	) as StatusEffectDefinition


func get_upgrade_definitions_for_branch(
	branch_id: StringName
) -> Array[UpgradeDefinition]:
	var branch_definition: BranchDefinition = (
		get_branch_definition(branch_id)
	)

	if not is_instance_valid(branch_definition):
		return []

	return branch_definition.upgrades


func get_talent_definitions_for_branch(
	branch_id: StringName
) -> Array[TalentDefinition]:
	var branch_definition: BranchDefinition = (
		get_branch_definition(branch_id)
	)

	if not is_instance_valid(branch_definition):
		return []

	if not is_instance_valid(
		branch_definition.talent_tree
	):
		return []

	return branch_definition.talent_tree.talents


func get_wave_definitions_for_stage(
	stage_id: StringName
) -> Array[WaveDefinition]:
	var stage_definition: StageDefinition = (
		get_stage_definition(stage_id)
	)

	if not is_instance_valid(stage_definition):
		return []

	return stage_definition.get_unique_wave_definitions()


func index_branch_content() -> void:
	for branch_definition in branches:
		if not is_instance_valid(branch_definition):
			continue

		var branch_id: StringName = (
			branch_definition.branch_id
		)

		if branch_id == &"":
			continue

		if branches_by_id.get(branch_id) != branch_definition:
			continue

		upgrades_by_branch_id[branch_id] = (
			index_scoped_definitions(
				branch_definition.upgrades,
				&"upgrade_id",
				branch_id,
				"Upgrade",
				"Branch"
			)
		)

		var talent_tree: TalentTreeDefinition = (
			branch_definition.talent_tree
		)

		if not is_instance_valid(talent_tree):
			continue

		var talent_tree_id: StringName = (
			talent_tree.talent_tree_id
		)

		if talent_tree_id != &"":
			if talent_trees_by_id.has(talent_tree_id):
				var indexed_talent_tree: TalentTreeDefinition = (
					talent_trees_by_id.get(
						talent_tree_id
					) as TalentTreeDefinition
				)

				if indexed_talent_tree != talent_tree:
					push_warning(
						(
							"Duplicate Talent Tree ID '%s' "
							+ "in Branch '%s'."
						)
						% [
							talent_tree_id,
							branch_id
						]
					)
			else:
				talent_trees_by_id[
					talent_tree_id
				] = talent_tree

		talents_by_branch_id[branch_id] = (
			index_scoped_definitions(
				talent_tree.talents,
				&"talent_id",
				branch_id,
				"Talent",
				"Branch"
			)
		)


func index_stage_waves() -> void:
	for stage_definition in stages:
		if not is_instance_valid(stage_definition):
			continue

		var stage_id: StringName = (
			stage_definition.stage_id
		)

		if stage_id == &"":
			continue

		if stages_by_id.get(stage_id) != stage_definition:
			continue

		waves_by_stage_id[stage_id] = (
			index_scoped_definitions(
				stage_definition.get_unique_wave_definitions(),
				&"wave_id",
				stage_id,
				"Wave",
				"Stage"
			)
		)


func index_scoped_definitions(
	definitions: Array,
	id_property: StringName,
	owner_id: StringName,
	content_kind: String,
	owner_kind: String
) -> Dictionary:
	var scoped_index: Dictionary = {}

	if owner_id == &"":
		return scoped_index

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

		if scoped_index.has(definition_id):
			push_warning(
				"Duplicate %s ID '%s' in %s '%s'."
				% [
					content_kind,
					definition_id,
					owner_kind,
					owner_id
				]
			)

			continue

		scoped_index[definition_id] = definition

	return scoped_index


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
