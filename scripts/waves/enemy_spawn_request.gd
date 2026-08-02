class_name EnemySpawnRequest
extends RefCounted


var enemy_definition: EnemyDefinition
var enemies_per_side: int = 0
var maximum_health: float = 1.0
var attack_damage_multiplier: float = 1.0


func _init(
	new_enemy_definition: EnemyDefinition = null,
	new_enemies_per_side: int = 0,
	new_maximum_health: float = 1.0,
	new_attack_damage_multiplier: float = 1.0
) -> void:
	enemy_definition = new_enemy_definition
	enemies_per_side = new_enemies_per_side
	maximum_health = new_maximum_health
	attack_damage_multiplier = new_attack_damage_multiplier


func is_valid_request() -> bool:
	return (
		is_instance_valid(enemy_definition)
		and enemy_definition.is_valid_definition()
		and is_instance_valid(enemy_definition.enemy_scene)
		and enemies_per_side >= 1
		and maximum_health >= 1.0
		and attack_damage_multiplier > 0.0
	)


func get_enemy_id() -> StringName:
	if (
		not is_instance_valid(enemy_definition)
		or not enemy_definition.is_valid_definition()
	):
		return &""

	return enemy_definition.enemy_id
