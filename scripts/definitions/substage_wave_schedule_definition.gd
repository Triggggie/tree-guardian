class_name SubstageWaveScheduleDefinition
extends Resource


const WAVE_COUNT: int = 100


@export_category("Identity")

@export var schedule_id: StringName = &""

@export var display_name: String = "Wave Schedule"


@export_category("Entries")

@export var entries: Array[SubstageWaveScheduleEntryDefinition] = []


func get_wave_for_number(
	wave_number: int
) -> WaveDefinition:
	if wave_number < 1 or wave_number > WAVE_COUNT:
		return null

	for entry in entries:
		if (
			is_instance_valid(entry)
			and entry.contains_wave(wave_number)
		):
			return entry.wave_definition

	return null


func get_unique_wave_definitions() -> Array[WaveDefinition]:
	var unique_waves: Array[WaveDefinition] = []
	var waves_by_id: Dictionary = {}

	for entry in entries:
		if not is_instance_valid(entry):
			continue

		var wave_definition: WaveDefinition = (
			entry.wave_definition
		)

		if not is_instance_valid(wave_definition):
			continue

		var wave_id: StringName = wave_definition.wave_id

		if wave_id == &"" or waves_by_id.has(wave_id):
			continue

		waves_by_id[wave_id] = wave_definition
		unique_waves.append(wave_definition)

	return unique_waves


func is_valid_definition() -> bool:
	if schedule_id == &"":
		return false

	if display_name.strip_edges().is_empty():
		return false

	if entries.is_empty():
		return false

	var expected_start_wave: int = 1
	var waves_by_id: Dictionary = {}

	for entry in entries:
		if not is_instance_valid(entry):
			return false

		if not entry.is_valid_definition():
			return false

		if entry.start_wave != expected_start_wave:
			return false

		var wave_definition: WaveDefinition = (
			entry.wave_definition
		)
		var wave_id: StringName = wave_definition.wave_id

		if waves_by_id.has(wave_id):
			var indexed_wave: WaveDefinition = (
				waves_by_id.get(wave_id) as WaveDefinition
			)

			if indexed_wave != wave_definition:
				return false
		else:
			waves_by_id[wave_id] = wave_definition

		expected_start_wave = entry.end_wave + 1

	return expected_start_wave == WAVE_COUNT + 1
