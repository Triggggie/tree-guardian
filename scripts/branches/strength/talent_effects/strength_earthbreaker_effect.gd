class_name StrengthEarthbreakerEffect
extends RefCounted


const EARTHBREAKER: StringName = &"earthbreaker"
const FAULT_LINE: StringName = &"fault_line"
const AFTERSHOCK: StringName = &"aftershock"
const WORLDROOT_SLAM: StringName = &"worldroot_slam"

const EARTHBREAKER_ATTACK_ID: StringName = &"strength_earthbreaker"
const AFTERSHOCK_ATTACK_ID: StringName = &"strength_aftershock"
const WORLDROOT_ATTACK_ID: StringName = &"strength_worldroot_slam"


var owner_branch: Node2D
var active_effect_ids: Dictionary = {}
var resolved_primary_attack_count: int = 0
var earthbreaker_trigger_count: int = 0
var runtime_generation: int = 0


func configure(configured_owner: Node2D) -> void:
	owner_branch = configured_owner


func set_active_effect_ids(effect_ids: Dictionary) -> void:
	active_effect_ids = effect_ids


func on_primary_resolved(
	primary_target: Node2D,
	current_damage: float,
	effect_set: StrengthTalentEffectSet
) -> void:
	if not _has_effect(EARTHBREAKER):
		return
	resolved_primary_attack_count += 1
	if resolved_primary_attack_count % 3 != 0:
		return

	earthbreaker_trigger_count += 1
	var is_worldroot: bool = (
		_has_effect(WORLDROOT_SLAM)
		and earthbreaker_trigger_count % 3 == 0
	)
	var targets: Array[Node2D] = _find_shockwave_targets(
		primary_target,
		is_worldroot
	)
	var multiplier: float = 0.70 if is_worldroot else 0.40
	var attack_id: StringName = (
		WORLDROOT_ATTACK_ID if is_worldroot else EARTHBREAKER_ATTACK_ID
	)
	var effect_id: StringName = (
		WORLDROOT_SLAM if is_worldroot else EARTHBREAKER
	)
	_resolve_targets(
		targets,
		current_damage,
		multiplier,
		attack_id,
		effect_id,
		is_worldroot,
		effect_set
	)
	if owner_branch.has_method("play_strength_talent_feedback"):
		owner_branch.call(
			"play_strength_talent_feedback",
			&"worldroot_slam" if is_worldroot else &"earthbreaker"
		)

	if _has_effect(AFTERSHOCK):
		_schedule_aftershock(
			targets,
			current_damage,
			multiplier * 0.50,
			effect_set
		)


func _schedule_aftershock(
	targets: Array[Node2D],
	current_damage: float,
	damage_multiplier: float,
	effect_set: StrengthTalentEffectSet
) -> void:
	if not is_instance_valid(owner_branch) or not owner_branch.is_inside_tree():
		return
	var target_ids: Array[int] = []
	for target in targets:
		if is_instance_valid(target):
			target_ids.append(target.get_instance_id())
	var scheduled_generation: int = runtime_generation
	var timer: SceneTreeTimer = owner_branch.get_tree().create_timer(0.25)
	timer.timeout.connect(
		func() -> void:
			if not _is_runtime_active(scheduled_generation):
				return
			var valid_targets: Array[Node2D] = []
			for target_id in target_ids:
				var target_object: Object = instance_from_id(target_id)
				if target_object is Node2D and _is_valid_target(target_object):
					valid_targets.append(target_object as Node2D)
			_resolve_targets(
				valid_targets,
				current_damage,
				damage_multiplier,
				AFTERSHOCK_ATTACK_ID,
				AFTERSHOCK,
				false,
				effect_set
			)
	)


func _find_shockwave_targets(
	primary_target: Node2D,
	is_worldroot: bool
) -> Array[Node2D]:
	var candidates: Array[Node2D] = []
	if not is_instance_valid(owner_branch) or not owner_branch.is_inside_tree():
		return candidates
	var uses_line: bool = _has_effect(FAULT_LINE) or is_worldroot
	var maximum_targets: int = 8 if is_worldroot else (5 if uses_line else 4)
	var line_length: float = 380.0 if is_worldroot else 260.0
	var half_width: float = 140.0 if is_worldroot else 90.0
	var local_radius: float = 220.0 if is_worldroot else 140.0
	var facing_direction: float = float(owner_branch.call("get_facing_direction"))
	for enemy in owner_branch.get_tree().get_nodes_in_group("enemies"):
		if enemy is not Node2D or enemy == primary_target or not _is_valid_target(enemy):
			continue
		var target := enemy as Node2D
		if uses_line:
			var outward_distance: float = (
				(target.global_position.x - primary_target.global_position.x)
				* facing_direction
			)
			if outward_distance < 0.0 or outward_distance > line_length:
				continue
			if abs(target.global_position.y - primary_target.global_position.y) > half_width:
				continue
		else:
			if target.global_position.distance_to(primary_target.global_position) > local_radius:
				continue
		candidates.append(target)
	candidates.sort_custom(
		func(first: Node2D, second: Node2D) -> bool:
			return first.global_position.distance_squared_to(primary_target.global_position) < second.global_position.distance_squared_to(primary_target.global_position)
	)
	if candidates.size() > maximum_targets:
		candidates.resize(maximum_targets)
	return candidates


func _resolve_targets(
	targets: Array[Node2D],
	current_damage: float,
	damage_multiplier: float,
	attack_id: StringName,
	effect_id: StringName,
	apply_worldroot_knockback: bool,
	effect_set: StrengthTalentEffectSet
) -> void:
	var resolved_ids: Dictionary = {}
	for target in targets:
		if not _is_valid_target(target) or resolved_ids.has(target.get_instance_id()):
			continue
		resolved_ids[target.get_instance_id()] = true
		var context := AttackContext.new(owner_branch, target, current_damage)
		context.attack_id = attack_id
		context.damage_multiplier = damage_multiplier
		context.is_secondary_attack = true
		context.add_tag(&"strength")
		context.add_tag(&"secondary_attack")
		context.add_tag(effect_id)
		if not AttackResolver.resolve_damage(context):
			continue
		effect_set.apply_after_resolved_secondary(target)
		if apply_worldroot_knockback and _is_normal_enemy(target):
			if target.has_method("apply_knockback"):
				target.call("apply_knockback", 25.0)


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


func _is_runtime_active(expected_generation: int) -> bool:
	return (
		expected_generation == runtime_generation
		and is_instance_valid(owner_branch)
		and owner_branch.is_inside_tree()
		and bool(owner_branch.get("combat_enabled"))
	)


func _has_effect(effect_id: StringName) -> bool:
	return active_effect_ids.has(effect_id)


func reset_runtime_state() -> void:
	resolved_primary_attack_count = 0
	earthbreaker_trigger_count = 0
	runtime_generation += 1
