class_name WaveDefinition
extends Resource


@export_category("Identity")

@export var wave_id: StringName = &""

@export var display_name: String = "Wave"

@export_multiline
var description: String = ""


@export_category("Enemies")

# Stabilní ID nepřátel obsažených ve vlně.
@export var enemy_ids: Array[StringName] = []

# Počet každého typu nepřítele na jednu stranu.
# Index odpovídá indexu v enemy_ids.
@export var enemies_per_side: Array[int] = []


@export_category("Spawning")

@export_range(0.0, 60.0, 0.05)
var spawn_interval: float = 0.25


@export_category("Scaling")

@export_range(0.01, 1000000.0, 0.01)
var health_multiplier: float = 1.0

@export_range(0.01, 1000000.0, 0.01)
var damage_multiplier: float = 1.0


@export_category("Timing")

@export_range(0.0, 60.0, 0.05)
var completion_message_duration: float = 0.7

@export_range(0.0, 60.0, 0.05)
var time_after_wave: float = 0.5


func get_enemy_count_for_id(
	enemy_id: StringName
) -> int:
	for enemy_index in range(
		enemy_ids.size()
	):
		if enemy_ids[enemy_index] == enemy_id:
			return enemies_per_side[
				enemy_index
			]

	return 0


func get_total_enemies_per_side() -> int:
	var total_enemies: int = 0

	for enemy_count in enemies_per_side:
		total_enemies += max(
			enemy_count,
			0
		)

	return total_enemies


func is_valid_definition() -> bool:
	if wave_id == &"":
		return false

	if display_name.strip_edges().is_empty():
		return false

	if enemy_ids.is_empty():
		return false

	if (
		enemy_ids.size()
		!= enemies_per_side.size()
	):
		return false

	if spawn_interval < 0.0:
		return false

	if health_multiplier <= 0.0:
		return false

	if damage_multiplier <= 0.0:
		return false

	if completion_message_duration < 0.0:
		return false

	if time_after_wave < 0.0:
		return false

	var unique_enemy_ids: Dictionary = {}

	for enemy_index in range(
		enemy_ids.size()
	):
		var enemy_id: StringName = (
			enemy_ids[enemy_index]
		)

		var enemy_count: int = (
			enemies_per_side[enemy_index]
		)

		if enemy_id == &"":
			return false

		if enemy_count < 1:
			return false

		if unique_enemy_ids.has(enemy_id):
			return false

		unique_enemy_ids[enemy_id] = true

	return true
