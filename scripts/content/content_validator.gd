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

	validate_wave_enemy_references(
		registry,
		errors
	)

	validate_enemy_immunity_references(
		registry,
		errors
	)

	return errors


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
