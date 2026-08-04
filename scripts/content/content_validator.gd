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

	validate_enemy_content(
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


static func validate_enemy_content(
	registry: ContentRegistry,
	errors: Array[String]
) -> void:
	for enemy_index in range(registry.enemies.size()):
		var enemy: EnemyDefinition = registry.enemies[enemy_index]
		if not is_instance_valid(enemy):
			continue
		var enemy_label: String = (
			"Enemy '%s'" % enemy.enemy_id
			if enemy.enemy_id != &""
			else "Enemy entry %d" % enemy_index
		)

		if enemy.encounter_rank_id not in [
			EnemyDefinition.ENCOUNTER_RANK_NORMAL,
			EnemyDefinition.ENCOUNTER_RANK_MINIBOSS,
			EnemyDefinition.ENCOUNTER_RANK_BOSS
		]:
			errors.append("%s has an invalid encounter rank." % enemy_label)

		if (
			enemy.branch_seed_roll_chance < 0.0
			or enemy.branch_seed_roll_chance > 1.0
		):
			errors.append("%s has an invalid Branch Seed roll chance." % enemy_label)

		if enemy.branch_seed_pity_points < 0:
			errors.append("%s has negative Branch Seed pity points." % enemy_label)

		if enemy.is_normal_enemy() and (
			enemy.branch_seed_roll_chance != 0.0
			or enemy.branch_seed_pity_points != 0
		):
			errors.append(
				"%s is normal and cannot grant Branch Seed rolls or pity."
				% enemy_label
			)


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

		if branch.is_standard_branch() and (
			branch.get_legendary_tier()
			!= BranchDefinition.LEGENDARY_TIER_NONE
		):
			errors.append("%s is standard and must use Tier 0." % branch_label)

		if branch.is_legendary_branch() and (
			branch.get_legendary_tier() not in [
				BranchDefinition.LEGENDARY_TIER_1,
				BranchDefinition.LEGENDARY_TIER_2,
				BranchDefinition.LEGENDARY_TIER_3
			]
		):
			errors.append("%s is legendary and must use Tier I-III." % branch_label)
		elif branch.is_legendary_branch() and (
			branch.get_legendary_tier_display_name().is_empty()
		):
			errors.append("%s has no player-facing Legendary Tier text." % branch_label)

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

		if (
			stage.get_substage_count()
			!= stage.get_required_substage_count()
		):
			errors.append(
				(
					"%s must contain exactly %d Substages."
				)
				% [
					stage_label,
					stage.get_required_substage_count()
				]
			)

		if stage.health_growth_per_stage_wave < 0.0:
			errors.append(
				(
					"%s has negative health growth "
					+ "per Stage Wave."
				)
				% stage_label
			)

		if stage.damage_growth_per_stage_wave < 0.0:
			errors.append(
				(
					"%s has negative damage growth "
					+ "per Stage Wave."
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

		validate_stage_branch_seed_loot_pool(
			registry,
			stage,
			stage_label,
			errors
		)

		validate_stage_substages(
			stage,
			stage_label,
			errors
		)


static func validate_stage_branch_seed_loot_pool(
	registry: ContentRegistry,
	stage: StageDefinition,
	stage_label: String,
	errors: Array[String]
) -> void:
	var loot_pool: BranchSeedLootPoolDefinition = (
		stage.get_branch_seed_loot_pool()
	)
	if not is_instance_valid(loot_pool):
		return

	if not loot_pool.is_valid_definition():
		errors.append("%s has an invalid Branch Seed loot pool." % stage_label)

	var registered_branches_by_id: Dictionary = {}
	for registered_branch in registry.branches:
		if is_instance_valid(registered_branch):
			registered_branches_by_id[registered_branch.branch_id] = registered_branch

	var used_branch_ids: Dictionary = {}
	for entry_index in range(loot_pool.entries.size()):
		var entry: BranchSeedLootEntryDefinition = loot_pool.entries[entry_index]
		if not is_instance_valid(entry):
			errors.append(
				"%s loot pool has an empty entry at index %d."
				% [stage_label, entry_index]
			)
			continue

		var branch: BranchDefinition = entry.branch_definition
		if not is_instance_valid(branch):
			errors.append("%s loot entry has no Branch definition." % stage_label)
			continue

		var branch_id: StringName = branch.branch_id
		if used_branch_ids.has(branch_id):
			errors.append(
				"%s loot pool duplicates Branch '%s'." % [stage_label, branch_id]
			)
		else:
			used_branch_ids[branch_id] = true

		var registered_branch: BranchDefinition = (
			registered_branches_by_id.get(branch_id) as BranchDefinition
		)
		if not is_instance_valid(registered_branch) or registered_branch != branch:
			errors.append(
				"%s loot pool references unregistered Branch '%s'."
				% [stage_label, branch_id]
			)

		if not branch.is_legendary_branch() or (
			branch.get_legendary_tier() not in [
				BranchDefinition.LEGENDARY_TIER_1,
				BranchDefinition.LEGENDARY_TIER_2,
				BranchDefinition.LEGENDARY_TIER_3
			]
		):
			errors.append(
				"%s loot pool Branch '%s' is not a valid Legendary Tier I-III Branch."
				% [stage_label, branch_id]
			)


static func validate_stage_substages(
	stage: StageDefinition,
	stage_label: String,
	errors: Array[String]
) -> void:
	var used_substage_ids: Dictionary = {}
	var used_wave_ids: Dictionary = {}
	var validated_wave_instance_ids: Dictionary = {}

	for substage_index in range(
		stage.substages.size()
	):
		var substage: SubstageDefinition = (
			stage.substages[substage_index]
		)

		if not is_instance_valid(substage):
			errors.append(
				(
					"%s has an empty Substage entry "
					+ "at index %d."
				)
				% [
					stage_label,
					substage_index
				]
			)

			continue

		var substage_label: String = (
			get_substage_label(
				substage,
				substage_index,
				stage_label
			)
		)

		if not substage.is_valid_definition():
			if substage.substage_id == &"":
				errors.append(
					"Substage entry %d in %s is invalid."
					% [
						substage_index,
						stage_label
					]
				)
			else:
				errors.append(
					"%s in %s is invalid."
					% [
						substage_label,
						stage_label
					]
				)

		if substage.substage_id == &"":
			errors.append(
				"Substage entry %d in %s has an empty ID."
				% [
					substage_index,
					stage_label
				]
			)
		elif used_substage_ids.has(substage.substage_id):
			errors.append(
				"Duplicate Substage ID '%s' in %s."
				% [
					substage.substage_id,
					stage_label
				]
			)
		else:
			used_substage_ids[
				substage.substage_id
			] = substage

		if substage.display_name.strip_edges().is_empty():
			errors.append(
				"%s has an empty display name."
				% substage_label
			)

		if substage.completion_essence_reward < 0:
			errors.append(
				(
					"%s has a negative completion "
					+ "Essence reward."
				)
				% substage_label
			)

		validate_substage_completion_effect_ids(
			substage,
			substage_label,
			errors
		)

		validate_substage_wave_schedule(
			substage,
			substage_label,
			used_wave_ids,
			validated_wave_instance_ids,
			errors
		)


static func validate_substage_completion_effect_ids(
	substage: SubstageDefinition,
	substage_label: String,
	errors: Array[String]
) -> void:
	var used_effect_ids: Dictionary = {}

	for effect_index in range(
		substage.completion_effect_ids.size()
	):
		var effect_id: StringName = (
			substage.completion_effect_ids[effect_index]
		)

		if effect_id == &"":
			errors.append(
				(
					"%s has an empty completion effect ID "
					+ "at index %d."
				)
				% [
					substage_label,
					effect_index
				]
			)
		elif used_effect_ids.has(effect_id):
			errors.append(
				(
					"%s has duplicate completion effect ID '%s'."
				)
				% [
					substage_label,
					effect_id
				]
			)
		else:
			used_effect_ids[effect_id] = true


static func validate_substage_wave_schedule(
	substage: SubstageDefinition,
	substage_label: String,
	used_wave_ids: Dictionary,
	validated_wave_instance_ids: Dictionary,
	errors: Array[String]
) -> void:
	var schedule: SubstageWaveScheduleDefinition = (
		substage.wave_schedule
	)

	if not is_instance_valid(schedule):
		errors.append(
			"%s has no Wave schedule."
			% substage_label
		)
		return

	var schedule_label: String = (
		"Wave schedule '%s'"
		% schedule.schedule_id
	)

	if not schedule.is_valid_definition():
		errors.append(
			"%s in %s is invalid."
			% [
				schedule_label,
				substage_label
			]
		)

	if schedule.schedule_id == &"":
		errors.append(
			"Wave schedule in %s has an empty ID."
			% substage_label
		)

	if schedule.display_name.strip_edges().is_empty():
		errors.append(
			"%s in %s has an empty display name."
			% [
				schedule_label,
				substage_label
			]
		)

	if schedule.entries.is_empty():
		errors.append(
			"%s in %s has no entries."
			% [
				schedule_label,
				substage_label
			]
		)
		return

	var expected_start_wave: int = 1
	var previous_start_wave: int = 0
	var schedule_waves_by_id: Dictionary = {}

	for entry_index in range(schedule.entries.size()):
		var entry: SubstageWaveScheduleEntryDefinition = (
			schedule.entries[entry_index]
		)

		if not is_instance_valid(entry):
			errors.append(
				(
					"%s in %s has an empty entry "
					+ "at index %d."
				)
				% [
					schedule_label,
					substage_label,
					entry_index
				]
			)
			continue

		if entry.start_wave < 1 or entry.start_wave > 100:
			errors.append(
				"Schedule entry %d in %s has start Wave outside 1-100."
				% [
					entry_index,
					schedule_label
				]
			)

		if entry.end_wave < 1 or entry.end_wave > 100:
			errors.append(
				"Schedule entry %d in %s has end Wave outside 1-100."
				% [
					entry_index,
					schedule_label
				]
			)

		if entry.start_wave > entry.end_wave:
			errors.append(
				"Schedule entry %d in %s starts after it ends."
				% [
					entry_index,
					schedule_label
				]
			)

		if entry_index == 0 and entry.start_wave != 1:
			errors.append(
				"%s in %s does not begin at Wave 1."
				% [
					schedule_label,
					substage_label
				]
			)
		elif entry_index > 0:
			if entry.start_wave < previous_start_wave:
				errors.append(
					"Schedule entry %d in %s is out of order."
					% [
						entry_index,
						schedule_label
					]
				)

			if entry.start_wave > expected_start_wave:
				errors.append(
					"%s in %s has a gap before Wave %d."
					% [
						schedule_label,
						substage_label,
						entry.start_wave
					]
				)
			elif entry.start_wave < expected_start_wave:
				errors.append(
					"%s in %s overlaps at Wave %d."
					% [
						schedule_label,
						substage_label,
						entry.start_wave
					]
				)

		previous_start_wave = entry.start_wave
		expected_start_wave = entry.end_wave + 1

		var wave: WaveDefinition = entry.wave_definition

		if not is_instance_valid(wave):
			errors.append(
				"Schedule entry %d in %s has no WaveDefinition."
				% [
					entry_index,
					schedule_label
				]
			)
			continue

		if not wave.is_valid_definition():
			errors.append(
				"Schedule entry %d in %s has an invalid WaveDefinition."
				% [
					entry_index,
					schedule_label
				]
			)

		if schedule_waves_by_id.has(wave.wave_id):
			var scheduled_wave: WaveDefinition = (
				schedule_waves_by_id.get(
					wave.wave_id
				) as WaveDefinition
			)

			if scheduled_wave != wave:
				errors.append(
					(
						"Conflicting Wave ID '%s' in %s uses "
						+ "multiple different resources."
					)
					% [
						wave.wave_id,
						schedule_label
					]
				)
		else:
			schedule_waves_by_id[wave.wave_id] = wave

		if wave.wave_id == &"":
			errors.append(
				"Schedule entry %d in %s has a Wave with an empty ID."
				% [
					entry_index,
					schedule_label
				]
			)
		elif used_wave_ids.has(wave.wave_id):
			var indexed_wave: WaveDefinition = (
				used_wave_ids.get(
					wave.wave_id
				) as WaveDefinition
			)

			if indexed_wave != wave:
				errors.append(
					(
						"Conflicting Wave ID '%s' in %s uses "
						+ "multiple different resources."
					)
					% [
						wave.wave_id,
						substage_label
					]
				)
		else:
			used_wave_ids[wave.wave_id] = wave

		var wave_instance_id: int = wave.get_instance_id()

		if validated_wave_instance_ids.has(wave_instance_id):
			continue

		validated_wave_instance_ids[wave_instance_id] = true

		validate_wave_content(
			wave,
			entry.start_wave - 1,
			schedule_label,
			errors
		)

	var last_entry: SubstageWaveScheduleEntryDefinition = (
		schedule.entries.back()
	)

	if (
		is_instance_valid(last_entry)
		and last_entry.end_wave != 100
	):
		errors.append(
			"%s in %s does not end at Wave 100."
			% [
				schedule_label,
				substage_label
			]
		)


static func validate_wave_content(
	wave: WaveDefinition,
	wave_index: int,
	owner_label: String,
	errors: Array[String]
) -> void:
	var wave_label: String = get_wave_label(
		wave,
		wave_index,
		owner_label
	)

	if not wave.is_valid_definition():
		if wave.wave_id == &"":
			errors.append(
				"Wave pattern %d in %s is invalid."
				% [
					wave_index,
					owner_label
				]
			)
		else:
			errors.append(
				"%s in %s is invalid."
				% [
					wave_label,
					owner_label
				]
			)

	if wave.display_name.strip_edges().is_empty():
		errors.append(
			"%s has an empty display name."
			% wave_label
		)

	if wave.enemy_entries.is_empty():
		errors.append(
			"%s has no enemy entries."
			% wave_label
		)

	if wave.spawn_interval < 0.0:
		errors.append(
			"%s has a negative spawn interval."
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

	for enemy_index in range(
		wave.enemy_entries.size()
	):
		var enemy_entry: WaveEnemyEntryDefinition = (
			wave.enemy_entries[enemy_index]
		)

		if not is_instance_valid(enemy_entry):
			errors.append(
				"%s has an empty enemy entry at index %d."
				% [
					wave_label,
					enemy_index
				]
			)
			continue

		var enemy_id: StringName = enemy_entry.enemy_id

		if not enemy_entry.is_valid_definition():
			errors.append(
				"Enemy entry %d in %s is invalid."
				% [
					enemy_index,
					wave_label
				]
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

		if enemy_entry.base_count_per_side < 1:
			errors.append(
				"%s has a base count below 1 for '%s'."
				% [
					wave_label,
					enemy_id
				]
			)

		if enemy_entry.count_scaling_start_stage_wave < 1:
			errors.append(
				(
					"%s has a count scaling start below 1 "
					+ "for '%s'."
				)
				% [
					wave_label,
					enemy_id
				]
			)

		if enemy_entry.count_increase_interval < 0:
			errors.append(
				"%s has a negative count interval for '%s'."
				% [
					wave_label,
					enemy_id
				]
			)

		if enemy_entry.count_increase_amount < 0:
			errors.append(
				"%s has a negative count amount for '%s'."
				% [
					wave_label,
					enemy_id
				]
			)

		if (
			enemy_entry.count_increase_interval == 0
			and enemy_entry.count_increase_amount > 0
		):
			errors.append(
				(
					"%s has a zero count interval with a positive "
					+ "count amount for '%s'."
				)
				% [
					wave_label,
					enemy_id
				]
			)

		if (
			enemy_entry.count_increase_interval > 0
			and enemy_entry.count_increase_amount == 0
		):
			errors.append(
				(
					"%s has a positive count interval with a zero "
					+ "count amount for '%s'."
				)
				% [
					wave_label,
					enemy_id
				]
			)

		if (
			enemy_entry.maximum_count_per_side
			< enemy_entry.base_count_per_side
		):
			errors.append(
				"%s has maximum count below base count for '%s'."
				% [
					wave_label,
					enemy_id
				]
			)

		if enemy_entry.health_multiplier <= 0.0:
			errors.append(
				"%s has a non-positive health multiplier for '%s'."
				% [
					wave_label,
					enemy_id
				]
			)

		if enemy_entry.damage_multiplier <= 0.0:
			errors.append(
				"%s has a non-positive damage multiplier for '%s'."
				% [
					wave_label,
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


static func get_substage_label(
	substage: SubstageDefinition,
	substage_index: int,
	stage_label: String
) -> String:
	if substage.substage_id != &"":
		return "Substage '%s'" % substage.substage_id

	return (
		"Substage entry %d in %s"
		% [
			substage_index,
			stage_label
		]
	)


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

		for wave in stage.get_unique_wave_definitions():
			if not is_instance_valid(wave):
				continue

			var validated_enemy_ids: Dictionary = {}

			for enemy_entry in wave.enemy_entries:
				if not is_instance_valid(enemy_entry):
					continue

				var enemy_id: StringName = enemy_entry.enemy_id

				if (
					enemy_id == &""
					or validated_enemy_ids.has(enemy_id)
				):
					continue

				validated_enemy_ids[enemy_id] = true

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
