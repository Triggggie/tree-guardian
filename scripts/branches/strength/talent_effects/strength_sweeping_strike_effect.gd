class_name StrengthSweepingStrikeEffect
extends RefCounted


const EFFECT_ID: StringName = &"sweeping_strike"
const ATTACK_ID: StringName = &"strength_sweeping_strike"


var owner_branch: Node2D
var damage_multiplier: float = 0.60
var search_radius: float = 120.0


func configure(
	configured_owner_branch: Node2D,
	configured_damage_multiplier: float,
	configured_search_radius: float
) -> void:
	owner_branch = configured_owner_branch
	damage_multiplier = configured_damage_multiplier
	search_radius = configured_search_radius


func get_effect_id() -> StringName:
	return EFFECT_ID


func find_secondary_target(
	primary_target: Node2D
) -> Node2D:
	if not is_valid_owner_target(primary_target):
		return null

	var best_target: Node2D = null
	var best_lane_difference: int = 999
	var closest_distance: float = search_radius + 0.001
	var primary_lane_index: int = -1

	if primary_target.has_method(
		"get_lane_index"
	):
		primary_lane_index = int(
			primary_target.call(
				"get_lane_index"
			)
		)

	for enemy in owner_branch.get_tree().get_nodes_in_group(
		"enemies"
	):
		if enemy == primary_target:
			continue

		if not is_valid_owner_target(enemy):
			continue

		var enemy_node := enemy as Node2D

		var distance_from_primary: float = (
			enemy_node.global_position.distance_to(
				primary_target.global_position
			)
		)

		if distance_from_primary > search_radius:
			continue

		var lane_difference: int = 999

		if (
			primary_lane_index >= 0
			and enemy.has_method(
				"get_lane_index"
			)
		):
			var enemy_lane_index: int = int(
				enemy.call(
					"get_lane_index"
				)
			)

			lane_difference = abs(
				enemy_lane_index
				- primary_lane_index
			)

		if lane_difference > best_lane_difference:
			continue

		if (
			lane_difference == best_lane_difference
			and distance_from_primary >= closest_distance
		):
			continue

		best_lane_difference = lane_difference
		closest_distance = distance_from_primary
		best_target = enemy_node

	return best_target


func configure_secondary_context(
	context: AttackContext
) -> void:
	if context == null:
		return

	context.attack_id = ATTACK_ID
	context.damage_multiplier = damage_multiplier
	context.is_secondary_attack = true
	context.add_tag(EFFECT_ID)


func is_valid_owner_target(
	target: Node
) -> bool:
	if not is_instance_valid(owner_branch):
		return false

	if not owner_branch.has_method(
		"is_valid_attack_target"
	):
		return false

	return bool(
		owner_branch.call(
			"is_valid_attack_target",
			target
		)
	)
