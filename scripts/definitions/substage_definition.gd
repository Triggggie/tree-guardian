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

@export var wave_schedule: SubstageWaveScheduleDefinition

var wave_patterns: Array[WaveDefinition]:
	get:
		return get_unique_wave_definitions()


@export_category("Completion")

@export_range(0, 1000000000, 1)
var completion_essence_reward: int = 0

@export var completion_effect_ids: Array[StringName] = []


func get_wave_count() -> int:
	return WAVE_COUNT


func get_wave_pattern_count() -> int:
	if not is_instance_valid(wave_schedule):
		return 0

	return wave_schedule.entries.size()


func get_wave_for_index(
	wave_index: int
) -> WaveDefinition:
	if (
		wave_index < 0
		or wave_index >= WAVE_COUNT
		or not is_instance_valid(wave_schedule)
	):
		return null

	return wave_schedule.get_wave_for_number(
		wave_index + 1
	)


func get_wave_by_id(
	wave_id: StringName
) -> WaveDefinition:
	if not is_instance_valid(wave_schedule):
		return null

	for wave_definition in wave_schedule.get_unique_wave_definitions():
		if not is_instance_valid(wave_definition):
			continue

		if wave_definition.wave_id == wave_id:
			return wave_definition

	return null


func get_unique_wave_definitions() -> Array[WaveDefinition]:
	if not is_instance_valid(wave_schedule):
		return []

	return wave_schedule.get_unique_wave_definitions()


func is_valid_definition() -> bool:
	if substage_id == &"":
		return false

	if display_name.strip_edges().is_empty():
		return false

	if not is_instance_valid(wave_schedule):
		return false

	if not wave_schedule.is_valid_definition():
		return false

	if completion_essence_reward < 0:
		return false

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
