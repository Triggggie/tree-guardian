class_name RunModifierService
extends Node


signal modifier_changed(
	modifier_id: StringName
)

signal all_modifiers_cleared()


# Struktura:
# modifier_id -> source_id -> hodnota
var additive_modifiers: Dictionary = {}

# Struktura:
# modifier_id -> source_id -> násobitel
var multiplier_modifiers: Dictionary = {}


func set_additive_modifier(
	modifier_id: StringName,
	source_id: StringName,
	value: float
) -> void:
	if not are_ids_valid(
		modifier_id,
		source_id
	):
		return

	var source_values: Dictionary = (
		additive_modifiers.get(
			modifier_id,
			{}
		)
	)

	source_values[source_id] = value
	additive_modifiers[modifier_id] = source_values

	modifier_changed.emit(
		modifier_id
	)


func set_multiplier_modifier(
	modifier_id: StringName,
	source_id: StringName,
	multiplier: float
) -> void:
	if not are_ids_valid(
		modifier_id,
		source_id
	):
		return

	if multiplier < 0.0:
		push_warning(
			"Modifier multiplier cannot be negative."
		)

		return

	var source_values: Dictionary = (
		multiplier_modifiers.get(
			modifier_id,
			{}
		)
	)

	source_values[source_id] = multiplier
	multiplier_modifiers[modifier_id] = source_values

	modifier_changed.emit(
		modifier_id
	)


func remove_modifier(
	modifier_id: StringName,
	source_id: StringName
) -> void:
	if not are_ids_valid(
		modifier_id,
		source_id
	):
		return

	var modifier_was_removed: bool = false

	if additive_modifiers.has(
		modifier_id
	):
		var additive_sources: Dictionary = (
			additive_modifiers[modifier_id]
		)

		if additive_sources.erase(source_id):
			modifier_was_removed = true

		if additive_sources.is_empty():
			additive_modifiers.erase(
				modifier_id
			)
		else:
			additive_modifiers[
				modifier_id
			] = additive_sources

	if multiplier_modifiers.has(
		modifier_id
	):
		var multiplier_sources: Dictionary = (
			multiplier_modifiers[modifier_id]
		)

		if multiplier_sources.erase(source_id):
			modifier_was_removed = true

		if multiplier_sources.is_empty():
			multiplier_modifiers.erase(
				modifier_id
			)
		else:
			multiplier_modifiers[
				modifier_id
			] = multiplier_sources

	if modifier_was_removed:
		modifier_changed.emit(
			modifier_id
		)


func clear_source(
	source_id: StringName
) -> void:
	if source_id == &"":
		return

	var changed_modifier_ids: Dictionary = {}

	for modifier_id in additive_modifiers.keys():
		var source_values: Dictionary = (
			additive_modifiers[modifier_id]
		)

		if not source_values.erase(source_id):
			continue

		changed_modifier_ids[
			modifier_id
		] = true

		if source_values.is_empty():
			additive_modifiers.erase(
				modifier_id
			)
		else:
			additive_modifiers[
				modifier_id
			] = source_values

	for modifier_id in multiplier_modifiers.keys():
		var source_values: Dictionary = (
			multiplier_modifiers[modifier_id]
		)

		if not source_values.erase(source_id):
			continue

		changed_modifier_ids[
			modifier_id
		] = true

		if source_values.is_empty():
			multiplier_modifiers.erase(
				modifier_id
			)
		else:
			multiplier_modifiers[
				modifier_id
			] = source_values

	for modifier_id in changed_modifier_ids.keys():
		modifier_changed.emit(
			StringName(
				str(modifier_id)
			)
		)


func clear_all() -> void:
	additive_modifiers.clear()
	multiplier_modifiers.clear()

	all_modifiers_cleared.emit()


func get_total_additive(
	modifier_id: StringName
) -> float:
	if not additive_modifiers.has(
		modifier_id
	):
		return 0.0

	var total_additive: float = 0.0
	var source_values: Dictionary = (
		additive_modifiers[modifier_id]
	)

	for source_value in source_values.values():
		total_additive += float(
			source_value
		)

	return total_additive


func get_total_multiplier(
	modifier_id: StringName
) -> float:
	if not multiplier_modifiers.has(
		modifier_id
	):
		return 1.0

	var total_multiplier: float = 1.0
	var source_values: Dictionary = (
		multiplier_modifiers[modifier_id]
	)

	for source_value in source_values.values():
		total_multiplier *= float(
			source_value
		)

	return total_multiplier


func apply_modifier(
	base_value: float,
	modifier_id: StringName
) -> float:
	return (
		base_value
		+ get_total_additive(modifier_id)
	) * get_total_multiplier(
		modifier_id
	)


func are_ids_valid(
	modifier_id: StringName,
	source_id: StringName
) -> bool:
	if modifier_id == &"":
		push_warning(
			"Modifier ID cannot be empty."
		)

		return false

	if source_id == &"":
		push_warning(
			"Modifier source ID cannot be empty."
		)

		return false

	return true
