class_name WaveEnemyEntryDefinition
extends Resource


@export_category("Enemy")

@export var enemy_id: StringName = &""


@export_category("Count")

@export_range(1, 1000000, 1)
var base_count_per_side: int = 1

@export_range(1, 1000000, 1)
var count_scaling_start_stage_wave: int = 1

@export_range(0, 1000000, 1)
var count_increase_interval: int = 0

@export_range(0, 1000000, 1)
var count_increase_amount: int = 0

@export_range(1, 1000000000, 1)
var maximum_count_per_side: int = 1


@export_category("Scaling")

@export_range(0.01, 1000000.0, 0.01)
var health_multiplier: float = 1.0

@export_range(0.01, 1000000.0, 0.01)
var damage_multiplier: float = 1.0


func get_count_for_stage_wave(
	stage_wave: int
) -> int:
	var safe_stage_wave: int = max(
		stage_wave,
		1
	)
	var safe_base_count: int = max(
		base_count_per_side,
		1
	)
	var safe_maximum_count: int = max(
		maximum_count_per_side,
		safe_base_count
	)

	if (
		count_increase_interval <= 0
		or count_increase_amount <= 0
		or safe_stage_wave < count_scaling_start_stage_wave
	):
		return min(
			safe_base_count,
			safe_maximum_count
		)

	var completed_intervals: int = int(
		floor(
			float(
				safe_stage_wave
				- count_scaling_start_stage_wave
			)
			/ float(count_increase_interval)
		)
	)
	var calculated_count: int = (
		safe_base_count
		+ completed_intervals
		* count_increase_amount
	)

	return clamp(
		calculated_count,
		1,
		safe_maximum_count
	)


func is_valid_definition() -> bool:
	if enemy_id == &"":
		return false

	if base_count_per_side < 1:
		return false

	if count_scaling_start_stage_wave < 1:
		return false

	if count_increase_interval < 0:
		return false

	if count_increase_amount < 0:
		return false

	if (
		(count_increase_interval == 0)
		!= (count_increase_amount == 0)
	):
		return false

	if maximum_count_per_side < base_count_per_side:
		return false

	if health_multiplier <= 0.0:
		return false

	if damage_multiplier <= 0.0:
		return false

	return true
