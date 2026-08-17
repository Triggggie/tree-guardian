class_name StrengthWardenEffect
extends RefCounted


const DISRUPTOR: StringName = &"disruptor"
const STAGGERING_BLOW: StringName = &"staggering_blow"
const DISRUPTIVE_ARC: StringName = &"disruptive_arc"
const UPROOT: StringName = &"uproot"
const PROTECTOR: StringName = &"protector"
const HOLD_THE_LINE: StringName = &"hold_the_line"
const SENTINEL_REFLEX: StringName = &"sentinel_reflex"
const LAST_BASTION: StringName = &"last_bastion"


var owner_branch: Node2D
var rebuff_effect: StrengthRebuffEffect
var active_effect_ids: Dictionary = {}
var repeated_target_id: int = 0
var repeated_target_hits: int = 0
var resolved_primary_attack_count: int = 0
var shortened_cooldown_pending: bool = false


func configure(
	configured_owner: Node2D,
	configured_rebuff_effect: StrengthRebuffEffect
) -> void:
	owner_branch = configured_owner
	rebuff_effect = configured_rebuff_effect


func set_active_effect_ids(effect_ids: Dictionary) -> void:
	active_effect_ids = effect_ids


func find_danger_target() -> Node2D:
	if not _has_effect(PROTECTOR):
		return null
	if not is_instance_valid(owner_branch) or not owner_branch.is_inside_tree():
		return null
	var best_target: Node2D = null
	var best_tree_distance: float = INF
	for enemy in owner_branch.get_tree().get_nodes_in_group("enemies"):
		if enemy is not Node2D or not _is_valid_target(enemy):
			continue
		var target := enemy as Node2D
		var tree_distance: float = _get_tree_distance(target)
		if tree_distance > get_danger_radius() or tree_distance >= best_tree_distance:
			continue
		best_tree_distance = tree_distance
		best_target = target
	return best_target


func apply_after_primary_resolved(
	target: Node2D
) -> void:
	if not _has_effect(rebuff_effect.get_effect_id()):
		return
	resolved_primary_attack_count += 1
	var target_id: int = target.get_instance_id()
	if repeated_target_id == target_id:
		repeated_target_hits += 1
	else:
		repeated_target_id = target_id
		repeated_target_hits = 1

	var started_in_danger: bool = _is_in_danger(target)
	var staggering_trigger: bool = (
		_has_effect(STAGGERING_BLOW)
		and repeated_target_hits % 3 == 0
	)
	var knockback_distance: float = rebuff_effect.knockback_distance
	if started_in_danger and _has_effect(HOLD_THE_LINE):
		knockback_distance *= 2.5 if _is_last_bastion_active() else 2.0
	if staggering_trigger:
		knockback_distance *= 2.0
	_apply_knockback(target, knockback_distance)

	var interrupted: bool = false
	if _has_effect(DISRUPTOR) or staggering_trigger:
		interrupted = _try_interrupt(target)
	if interrupted and _has_effect(DISRUPTIVE_ARC):
		_apply_disruptive_arc(target)

	if (
		started_in_danger
		and _has_effect(SENTINEL_REFLEX)
		and not _is_in_danger(target)
	):
		shortened_cooldown_pending = true

	if _has_effect(UPROOT) and resolved_primary_attack_count % 5 == 0:
		_apply_uproot(target)


func apply_after_secondary_resolved(target: Node2D) -> void:
	if not _has_effect(rebuff_effect.get_effect_id()):
		return
	rebuff_effect.apply_after_resolved_hit(target)


func consume_next_cooldown_multiplier() -> float:
	if not shortened_cooldown_pending:
		return 1.0
	shortened_cooldown_pending = false
	return 0.50


func get_danger_radius() -> float:
	return 350.0 if _is_last_bastion_active() else 250.0


func _apply_disruptive_arc(primary_target: Node2D) -> void:
	var targets: Array[Node2D] = _find_nearby_targets(primary_target, 170.0, 2, true)
	for target in targets:
		_apply_knockback(target, rebuff_effect.knockback_distance * 0.50)
		_try_interrupt(target)


func _apply_uproot(primary_target: Node2D) -> void:
	var targets: Array[Node2D] = [primary_target]
	targets.append_array(_find_nearby_targets(primary_target, 220.0, 5, false))
	for target in targets:
		if not _is_valid_target(target):
			continue
		_apply_knockback(target, rebuff_effect.knockback_distance * 1.50)
		_try_interrupt(target)
	if owner_branch.has_method("play_strength_talent_feedback"):
		owner_branch.call("play_strength_talent_feedback", &"uproot")


func _find_nearby_targets(
	center: Node2D,
	radius: float,
	maximum_targets: int,
	normal_only: bool
) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for enemy in owner_branch.get_tree().get_nodes_in_group("enemies"):
		if enemy is not Node2D or enemy == center or not _is_valid_target(enemy):
			continue
		var target := enemy as Node2D
		if target.global_position.distance_to(center.global_position) > radius:
			continue
		if normal_only and not _is_normal_enemy(target):
			continue
		targets.append(target)
	targets.sort_custom(
		func(first: Node2D, second: Node2D) -> bool:
			return first.global_position.distance_squared_to(center.global_position) < second.global_position.distance_squared_to(center.global_position)
	)
	if targets.size() > maximum_targets:
		targets.resize(maximum_targets)
	return targets


func _try_interrupt(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	if not target.has_method("can_be_interrupted") or not target.has_method("interrupt_attack"):
		return false
	if not bool(target.call("can_be_interrupted")):
		return false
	return bool(target.call("interrupt_attack"))


func _apply_knockback(target: Node, distance: float) -> void:
	if is_instance_valid(target) and target.has_method("apply_knockback"):
		target.call("apply_knockback", distance)


func _is_in_danger(target: Node2D) -> bool:
	return is_instance_valid(target) and _get_tree_distance(target) <= get_danger_radius()


func _get_tree_distance(target: Node2D) -> float:
	var tree_position_x: float = owner_branch.global_position.x
	var tree_node = owner_branch.get("tree_node")
	if is_instance_valid(tree_node) and tree_node is Node2D:
		tree_position_x = (tree_node as Node2D).global_position.x
	return abs(target.global_position.x - tree_position_x)


func _is_last_bastion_active() -> bool:
	if not _has_effect(LAST_BASTION) or not is_instance_valid(owner_branch):
		return false
	var tree_node = owner_branch.get("tree_node")
	if not is_instance_valid(tree_node):
		return false
	var current_health_value = tree_node.get("current_health")
	var maximum_health_value = tree_node.get("max_health")
	if current_health_value == null or maximum_health_value == null:
		return false
	var maximum_health: float = float(maximum_health_value)
	return maximum_health > 0.0 and float(current_health_value) / maximum_health <= 0.35


func _is_normal_enemy(target: Node) -> bool:
	if target.has_method("is_normal_enemy"):
		return bool(target.call("is_normal_enemy"))
	var definition = target.get("enemy_definition")
	return not is_instance_valid(definition) or definition.is_normal_enemy()


func _is_valid_target(target: Node) -> bool:
	return (
		is_instance_valid(owner_branch)
		and owner_branch.has_method("is_valid_attack_target")
		and bool(owner_branch.call("is_valid_attack_target", target))
	)


func _has_effect(effect_id: StringName) -> bool:
	return active_effect_ids.has(effect_id)


func reset_runtime_state() -> void:
	repeated_target_id = 0
	repeated_target_hits = 0
	resolved_primary_attack_count = 0
	shortened_cooldown_pending = false
