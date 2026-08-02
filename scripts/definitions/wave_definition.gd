class_name WaveDefinition
extends Resource


@export_category("Identity")

@export var wave_id: StringName = &""

@export var display_name: String = "Wave"

@export_multiline
var description: String = ""


@export_category("Enemies")

@export var enemy_entries: Array[WaveEnemyEntryDefinition] = []


@export_category("Spawning")

@export_range(0.0, 60.0, 0.05)
var spawn_interval: float = 0.25


@export_category("Timing")

@export_range(0.0, 60.0, 0.05)
var completion_message_duration: float = 0.7

@export_range(0.0, 60.0, 0.05)
var time_after_wave: float = 0.5


func get_enemy_entry(
	enemy_id: StringName
) -> WaveEnemyEntryDefinition:
	for enemy_entry in enemy_entries:
		if not is_instance_valid(enemy_entry):
			continue

		if enemy_entry.enemy_id == enemy_id:
			return enemy_entry

	return null


func get_enemy_ids() -> Array[StringName]:
	var enemy_ids: Array[StringName] = []

	for enemy_entry in enemy_entries:
		if (
			not is_instance_valid(enemy_entry)
			or enemy_entry.enemy_id == &""
		):
			continue

		enemy_ids.append(enemy_entry.enemy_id)

	return enemy_ids


func get_enemy_count_for_id(
	enemy_id: StringName,
	stage_wave: int = 1
) -> int:
	var enemy_entry: WaveEnemyEntryDefinition = (
		get_enemy_entry(enemy_id)
	)

	if not is_instance_valid(enemy_entry):
		return 0

	return enemy_entry.get_count_for_stage_wave(
		stage_wave
	)


func get_total_enemies_per_side(
	stage_wave: int = 1
) -> int:
	var total_enemies: int = 0

	for enemy_entry in enemy_entries:
		if (
			not is_instance_valid(enemy_entry)
			or not enemy_entry.is_valid_definition()
		):
			continue

		total_enemies += enemy_entry.get_count_for_stage_wave(
			stage_wave
		)

	return total_enemies


func get_health_multiplier_for_id(
	enemy_id: StringName
) -> float:
	var enemy_entry: WaveEnemyEntryDefinition = (
		get_enemy_entry(enemy_id)
	)

	if (
		not is_instance_valid(enemy_entry)
		or not enemy_entry.is_valid_definition()
	):
		return 1.0

	return enemy_entry.health_multiplier


func get_damage_multiplier_for_id(
	enemy_id: StringName
) -> float:
	var enemy_entry: WaveEnemyEntryDefinition = (
		get_enemy_entry(enemy_id)
	)

	if (
		not is_instance_valid(enemy_entry)
		or not enemy_entry.is_valid_definition()
	):
		return 1.0

	return enemy_entry.damage_multiplier


func is_valid_definition() -> bool:
	if wave_id == &"":
		return false

	if display_name.strip_edges().is_empty():
		return false

	if enemy_entries.is_empty():
		return false

	if spawn_interval < 0.0:
		return false

	if completion_message_duration < 0.0:
		return false

	if time_after_wave < 0.0:
		return false

	var unique_enemy_ids: Dictionary = {}

	for enemy_entry in enemy_entries:
		if not is_instance_valid(enemy_entry):
			return false

		if not enemy_entry.is_valid_definition():
			return false

		if unique_enemy_ids.has(enemy_entry.enemy_id):
			return false

		unique_enemy_ids[enemy_entry.enemy_id] = true

	return true
