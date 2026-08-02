class_name SubstageDefinition
extends Resource


const WAVE_COUNT: int = 100


@export_category("Identity")

@export var substage_id: StringName = &""

@export var display_name: String = "Substage"

@export_multiline
var description: String = ""


@export_category("Presentation")

@export var icon: Texture2D


@export_category("Waves")

@export var wave_patterns: Array[WaveDefinition] = []


@export_category("Completion")

@export_range(0, 1000000000, 1)
var completion_essence_reward: int = 0

@export var completion_effect_ids: Array[StringName] = []


func get_wave_count() -> int:
	return WAVE_COUNT


func get_wave_pattern_count() -> int:
	return wave_patterns.size()


func get_wave_for_index(
	wave_index: int
) -> WaveDefinition:
	if (
		wave_index < 0
		or wave_index >= WAVE_COUNT
		or wave_patterns.is_empty()
	):
		return null

	return wave_patterns[
		wave_index % wave_patterns.size()
	]


func get_wave_by_id(
	wave_id: StringName
) -> WaveDefinition:
	for wave_definition in wave_patterns:
		if not is_instance_valid(wave_definition):
			continue

		if wave_definition.wave_id == wave_id:
			return wave_definition

	return null


func get_unique_wave_definitions() -> Array[WaveDefinition]:
	var unique_waves: Array[WaveDefinition] = []
	var waves_by_id: Dictionary = {}

	for wave_definition in wave_patterns:
		if not is_instance_valid(wave_definition):
			continue

		var wave_id: StringName = wave_definition.wave_id

		if wave_id == &"" or waves_by_id.has(wave_id):
			continue

		waves_by_id[wave_id] = wave_definition
		unique_waves.append(wave_definition)

	return unique_waves


func is_valid_definition() -> bool:
	if substage_id == &"":
		return false

	if display_name.strip_edges().is_empty():
		return false

	if wave_patterns.is_empty():
		return false

	if completion_essence_reward < 0:
		return false

	var waves_by_id: Dictionary = {}

	for wave_definition in wave_patterns:
		if not is_instance_valid(wave_definition):
			return false

		if not wave_definition.is_valid_definition():
			return false

		var wave_id: StringName = wave_definition.wave_id

		if waves_by_id.has(wave_id):
			var indexed_wave: WaveDefinition = (
				waves_by_id.get(wave_id) as WaveDefinition
			)

			if indexed_wave != wave_definition:
				return false

			continue

		waves_by_id[wave_id] = wave_definition

	if _has_invalid_or_duplicate_ids(
		completion_effect_ids
	):
		return false

	return true


func _has_invalid_or_duplicate_ids(
	ids: Array[StringName]
) -> bool:
	var unique_ids: Dictionary = {}

	for checked_id in ids:
		if checked_id == &"":
			return true

		if unique_ids.has(checked_id):
			return true

		unique_ids[checked_id] = true

	return false
