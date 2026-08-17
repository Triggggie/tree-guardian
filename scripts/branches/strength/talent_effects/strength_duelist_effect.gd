class_name StrengthDuelistEffect
extends RefCounted


const EXECUTIONER: StringName = &"executioner"
const CULL_THE_WEAK: StringName = &"cull_the_weak"
const FINISHING_RHYTHM: StringName = &"finishing_rhythm"
const FINAL_CUT: StringName = &"final_cut"
const RELENTLESS: StringName = &"relentless"
const PURSUIT: StringName = &"pursuit"
const UNBROKEN_COMBO: StringName = &"unbroken_combo"
const RELENTLESS_FLURRY: StringName = &"relentless_flurry"
const COMBO_ATTACK_ID: StringName = &"strength_combo_followup"


var owner_branch: Node2D
var marked_effect: StrengthMarkedPreyEffect
var active_effect_ids: Dictionary = {}
var cull_carryover_stacks: int = 0
var recent_snapshots: Array[Dictionary] = []
var finishing_target_id: int = 0
var finishing_hit_count: int = 0
var combo_target_id: int = 0
var combo_hit_count: int = 0
var pending_target_id: int = 0
var pending_stack_count: int = 0
var pending_finishing_hit_count: int = 0
var runtime_generation: int = 0


func configure(
	configured_owner: Node2D,
	configured_marked_effect: StrengthMarkedPreyEffect
) -> void:
	owner_branch = configured_owner
	marked_effect = configured_marked_effect


func set_active_effect_ids(effect_ids: Dictionary) -> void:
	active_effect_ids = effect_ids
	if not _has_effect(marked_effect.get_effect_id()):
		reset_runtime_state()


func get_primary_damage(target: Node2D, base_damage: float) -> float:
	if not _has_effect(marked_effect.get_effect_id()):
		return base_damage
	_prune_snapshots()
	_prepare_target_change(target)
	var damage: float = marked_effect.get_damage(target, base_damage)
	var stack_count: int = marked_effect.get_stack_count()
	var maximum_stacks: int = marked_effect.get_maximum_stacks()
	var health_ratio: float = _get_health_ratio(target)
	var target_id: int = target.get_instance_id()

	if _has_effect(EXECUTIONER) and stack_count >= maximum_stacks and health_ratio <= 0.35:
		damage *= 1.50

	pending_finishing_hit_count = 0
	if _has_effect(FINISHING_RHYTHM) and stack_count >= maximum_stacks:
		var previous_count: int = finishing_hit_count if finishing_target_id == target_id else 0
		pending_finishing_hit_count = previous_count + 1
		if pending_finishing_hit_count % 3 == 0:
			damage *= 2.0
			_play_feedback(&"finisher")

	if _has_effect(FINAL_CUT) and stack_count >= maximum_stacks and health_ratio <= 0.15:
		if _is_normal_enemy(target):
			damage = max(damage, _get_current_health(target))
		else:
			damage *= 2.0
		_play_feedback(&"final_cut")

	pending_target_id = target_id
	pending_stack_count = stack_count
	return damage


func on_primary_resolved(target: Node2D, current_damage: float) -> void:
	if not _has_effect(marked_effect.get_effect_id()):
		return
	var target_id: int = target.get_instance_id()
	if target_id != pending_target_id:
		return
	if pending_finishing_hit_count > 0:
		finishing_target_id = target_id
		finishing_hit_count = pending_finishing_hit_count

	if not _target_is_alive(target):
		if _has_effect(CULL_THE_WEAK) and pending_stack_count >= 3:
			cull_carryover_stacks = 2
		finishing_target_id = 0
		finishing_hit_count = 0
		combo_target_id = 0
		combo_hit_count = 0
		return

	if not _has_effect(UNBROKEN_COMBO):
		return
	if pending_stack_count < marked_effect.get_maximum_stacks():
		combo_target_id = target_id
		combo_hit_count = 0
		return
	if combo_target_id == target_id:
		combo_hit_count += 1
	else:
		combo_target_id = target_id
		combo_hit_count = 1
	if combo_hit_count % 2 != 0:
		return
	var followup_count: int = 2 if _has_effect(RELENTLESS_FLURRY) else 1
	for followup_index in range(followup_count):
		_schedule_followup(
			target_id,
			current_damage,
			0.08 * float(followup_index + 1)
		)


func cancel_pending_primary() -> void:
	pending_target_id = 0
	pending_stack_count = 0
	pending_finishing_hit_count = 0


func _prepare_target_change(target: Node2D) -> void:
	var target_id: int = target.get_instance_id()
	var previous_target_id: int = marked_effect.get_target_instance_id()
	if previous_target_id == target_id:
		return
	var previous_stacks: int = marked_effect.get_stack_count()
	if _has_effect(PURSUIT) and previous_target_id != 0:
		_store_snapshot(previous_target_id, previous_stacks)
	var starting_stacks: int = 0
	if _has_effect(RELENTLESS):
		starting_stacks = int(floor(float(max(previous_stacks, 0)) / 2.0))
	if cull_carryover_stacks > starting_stacks:
		starting_stacks = cull_carryover_stacks
	if cull_carryover_stacks > 0:
		cull_carryover_stacks = 0
	if _has_effect(PURSUIT):
		starting_stacks = max(starting_stacks, _get_snapshot_stacks(target_id))
	marked_effect.begin_target(target, starting_stacks)
	finishing_target_id = 0
	finishing_hit_count = 0
	combo_target_id = 0
	combo_hit_count = 0


func _store_snapshot(target_id: int, stack_count: int) -> void:
	if target_id == 0:
		return
	for index in range(recent_snapshots.size() - 1, -1, -1):
		if int(recent_snapshots[index].get("target_id", 0)) == target_id:
			recent_snapshots.remove_at(index)
	var target_object: Object = instance_from_id(target_id)
	if not is_instance_valid(target_object):
		return
	recent_snapshots.push_front({
		"target_id": target_id,
		"target": weakref(target_object),
		"stacks": stack_count,
		"expires_at": Time.get_ticks_msec() + 4000
	})
	if recent_snapshots.size() > 3:
		recent_snapshots.resize(3)


func _get_snapshot_stacks(target_id: int) -> int:
	for snapshot in recent_snapshots:
		if int(snapshot.get("target_id", 0)) == target_id:
			return int(snapshot.get("stacks", 0))
	return 0


func _prune_snapshots() -> void:
	var now: int = Time.get_ticks_msec()
	for index in range(recent_snapshots.size() - 1, -1, -1):
		var snapshot: Dictionary = recent_snapshots[index]
		var target_reference := snapshot.get("target") as WeakRef
		if (
			int(snapshot.get("expires_at", 0)) <= now
			or target_reference == null
			or not is_instance_valid(target_reference.get_ref())
		):
			recent_snapshots.remove_at(index)


func _schedule_followup(
	target_id: int,
	current_damage: float,
	delay: float
) -> void:
	if not is_instance_valid(owner_branch) or not owner_branch.is_inside_tree():
		return
	var scheduled_generation: int = runtime_generation
	var timer: SceneTreeTimer = owner_branch.get_tree().create_timer(delay)
	timer.timeout.connect(
		func() -> void:
			if not _is_runtime_active(scheduled_generation):
				return
			var target_object: Object = instance_from_id(target_id)
			if target_object is not Node2D or not _is_valid_target(target_object):
				return
			var context := AttackContext.new(owner_branch, target_object as Node2D, current_damage)
			context.attack_id = COMBO_ATTACK_ID
			context.damage_multiplier = 0.35
			context.is_secondary_attack = true
			context.add_tag(&"strength")
			context.add_tag(&"secondary_attack")
			context.add_tag(COMBO_ATTACK_ID)
			AttackResolver.resolve_damage(context)
	)


func _get_current_health(target: Node) -> float:
	if target.has_method("get_current_health"):
		return max(float(target.call("get_current_health")), 0.0)
	return INF


func _get_health_ratio(target: Node) -> float:
	if target.has_method("get_health_ratio"):
		return clamp(float(target.call("get_health_ratio")), 0.0, 1.0)
	if target.has_method("get_current_health") and target.has_method("get_maximum_health"):
		var maximum_health: float = float(target.call("get_maximum_health"))
		if maximum_health > 0.0:
			return clamp(float(target.call("get_current_health")) / maximum_health, 0.0, 1.0)
	return 1.0


func _target_is_alive(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	if target.has_method("get_current_health"):
		return float(target.call("get_current_health")) > 0.0
	if target.has_method("is_targetable"):
		return bool(target.call("is_targetable"))
	return true


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


func _play_feedback(feedback_id: StringName) -> void:
	if is_instance_valid(owner_branch) and owner_branch.has_method("play_strength_talent_feedback"):
		owner_branch.call("play_strength_talent_feedback", feedback_id)


func _has_effect(effect_id: StringName) -> bool:
	return active_effect_ids.has(effect_id)


func reset_runtime_state() -> void:
	marked_effect.reset_runtime_state()
	cull_carryover_stacks = 0
	recent_snapshots.clear()
	finishing_target_id = 0
	finishing_hit_count = 0
	combo_target_id = 0
	combo_hit_count = 0
	cancel_pending_primary()
	runtime_generation += 1
