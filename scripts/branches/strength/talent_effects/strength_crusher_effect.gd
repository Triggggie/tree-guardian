class_name StrengthCrusherEffect
extends RefCounted


const CLEAVER: StringName = &"cleaver"
const SERRATED_ARC: StringName = &"serrated_arc"
const REAPING_SWEEP: StringName = &"reaping_sweep"
const WHIRLING_BOUGH: StringName = &"whirling_bough"

const SERRATED_ATTACK_ID: StringName = &"strength_serrated_arc"
const REAPING_ATTACK_ID: StringName = &"strength_reaping_sweep"
const GRAND_SWEEP_ATTACK_ID: StringName = &"strength_grand_sweep"


var owner_branch: Node2D
var sweeping_effect: StrengthSweepingStrikeEffect
var active_effect_ids: Dictionary = {}
var resolved_primary_attack_count: int = 0


func configure(
	configured_owner: Node2D,
	configured_sweeping_effect: StrengthSweepingStrikeEffect
) -> void:
	owner_branch = configured_owner
	sweeping_effect = configured_sweeping_effect


func set_active_effect_ids(effect_ids: Dictionary) -> void:
	active_effect_ids = effect_ids


func on_primary_resolved(
	primary_target: Node2D,
	current_damage: float,
	effect_set: StrengthTalentEffectSet
) -> void:
	if not _has_effect(sweeping_effect.get_effect_id()):
		return

	resolved_primary_attack_count += 1
	if (
		_has_effect(WHIRLING_BOUGH)
		and resolved_primary_attack_count % 4 == 0
	):
		_resolve_grand_sweep(primary_target, current_damage, effect_set)
		return

	_resolve_normal_sweep(primary_target, current_damage, effect_set)


func _resolve_normal_sweep(
	primary_target: Node2D,
	current_damage: float,
	effect_set: StrengthTalentEffectSet
) -> void:
	var hit_ids: Dictionary = {primary_target.get_instance_id(): true}
	var secondary_limit: int = 2 if _has_effect(CLEAVER) else 1
	var secondary_targets: Array[Node2D] = _find_targets_near(
		primary_target,
		sweeping_effect.search_radius,
		hit_ids,
		secondary_limit
	)
	var any_sweep_kill: bool = false
	var first_resolved_secondary: Node2D = null

	for target in secondary_targets:
		var target_was_alive: bool = _target_is_alive(target)
		if not _resolve_hit(
			target,
			current_damage,
			sweeping_effect.damage_multiplier,
			sweeping_effect.ATTACK_ID,
			sweeping_effect.get_effect_id(),
			effect_set
		):
			continue
		hit_ids[target.get_instance_id()] = true
		if first_resolved_secondary == null:
			first_resolved_secondary = target
		any_sweep_kill = any_sweep_kill or (
			target_was_alive and not _target_is_alive(target)
		)

	if _has_effect(SERRATED_ARC) and is_instance_valid(first_resolved_secondary):
		var chained_targets: Array[Node2D] = _find_targets_near(
			first_resolved_secondary,
			sweeping_effect.search_radius,
			hit_ids,
			1
		)
		if not chained_targets.is_empty():
			var chained_target: Node2D = chained_targets[0]
			var target_was_alive: bool = _target_is_alive(chained_target)
			if _resolve_hit(
				chained_target,
				current_damage,
				0.45,
				SERRATED_ATTACK_ID,
				SERRATED_ARC,
				effect_set
			):
				hit_ids[chained_target.get_instance_id()] = true
				any_sweep_kill = any_sweep_kill or (
					target_was_alive and not _target_is_alive(chained_target)
				)

	if not _has_effect(REAPING_SWEEP) or not any_sweep_kill:
		return

	var reaping_targets: Array[Node2D] = _find_targets_near(
		primary_target,
		sweeping_effect.search_radius,
		hit_ids,
		1
	)
	if reaping_targets.is_empty():
		return
	_resolve_hit(
		reaping_targets[0],
		current_damage,
		0.60,
		REAPING_ATTACK_ID,
		REAPING_SWEEP,
		effect_set
	)


func _resolve_grand_sweep(
	primary_target: Node2D,
	current_damage: float,
	effect_set: StrengthTalentEffectSet
) -> void:
	var hit_ids: Dictionary = {primary_target.get_instance_id(): true}
	var targets: Array[Node2D] = _find_targets_near(
		primary_target,
		max(sweeping_effect.search_radius, 180.0),
		hit_ids,
		5
	)
	for target in targets:
		_resolve_hit(
			target,
			current_damage,
			0.70,
			GRAND_SWEEP_ATTACK_ID,
			WHIRLING_BOUGH,
			effect_set
		)
	if owner_branch.has_method("play_strength_talent_feedback"):
		owner_branch.call("play_strength_talent_feedback", &"grand_sweep")


func _resolve_hit(
	target: Node2D,
	current_damage: float,
	damage_multiplier: float,
	attack_id: StringName,
	effect_id: StringName,
	effect_set: StrengthTalentEffectSet
) -> bool:
	if not _is_valid_target(target):
		return false
	var context := AttackContext.new(owner_branch, target, current_damage)
	context.attack_id = attack_id
	context.damage_multiplier = damage_multiplier
	context.is_secondary_attack = true
	context.add_tag(&"strength")
	context.add_tag(&"secondary_attack")
	context.add_tag(effect_id)
	var resolved: bool = AttackResolver.resolve_damage(context)
	if resolved:
		effect_set.apply_after_resolved_secondary(target)
	return resolved


func _find_targets_near(
	center: Node2D,
	radius: float,
	excluded_ids: Dictionary,
	maximum_targets: int
) -> Array[Node2D]:
	var candidates: Array[Node2D] = []
	if not is_instance_valid(owner_branch) or not owner_branch.is_inside_tree():
		return candidates
	for enemy in owner_branch.get_tree().get_nodes_in_group("enemies"):
		if enemy is not Node2D or not _is_valid_target(enemy):
			continue
		var enemy_node := enemy as Node2D
		if excluded_ids.has(enemy_node.get_instance_id()):
			continue
		if enemy_node.global_position.distance_to(center.global_position) > radius:
			continue
		candidates.append(enemy_node)
	candidates.sort_custom(
		func(first: Node2D, second: Node2D) -> bool:
			return first.global_position.distance_squared_to(center.global_position) < second.global_position.distance_squared_to(center.global_position)
	)
	if candidates.size() > maximum_targets:
		candidates.resize(maximum_targets)
	return candidates


func _is_valid_target(target: Node) -> bool:
	return (
		is_instance_valid(owner_branch)
		and owner_branch.has_method("is_valid_attack_target")
		and bool(owner_branch.call("is_valid_attack_target", target))
	)


func _target_is_alive(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	if target.has_method("get_current_health"):
		return float(target.call("get_current_health")) > 0.0
	if target.has_method("is_targetable"):
		return bool(target.call("is_targetable"))
	return true


func _has_effect(effect_id: StringName) -> bool:
	return active_effect_ids.has(effect_id)


func reset_runtime_state() -> void:
	resolved_primary_attack_count = 0
