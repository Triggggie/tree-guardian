class_name ContentValidator
extends RefCounted


static func validate_registry(
	registry: ContentRegistry
) -> Array[String]:
	var errors: Array[String] = []

	if registry == null:
		errors.append(
			"Content registry is missing."
		)

		return errors

	validate_definition_list(
		"Branch",
		registry.branches,
		&"branch_id",
		errors
	)

	validate_definition_list(
		"Tree Soul",
		registry.tree_souls,
		&"tree_soul_id",
		errors
	)

	validate_definition_list(
		"Enemy",
		registry.enemies,
		&"enemy_id",
		errors
	)

	validate_definition_list(
		"Stage",
		registry.stages,
		&"stage_id",
		errors
	)

	validate_definition_list(
		"Status Effect",
		registry.status_effects,
		&"status_effect_id",
		errors
	)

	validate_branch_content(
		registry,
		errors
	)

	validate_global_talent_tree_ids(
		registry,
		errors
	)

	validate_stage_content(
		registry,
		errors
	)

	validate_wave_enemy_references(
		registry,
		errors
	)

	validate_enemy_immunity_references(
		registry,
		errors
	)

	return remove_duplicate_errors(errors)


static func validate_definition_list(
	definition_type_name: String,
	definitions: Array,
	id_property: StringName,
	errors: Array[String]
) -> void:
	var used_ids: Dictionary = {}

	for definition_index in range(
		definitions.size()
	):
		var definition = definitions[
			definition_index
		]

		if not is_instance_valid(definition):
			errors.append(
				"%s entry %d is empty."
				% [
					definition_type_name,
					definition_index
				]
			)

			continue

		if not definition.has_method(
			"is_valid_definition"
		):
			errors.append(
				"%s entry %d has no validation method."
				% [
					definition_type_name,
					definition_index
				]
			)

			continue

		if not bool(
			definition.call(
				"is_valid_definition"
			)
		):
			errors.append(
				"%s entry %d is invalid."
				% [
					definition_type_name,
					definition_index
				]
			)

		var raw_id = definition.get(
			id_property
		)

		var definition_id: StringName = (
			StringName(str(raw_id))
		)

		if definition_id == &"":
			continue

		if used_ids.has(definition_id):
			errors.append(
				"Duplicate %s ID '%s'."
				% [
					definition_type_name,
					definition_id
				]
			)

			continue

		used_ids[definition_id] = true


static func validate_branch_content(
	registry: ContentRegistry,
	errors: Array[String]
) -> void:
	for branch_index in range(
		registry.branches.size()
	):
		var branch: BranchDefinition = (
			registry.branches[branch_index]
		)

		if not is_instance_valid(branch):
			continue

		var branch_label: String = (
			get_branch_label(
				branch,
				branch_index
			)
		)

		if branch.branch_id == &"":
			errors.append(
				"Branch entry %d has an empty branch ID."
				% branch_index
			)

		if branch.display_name.strip_edges().is_empty():
			errors.append(
				"%s has an empty display name."
				% branch_label
			)

		if not is_instance_valid(branch.branch_scene):
			errors.append(
				"%s has no branch scene."
				% branch_label
			)

		if not is_instance_valid(branch.targeting_profile):
			errors.append(
				"%s has no targeting profile."
				% branch_label
			)
		elif not branch.targeting_profile.is_valid_definition():
			errors.append(
				"%s has an invalid targeting profile."
				% branch_label
			)

		validate_branch_upgrades(
			branch,
			branch_label,
			errors
		)

		if is_instance_valid(branch.talent_tree):
			validate_talent_tree_content(
				branch.talent_tree,
				branch_label,
				errors
			)


static func validate_branch_upgrades(
	branch: BranchDefinition,
	branch_label: String,
	errors: Array[String]
) -> void:
	var used_upgrade_ids: Dictionary = {}

	for upgrade_index in range(
		branch.upgrades.size()
	):
		var upgrade: UpgradeDefinition = (
			branch.upgrades[upgrade_index]
		)

		if not is_instance_valid(upgrade):
			errors.append(
				(
					"%s has an empty Upgrade entry "
					+ "at index %d."
				)
				% [
					branch_label,
					upgrade_index
				]
			)

			continue

		if not upgrade.is_valid_definition():
			errors.append(
				"Upgrade entry %d in %s is invalid."
				% [
					upgrade_index,
					branch_label
				]
			)

		if upgrade.upgrade_id == &"":
			errors.append(
				(
					"Upgrade entry %d in %s "
					+ "has an empty ID."
				)
				% [
					upgrade_index,
					branch_label
				]
			)

			continue

		if used_upgrade_ids.has(upgrade.upgrade_id):
			errors.append(
				"Duplicate Upgrade ID '%s' in %s."
				% [
					upgrade.upgrade_id,
					branch_label
				]
			)

			continue

		used_upgrade_ids[upgrade.upgrade_id] = true


static func validate_talent_tree_content(
	talent_tree: TalentTreeDefinition,
	branch_label: String,
	errors: Array[String]
) -> void:
	var talent_tree_label: String = (
		get_talent_tree_label(
			talent_tree,
			branch_label
		)
	)

	if talent_tree.talent_tree_id == &"":
		errors.append(
			"Talent Tree in %s has an empty ID."
			% branch_label
		)

	if talent_tree.display_name.strip_edges().is_empty():
		errors.append(
			"%s has an empty display name."
			% talent_tree_label
		)

	if talent_tree.talents.is_empty():
		errors.append(
			"%s has no talents."
			% talent_tree_label
		)

	var talents_by_id: Dictionary = {}

	for talent_index in range(
		talent_tree.talents.size()
	):
		var talent: TalentDefinition = (
			talent_tree.talents[talent_index]
		)

		if not is_instance_valid(talent):
			errors.append(
				(
					"%s has an empty Talent entry "
					+ "at index %d."
				)
				% [
					talent_tree_label,
					talent_index
				]
			)

			continue

		var talent_label: String = (
			get_talent_label(
				talent,
				talent_index,
				talent_tree_label
			)
		)

		if not talent.is_valid_definition():
			if talent.talent_id == &"":
				errors.append(
					"Talent entry %d in %s is invalid."
					% [
						talent_index,
						talent_tree_label
					]
				)
			else:
				errors.append(
					"%s in %s is invalid."
					% [
						talent_label,
						talent_tree_label
					]
				)

		if talent.talent_id == &"":
			errors.append(
				"Talent entry %d in %s has an empty ID."
				% [
					talent_index,
					talent_tree_label
				]
			)
		elif talents_by_id.has(talent.talent_id):
			errors.append(
				"Duplicate Talent ID '%s' in %s."
				% [
					talent.talent_id,
					talent_tree_label
				]
			)
		else:
			talents_by_id[talent.talent_id] = talent

		if talent.display_name.strip_edges().is_empty():
			errors.append(
				"%s has an empty display name."
				% talent_label
			)

		if talent.required_branch_level < 1:
			errors.append(
				"%s has a required Branch Level below 1."
				% talent_label
			)

		if talent.talent_point_cost < 1:
			errors.append(
				"%s has a Talent Point cost below 1."
				% talent_label
			)

	for talent_index in range(
		talent_tree.talents.size()
	):
		var talent: TalentDefinition = (
			talent_tree.talents[talent_index]
		)

		if not is_instance_valid(talent):
			continue

		var talent_label: String = (
			get_talent_label(
				talent,
				talent_index,
				talent_tree_label
			)
		)

		validate_talent_relationships(
			talent,
			talent_label,
			talents_by_id,
			errors
		)

	validate_talent_prerequisite_cycles(
		talent_tree,
		errors
	)


static func validate_talent_relationships(
	talent: TalentDefinition,
	talent_label: String,
	talents_by_id: Dictionary,
	errors: Array[String]
) -> void:
	var prerequisite_ids: Dictionary = {}

	for prerequisite_id in talent.prerequisite_ids:
		if prerequisite_id == &"":
			errors.append(
				"%s has an empty prerequisite ID."
				% talent_label
			)

			continue

		if prerequisite_ids.has(prerequisite_id):
			errors.append(
				"%s has duplicate prerequisite '%s'."
				% [
					talent_label,
					prerequisite_id
				]
			)

			continue

		prerequisite_ids[prerequisite_id] = true

		if prerequisite_id == talent.talent_id:
			errors.append(
				"%s cannot require itself."
				% talent_label
			)
		elif not talents_by_id.has(prerequisite_id):
			errors.append(
				(
					"%s references missing prerequisite "
					+ "'%s'."
				)
				% [
					talent_label,
					prerequisite_id
				]
			)

	var conflicting_ids: Dictionary = {}
	var overlapping_ids: Dictionary = {}

	for conflicting_id in talent.conflicting_ids:
		if conflicting_id == &"":
			errors.append(
				"%s has an empty conflict ID."
				% talent_label
			)

			continue

		if conflicting_ids.has(conflicting_id):
			errors.append(
				"%s has duplicate conflict '%s'."
				% [
					talent_label,
					conflicting_id
				]
			)

			continue

		conflicting_ids[conflicting_id] = true

		if conflicting_id == talent.talent_id:
			errors.append(
				"%s cannot conflict with itself."
				% talent_label
			)
		elif not talents_by_id.has(conflicting_id):
			errors.append(
				"%s references missing conflict '%s'."
				% [
					talent_label,
					conflicting_id
				]
			)

		if (
			prerequisite_ids.has(conflicting_id)
			and not overlapping_ids.has(conflicting_id)
		):
			errors.append(
				(
					"%s both requires and conflicts "
					+ "with '%s'."
				)
				% [
					talent_label,
					conflicting_id
				]
			)

			overlapping_ids[conflicting_id] = true


static func validate_talent_prerequisite_cycles(
	talent_tree: TalentTreeDefinition,
	errors: Array[String]
) -> void:
	var talents_by_id: Dictionary = {}

	for talent in talent_tree.talents:
		if not is_instance_valid(talent):
			continue

		if talent.talent_id == &"":
			continue

		if talents_by_id.has(talent.talent_id):
			continue

		talents_by_id[talent.talent_id] = talent

	var visit_states: Dictionary = {}
	var path: Array[StringName] = []
	var reported_cycles: Dictionary = {}

	for talent in talent_tree.talents:
		if not is_instance_valid(talent):
			continue

		if talent.talent_id == &"":
			continue

		if int(visit_states.get(talent.talent_id, 0)) != 0:
			continue

		visit_talent_prerequisites(
			talent.talent_id,
			talents_by_id,
			visit_states,
			path,
			reported_cycles,
			talent_tree.talent_tree_id,
			errors
		)


static func visit_talent_prerequisites(
	talent_id: StringName,
	talents_by_id: Dictionary,
	visit_states: Dictionary,
	path: Array[StringName],
	reported_cycles: Dictionary,
	talent_tree_id: StringName,
	errors: Array[String]
) -> void:
	visit_states[talent_id] = 1
	path.append(talent_id)

	var talent: TalentDefinition = (
		talents_by_id.get(talent_id) as TalentDefinition
	)

	if is_instance_valid(talent):
		for prerequisite_id in talent.prerequisite_ids:
			if prerequisite_id == talent_id:
				continue

			if not talents_by_id.has(prerequisite_id):
				continue

			var prerequisite_state: int = int(
				visit_states.get(
					prerequisite_id,
					0
				)
			)

			if prerequisite_state == 0:
				visit_talent_prerequisites(
					prerequisite_id,
					talents_by_id,
					visit_states,
					path,
					reported_cycles,
					talent_tree_id,
					errors
				)
			elif prerequisite_state == 1:
				report_talent_prerequisite_cycle(
					prerequisite_id,
					path,
					reported_cycles,
					talent_tree_id,
					errors
				)

	path.pop_back()
	visit_states[talent_id] = 2


static func report_talent_prerequisite_cycle(
	cycle_start_id: StringName,
	path: Array[StringName],
	reported_cycles: Dictionary,
	talent_tree_id: StringName,
	errors: Array[String]
) -> void:
	var cycle_start_index: int = path.find(
		cycle_start_id
	)

	if cycle_start_index < 0:
		return

	var cycle_parts: PackedStringArray = PackedStringArray()

	for path_index in range(
		cycle_start_index,
		path.size()
	):
		cycle_parts.append(
			str(path[path_index])
		)

	cycle_parts.append(
		str(cycle_start_id)
	)

	var cycle_key: String = "|".join(
		cycle_parts
	)

	if reported_cycles.has(cycle_key):
		return

	reported_cycles[cycle_key] = true

	var talent_tree_id_text: String = str(
		talent_tree_id
	)

	if talent_tree_id_text.is_empty():
		talent_tree_id_text = "<empty>"

	errors.append(
		(
			"Talent Tree '%s' has a prerequisite cycle: "
			+ "%s."
		)
		% [
			talent_tree_id_text,
			" -> ".join(cycle_parts)
		]
	)


static func validate_global_talent_tree_ids(
	registry: ContentRegistry,
	errors: Array[String]
) -> void:
	var talent_trees_by_id: Dictionary = {}

	for branch in registry.branches:
		if not is_instance_valid(branch):
			continue

		var talent_tree: TalentTreeDefinition = (
			branch.talent_tree
		)

		if not is_instance_valid(talent_tree):
			continue

		if talent_tree.talent_tree_id == &"":
			continue

		if not talent_trees_by_id.has(
			talent_tree.talent_tree_id
		):
			talent_trees_by_id[
				talent_tree.talent_tree_id
			] = talent_tree

			continue

		var indexed_talent_tree: TalentTreeDefinition = (
			talent_trees_by_id.get(
				talent_tree.talent_tree_id
			) as TalentTreeDefinition
		)

		if indexed_talent_tree == talent_tree:
			continue

		errors.append(
			(
				"Duplicate Talent Tree ID '%s' is used "
				+ "by multiple different resources."
			)
			% talent_tree.talent_tree_id
		)


static func validate_stage_content(
	registry: ContentRegistry,
	errors: Array[String]
) -> void:
	for stage_index in range(
		registry.stages.size()
	):
		var stage: StageDefinition = (
			registry.stages[stage_index]
		)

		if not is_instance_valid(stage):
			continue

		var stage_label: String = (
			get_stage_label(
				stage,
				stage_index
			)
		)

		if stage.stage_id == &"":
			errors.append(
				"Stage entry %d has an empty stage ID."
				% stage_index
			)

		if stage.display_name.strip_edges().is_empty():
			errors.append(
				"%s has an empty display name."
				% stage_label
			)

		if stage.waves.is_empty():
			errors.append(
				"%s has no waves."
				% stage_label
			)

		if stage.wave_count < 1:
			errors.append(
				"%s has a wave count below 1."
				% stage_label
			)

		if stage.enemies_per_side_increase_interval < 1:
			errors.append(
				(
					"%s has an enemy increase "
					+ "interval below 1."
				)
				% stage_label
			)

		if stage.maximum_enemies_per_side < 1:
			errors.append(
				(
					"%s has maximum enemies "
					+ "per side below 1."
				)
				% stage_label
			)

		if stage.health_increase_per_global_wave < 0.0:
			errors.append(
				(
					"%s has a negative health increase "
					+ "per global wave."
				)
				% stage_label
			)

		if stage.maximum_enemy_health < 1.0:
			errors.append(
				(
					"%s has maximum enemy health "
					+ "below 1."
				)
				% stage_label
			)

		if stage.completion_essence_reward < 0:
			errors.append(
				(
					"%s has a negative completion "
					+ "Essence reward."
				)
				% stage_label
			)

		validate_stage_waves(
			stage,
			stage_label,
			errors
		)


static func validate_stage_waves(
	stage: StageDefinition,
	stage_label: String,
	errors: Array[String]
) -> void:
	var used_wave_ids: Dictionary = {}

	for wave_index in range(
		stage.waves.size()
	):
		var wave: WaveDefinition = (
			stage.waves[wave_index]
		)

		if not is_instance_valid(wave):
			errors.append(
				(
					"%s has an empty Wave entry "
					+ "at index %d."
				)
				% [
					stage_label,
					wave_index
				]
			)

			continue

		var wave_label: String = (
			get_wave_label(
				wave,
				wave_index,
				stage_label
			)
		)

		if not wave.is_valid_definition():
			if wave.wave_id == &"":
				errors.append(
					"Wave entry %d in %s is invalid."
					% [
						wave_index,
						stage_label
					]
				)
			else:
				errors.append(
					"%s in %s is invalid."
					% [
						wave_label,
						stage_label
					]
				)

		if wave.wave_id == &"":
			errors.append(
				"Wave entry %d in %s has an empty ID."
				% [
					wave_index,
					stage_label
				]
			)
		elif used_wave_ids.has(wave.wave_id):
			errors.append(
				"Duplicate Wave ID '%s' in %s."
				% [
					wave.wave_id,
					stage_label
				]
			)
		else:
			used_wave_ids[wave.wave_id] = true

		if wave.display_name.strip_edges().is_empty():
			errors.append(
				"%s has an empty display name."
				% wave_label
			)

		if wave.enemy_ids.is_empty():
			errors.append(
				"%s has no enemy IDs."
				% wave_label
			)

		if wave.enemy_ids.size() != wave.enemies_per_side.size():
			errors.append(
				(
					"%s has mismatched enemy ID "
					+ "and count arrays."
				)
				% wave_label
			)

		if wave.spawn_interval < 0.0:
			errors.append(
				"%s has a negative spawn interval."
				% wave_label
			)

		if wave.health_multiplier <= 0.0:
			errors.append(
				"%s has a non-positive health multiplier."
				% wave_label
			)

		if wave.damage_multiplier <= 0.0:
			errors.append(
				"%s has a non-positive damage multiplier."
				% wave_label
			)

		if wave.completion_message_duration < 0.0:
			errors.append(
				(
					"%s has a negative completion "
					+ "message duration."
				)
				% wave_label
			)

		if wave.time_after_wave < 0.0:
			errors.append(
				"%s has a negative time after wave."
				% wave_label
			)

		validate_wave_enemy_entries(
			wave,
			wave_label,
			errors
		)


static func validate_wave_enemy_entries(
	wave: WaveDefinition,
	wave_label: String,
	errors: Array[String]
) -> void:
	var used_enemy_ids: Dictionary = {}
	var shared_entry_count: int = min(
		wave.enemy_ids.size(),
		wave.enemies_per_side.size()
	)

	for enemy_index in range(shared_entry_count):
		var enemy_id: StringName = (
			wave.enemy_ids[enemy_index]
		)

		var enemy_count: int = (
			wave.enemies_per_side[enemy_index]
		)

		if enemy_id == &"":
			errors.append(
				"%s has an empty enemy ID at index %d."
				% [
					wave_label,
					enemy_index
				]
			)
		elif used_enemy_ids.has(enemy_id):
			errors.append(
				"%s has duplicate enemy ID '%s'."
				% [
					wave_label,
					enemy_id
				]
			)
		else:
			used_enemy_ids[enemy_id] = true

		if enemy_count < 1:
			errors.append(
				"%s has invalid enemy count %d for '%s'."
				% [
					wave_label,
					enemy_count,
					enemy_id
				]
			)


static func get_branch_label(
	branch: BranchDefinition,
	branch_index: int
) -> String:
	if branch.branch_id != &"":
		return "Branch '%s'" % branch.branch_id

	return "Branch entry %d" % branch_index


static func get_talent_tree_label(
	talent_tree: TalentTreeDefinition,
	branch_label: String
) -> String:
	if talent_tree.talent_tree_id != &"":
		return (
			"Talent Tree '%s'"
			% talent_tree.talent_tree_id
		)

	return "Talent Tree in %s" % branch_label


static func get_talent_label(
	talent: TalentDefinition,
	talent_index: int,
	talent_tree_label: String
) -> String:
	if talent.talent_id != &"":
		return "Talent '%s'" % talent.talent_id

	return (
		"Talent entry %d in %s"
		% [
			talent_index,
			talent_tree_label
		]
	)


static func get_stage_label(
	stage: StageDefinition,
	stage_index: int
) -> String:
	if stage.stage_id != &"":
		return "Stage '%s'" % stage.stage_id

	return "Stage entry %d" % stage_index


static func get_wave_label(
	wave: WaveDefinition,
	wave_index: int,
	stage_label: String
) -> String:
	if wave.wave_id != &"":
		return "Wave '%s'" % wave.wave_id

	return (
		"Wave entry %d in %s"
		% [
			wave_index,
			stage_label
		]
	)


static func validate_wave_enemy_references(
	registry: ContentRegistry,
	errors: Array[String]
) -> void:
	var enemy_ids: Dictionary = collect_ids(
		registry.enemies,
		&"enemy_id"
	)

	for stage in registry.stages:
		if not is_instance_valid(stage):
			continue

		for wave in stage.waves:
			if not is_instance_valid(wave):
				continue

			for enemy_id in wave.enemy_ids:
				if enemy_ids.has(enemy_id):
					continue

				errors.append(
					"Wave '%s' references missing enemy '%s'."
					% [
						wave.wave_id,
						enemy_id
					]
				)


static func validate_enemy_immunity_references(
	registry: ContentRegistry,
	errors: Array[String]
) -> void:
	var status_effect_ids: Dictionary = (
		collect_ids(
			registry.status_effects,
			&"status_effect_id"
		)
	)

	for enemy in registry.enemies:
		if not is_instance_valid(enemy):
			continue

		for status_effect_id in (
			enemy.immune_status_effect_ids
		):
			if status_effect_ids.has(
				status_effect_id
			):
				continue

			errors.append(
				"Enemy '%s' references missing "
				+ "status effect '%s'."
				% [
					enemy.enemy_id,
					status_effect_id
				]
			)


static func collect_ids(
	definitions: Array,
	id_property: StringName
) -> Dictionary:
	var collected_ids: Dictionary = {}

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

		collected_ids[definition_id] = true

	return collected_ids


static func remove_duplicate_errors(
	errors: Array[String]
) -> Array[String]:
	var unique_errors: Dictionary = {}
	var deduplicated_errors: Array[String] = []

	for error in errors:
		if unique_errors.has(error):
			continue

		unique_errors[error] = true
		deduplicated_errors.append(error)

	return deduplicated_errors
