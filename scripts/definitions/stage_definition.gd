class_name StageDefinition
extends Resource


@export_category("Identity")

@export var stage_id: StringName = &""

@export var display_name: String = "Stage"

@export_multiline
var description: String = ""


@export_category("Presentation")

@export var icon: Texture2D


@export_category("Waves")

@export var waves: Array[WaveDefinition] = []


@export_category("Completion")

@export_range(0, 1000000000, 1)
var completion_essence_reward: int = 0

# Stabilní ID efektů, které se aktivují
# po dokončení celé stage.
@export var completion_effect_ids: Array[StringName] = []


func get_wave(
	wave_index: int
) -> WaveDefinition:
	if (
		wave_index < 0
		or wave_index >= waves.size()
	):
		return null

	return waves[wave_index]


func get_wave_count() -> int:
	return waves.size()


func get_wave_by_id(
	wave_id: StringName
) -> WaveDefinition:
	for wave in waves:
		if wave == null:
			continue

		if wave.wave_id == wave_id:
			return wave

	return null


func is_valid_definition() -> bool:
	if stage_id == &"":
		return false

	if display_name.strip_edges().is_empty():
		return false

	if waves.is_empty():
		return false

	if completion_essence_reward < 0:
		return false

	var waves_by_id: Dictionary = {}

	for wave in waves:
		if wave == null:
			return false

		if not wave.is_valid_definition():
			return false

		if waves_by_id.has(
			wave.wave_id
		):
			return false

		waves_by_id[
			wave.wave_id
		] = wave

	if has_invalid_or_duplicate_ids(
		completion_effect_ids
	):
		return false

	return true


func has_invalid_or_duplicate_ids(
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
