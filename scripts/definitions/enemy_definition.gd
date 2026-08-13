class_name EnemyDefinition
extends Resource


const ENCOUNTER_RANK_NORMAL: StringName = &"normal"
const ENCOUNTER_RANK_MINIBOSS: StringName = &"miniboss"
const ENCOUNTER_RANK_BOSS: StringName = &"boss"


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


@export_category("Boss Ability")

@export var boss_ability_definition: BossAbilityDefinition


@export_category("Rewards")

@export_range(0, 1000000000, 1)
var essence_reward: int = 0

@export_range(0, 1000000000, 1)
var experience_reward: int = 1

@export_range(0.0, 1.0, 0.0001)
var branch_seed_roll_chance: float = 0.0

@export_range(0, 1000000, 1)
var branch_seed_pity_points: int = 0

@export_range(0.0, 1.0, 0.0001)
var equipment_drop_chance: float = 0.0

@export var equipment_guaranteed_once_per_wave: bool = false

@export var equipment_minimum_rarity_id: StringName = (
	ItemRarityRules.COMMON
)

@export_range(0, 1000000, 1)
var equipment_item_level_bonus: int = 0


@export_category("Classification")

@export var encounter_rank_id: StringName = ENCOUNTER_RANK_NORMAL

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

	if (
		is_instance_valid(boss_ability_definition)
		and not boss_ability_definition.is_valid_definition()
	):
		return false

	if essence_reward < 0:
		return false

	if experience_reward < 0:
		return false

	if encounter_rank_id not in [
		ENCOUNTER_RANK_NORMAL,
		ENCOUNTER_RANK_MINIBOSS,
		ENCOUNTER_RANK_BOSS
	]:
		return false

	if branch_seed_roll_chance < 0.0 or branch_seed_roll_chance > 1.0:
		return false

	if branch_seed_pity_points < 0:
		return false

	if equipment_drop_chance < 0.0 or equipment_drop_chance > 1.0:
		return false

	if not ItemRarityRules.is_valid_rarity_id(
		equipment_minimum_rarity_id
	):
		return false

	if equipment_item_level_bonus < 0:
		return false

	if is_normal_enemy() and (
		branch_seed_roll_chance != 0.0
		or branch_seed_pity_points != 0
	):
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


func is_normal_enemy() -> bool:
	return encounter_rank_id == ENCOUNTER_RANK_NORMAL


func is_miniboss() -> bool:
	return encounter_rank_id == ENCOUNTER_RANK_MINIBOSS


func is_boss() -> bool:
	return encounter_rank_id == ENCOUNTER_RANK_BOSS


func can_roll_branch_seed() -> bool:
	return (
		(is_miniboss() or is_boss())
		and (
			branch_seed_roll_chance > 0.0
			or branch_seed_pity_points > 0
		)
	)


func can_roll_equipment() -> bool:
	return (
		equipment_drop_chance > 0.0
		or equipment_guaranteed_once_per_wave
	)


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
