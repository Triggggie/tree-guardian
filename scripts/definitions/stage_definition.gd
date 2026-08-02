class_name StageDefinition
extends Resource


const SUBSTAGE_COUNT: int = 10


@export_category("Identity")

@export var stage_id: StringName = &""

@export var display_name: String = "Stage"

@export_multiline
var description: String = ""


@export_category("Presentation")

@export var icon: Texture2D


@export_category("Substages")

@export var substages: Array[SubstageDefinition] = []


@export_category("Progression")

@export var repeat_indefinitely: bool = false


@export_category("Enemy Scaling")

@export_range(0.0, 1.0, 0.0001)
var health_growth_per_stage_wave: float = 0.0

@export_range(0.0, 1.0, 0.0001)
var damage_growth_per_stage_wave: float = 0.0

@export_range(1.0, 1000000000.0, 1.0)
var maximum_enemy_health: float = 1000000.0


@export_category("Completion")

@export_range(0, 1000000000, 1)
var completion_essence_reward: int = 0

# Stabilní ID efektů, které se aktivují
# po dokončení celé stage.
@export var completion_effect_ids: Array[StringName] = []


func get_substage_count() -> int:
	return substages.size()


func get_required_substage_count() -> int:
	return SUBSTAGE_COUNT


func get_waves_per_substage() -> int:
	return SubstageDefinition.WAVE_COUNT


func get_total_wave_count() -> int:
	return (
		SUBSTAGE_COUNT
		* SubstageDefinition.WAVE_COUNT
	)


func get_wave_count() -> int:
	return get_total_wave_count()


func get_substage(
	substage_index: int
) -> SubstageDefinition:
	if (
		substage_index < 0
		or substage_index >= SUBSTAGE_COUNT
		or substage_index >= substages.size()
	):
		return null

	return substages[substage_index]


func get_substage_by_id(
	substage_id: StringName
) -> SubstageDefinition:
	for substage in substages:
		if not is_instance_valid(substage):
			continue

		if substage.substage_id == substage_id:
			return substage

	return null


func get_substage_index_for_stage_wave(
	stage_wave_index: int
) -> int:
	if (
		stage_wave_index < 0
		or stage_wave_index >= get_total_wave_count()
	):
		return -1

	return int(
		floor(
			float(stage_wave_index)
			/ float(SubstageDefinition.WAVE_COUNT)
		)
	)


func get_wave_index_in_substage_for_stage_wave(
	stage_wave_index: int
) -> int:
	if (
		stage_wave_index < 0
		or stage_wave_index >= get_total_wave_count()
	):
		return -1

	return stage_wave_index % SubstageDefinition.WAVE_COUNT


func get_substage_start_wave_index(
	substage_index: int
) -> int:
	if substage_index < 0 or substage_index >= SUBSTAGE_COUNT:
		return -1

	return substage_index * SubstageDefinition.WAVE_COUNT


func get_wave_for_stage_index(
	stage_wave_index: int
) -> WaveDefinition:
	var substage_index: int = (
		get_substage_index_for_stage_wave(
			stage_wave_index
		)
	)
	var wave_index_in_substage: int = (
		get_wave_index_in_substage_for_stage_wave(
			stage_wave_index
		)
	)

	if substage_index < 0 or wave_index_in_substage < 0:
		return null

	var substage: SubstageDefinition = get_substage(
		substage_index
	)

	if not is_instance_valid(substage):
		return null

	return substage.get_wave_for_index(
		wave_index_in_substage
	)


func get_wave(
	stage_wave_index: int
) -> WaveDefinition:
	return get_wave_for_stage_index(
		stage_wave_index
	)


func get_unique_wave_definitions() -> Array[WaveDefinition]:
	var unique_waves: Array[WaveDefinition] = []
	var waves_by_id: Dictionary = {}

	for substage in substages:
		if not is_instance_valid(substage):
			continue

		for wave_definition in substage.wave_patterns:
			if not is_instance_valid(wave_definition):
				continue

			var wave_id: StringName = wave_definition.wave_id

			if wave_id == &"" or waves_by_id.has(wave_id):
				continue

			waves_by_id[wave_id] = wave_definition
			unique_waves.append(wave_definition)

	return unique_waves


func get_wave_by_id(
	wave_id: StringName
) -> WaveDefinition:
	for substage in substages:
		if not is_instance_valid(substage):
			continue

		var wave_definition: WaveDefinition = (
			substage.get_wave_by_id(wave_id)
		)

		if is_instance_valid(wave_definition):
			return wave_definition

	return null


func get_enemy_count_for_stage_wave(
	wave_definition: WaveDefinition,
	enemy_id: StringName,
	stage_wave: int
) -> int:
	if (
		not is_instance_valid(wave_definition)
		or not wave_definition.is_valid_definition()
	):
		return 0

	return max(
		wave_definition.get_enemy_count_for_id(
			enemy_id,
			stage_wave
		),
		0
	)


func get_enemy_health_for_stage_wave(
	wave_definition: WaveDefinition,
	enemy_definition: EnemyDefinition,
	stage_wave: int
) -> float:
	if (
		not is_instance_valid(wave_definition)
		or not wave_definition.is_valid_definition()
		or not is_instance_valid(enemy_definition)
		or not enemy_definition.is_valid_definition()
	):
		return 1.0

	var enemy_entry: WaveEnemyEntryDefinition = (
		wave_definition.get_enemy_entry(
			enemy_definition.enemy_id
		)
	)

	if (
		not is_instance_valid(enemy_entry)
		or not enemy_entry.is_valid_definition()
	):
		return 1.0

	var safe_stage_wave: int = max(
		stage_wave,
		1
	)
	var stage_health_multiplier: float = (
		1.0
		+ health_growth_per_stage_wave
		* (safe_stage_wave - 1)
	)

	var calculated_health: float = (
		enemy_definition.maximum_health
		* enemy_entry.health_multiplier
		* stage_health_multiplier
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


func get_enemy_damage_multiplier(
	wave_definition: WaveDefinition,
	enemy_id: StringName,
	stage_wave: int = 1
) -> float:
	if (
		not is_instance_valid(wave_definition)
		or not wave_definition.is_valid_definition()
	):
		return 1.0

	var enemy_entry: WaveEnemyEntryDefinition = (
		wave_definition.get_enemy_entry(enemy_id)
	)

	if (
		not is_instance_valid(enemy_entry)
		or not enemy_entry.is_valid_definition()
	):
		return 1.0

	var safe_stage_wave: int = max(stage_wave, 1)
	var stage_damage_multiplier: float = (
		1.0
		+ damage_growth_per_stage_wave
		* (safe_stage_wave - 1)
	)

	return (
		enemy_entry.damage_multiplier
		* stage_damage_multiplier
	)


func is_valid_definition() -> bool:
	if stage_id == &"":
		return false

	if display_name.strip_edges().is_empty():
		return false

	if substages.size() != SUBSTAGE_COUNT:
		return false

	if health_growth_per_stage_wave < 0.0:
		return false

	if damage_growth_per_stage_wave < 0.0:
		return false

	if maximum_enemy_health < 1.0:
		return false

	if completion_essence_reward < 0:
		return false

	var substages_by_id: Dictionary = {}
	var waves_by_id: Dictionary = {}

	for substage in substages:
		if not is_instance_valid(substage):
			return false

		if not substage.is_valid_definition():
			return false

		if substage.substage_id == &"":
			return false

		if substages_by_id.has(substage.substage_id):
			return false

		substages_by_id[substage.substage_id] = substage

		for wave_definition in substage.wave_patterns:
			var wave_id: StringName = wave_definition.wave_id

			if waves_by_id.has(wave_id):
				var indexed_wave: WaveDefinition = (
					waves_by_id.get(wave_id) as WaveDefinition
				)

				if indexed_wave != wave_definition:
					return false

				continue

			waves_by_id[wave_id] = wave_definition

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
