class_name EnemyDefinition
extends Resource


@export_category("Identity")

@export var enemy_id: StringName = &""

@export var display_name: String = "Enemy"

@export_multiline
var description: String = ""


@export_category("Presentation")

@export var icon: Texture2D


@export_category("Runtime")

@export var enemy_scene: PackedScene


@export_category("Movement")

@export_range(0.0, 10000.0, 0.1)
var movement_speed: float = 50.0


@export_category("Combat")

@export_range(1.0, 1000000000.0, 1.0)
var maximum_health: float = 10.0

@export_range(0.0, 1000000000.0, 1.0)
var attack_damage: float = 1.0

@export_range(0.01, 3600.0, 0.01)
var attack_interval: float = 1.0

@export_range(0.0, 10000.0, 1.0)
var attack_range: float = 40.0


@export_category("Rewards")

@export_range(0, 1000000000, 1)
var essence_reward: int = 0

@export_range(0, 1000000000, 1)
var experience_reward: int = 1


@export_category("Classification")

@export var tags: Array[StringName] = []

@export var immune_status_effect_ids: Array[StringName] = []


func is_valid_definition() -> bool:
	if enemy_id == &"":
		return false

	if display_name.strip_edges().is_empty():
		return false

	if enemy_scene == null:
		return false

	if movement_speed < 0.0:
		return false

	if maximum_health <= 0.0:
		return false

	if attack_damage < 0.0:
		return false

	if attack_interval <= 0.0:
		return false

	if attack_range < 0.0:
		return false

	if essence_reward < 0:
		return false

	if experience_reward < 0:
		return false

	if has_invalid_or_duplicate_ids(
		tags
	):
		return false

	if has_invalid_or_duplicate_ids(
		immune_status_effect_ids
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
