class_name SubstageWaveScheduleEntryDefinition
extends Resource


@export_category("Range")

@export_range(1, 100, 1)
var start_wave: int = 1

@export_range(1, 100, 1)
var end_wave: int = 1


@export_category("Wave")

@export var wave_definition: WaveDefinition


func contains_wave(
	wave_number: int
) -> bool:
	return (
		wave_number >= start_wave
		and wave_number <= end_wave
	)


func is_valid_definition() -> bool:
	if start_wave < 1 or start_wave > 100:
		return false

	if end_wave < 1 or end_wave > 100:
		return false

	if start_wave > end_wave:
		return false

	if not is_instance_valid(wave_definition):
		return false

	return wave_definition.is_valid_definition()
