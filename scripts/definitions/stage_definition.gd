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


@export_category("Progression")

@export_range(1, 1000000, 1)
var wave_count: int = 100

@export var repeat_indefinitely: bool = false

@export_range(1, 1000000, 1)
var enemies_per_side_increase_interval: int = 3

@export_range(1, 1000000000, 1)
var maximum_enemies_per_side: int = 30

@export_range(0.0, 1000000000.0, 0.01)
var health_increase_per_global_wave: float = 3.0

@export_range(1.0, 1000000000.0, 1.0)
var maximum_enemy_health: float = 1000000.0


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
		or wave_index >= wave_count
		or waves.is_empty()
	):
		return null

	return waves[
		wave_index % waves.size()
	]


func get_wave_for_stage_index(
	wave_index: int
) -> WaveDefinition:
	return get_wave(wave_index)


func get_wave_count() -> int:
	return max(
		wave_count,
		1
	)


func get_wave_pattern_count() -> int:
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


func get_enemy_count_for_global_wave(
	wave_definition: WaveDefinition,
	enemy_id: StringName,
	global_wave: int
) -> int:
	if (
		not is_instance_valid(wave_definition)
		or not wave_definition.is_valid_definition()
	):
		return 0

	var base_enemy_count: int = (
		wave_definition.get_enemy_count_for_id(
			enemy_id
		)
	)

	if base_enemy_count < 1:
		return 0

	var safe_global_wave: int = max(
		global_wave,
		1
	)

	var safe_interval: int = max(
		enemies_per_side_increase_interval,
		1
	)

	var additional_enemy_count: int = int(
		floor(
			float(safe_global_wave - 1)
			/ float(safe_interval)
		)
	)

	return max(
		min(
			base_enemy_count
			+ additional_enemy_count,
			maximum_enemies_per_side
		),
		0
	)


func get_enemy_health_for_global_wave(
	wave_definition: WaveDefinition,
	enemy_definition: EnemyDefinition,
	global_wave: int
) -> float:
	if (
		not is_instance_valid(wave_definition)
		or not wave_definition.is_valid_definition()
		or not is_instance_valid(enemy_definition)
		or not enemy_definition.is_valid_definition()
	):
		return 1.0

	var safe_global_wave: int = max(
		global_wave,
		1
	)

	var calculated_health: float = (
		enemy_definition.maximum_health
		* wave_definition.health_multiplier
		+ health_increase_per_global_wave
		* (safe_global_wave - 1)
	)

	return min(
		max(
			calculated_health,
			1.0
		),
		max(
			maximum_enemy_health,
			1.0
		)
	)


func is_valid_definition() -> bool:
	if stage_id == &"":
		return false

	if display_name.strip_edges().is_empty():
		return false

	if waves.is_empty():
		return false

	if wave_count < 1:
		return false

	if enemies_per_side_increase_interval < 1:
		return false

	if maximum_enemies_per_side < 1:
		return false

	if health_increase_per_global_wave < 0.0:
		return false

	if maximum_enemy_health < 1.0:
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
