class_name StrengthTalentEffectSet
extends RefCounted


var owner_branch: Node2D
var sweeping_strike_effect: StrengthSweepingStrikeEffect
var rebuff_effect: StrengthRebuffEffect
var marked_prey_effect: StrengthMarkedPreyEffect
var crusher_effect: StrengthCrusherEffect
var earthbreaker_effect: StrengthEarthbreakerEffect
var warden_effect: StrengthWardenEffect
var duelist_effect: StrengthDuelistEffect

var active_effect_ids: Dictionary = {}
var warned_unsupported_effect_ids: Dictionary = {}


func _init() -> void:
	sweeping_strike_effect = StrengthSweepingStrikeEffect.new()
	rebuff_effect = StrengthRebuffEffect.new()
	marked_prey_effect = StrengthMarkedPreyEffect.new()
	crusher_effect = StrengthCrusherEffect.new()
	earthbreaker_effect = StrengthEarthbreakerEffect.new()
	warden_effect = StrengthWardenEffect.new()
	duelist_effect = StrengthDuelistEffect.new()


func configure(
	configured_owner_branch: Node2D,
	sweeping_damage_multiplier: float,
	sweeping_search_radius: float,
	rebuff_distance: float,
	marked_damage_per_stack: float,
	marked_maximum_stacks: int
) -> void:
	owner_branch = configured_owner_branch

	sweeping_strike_effect.configure(
		owner_branch,
		sweeping_damage_multiplier,
		sweeping_search_radius
	)

	rebuff_effect.configure(
		owner_branch,
		rebuff_distance
	)

	marked_prey_effect.configure(
		marked_damage_per_stack,
		marked_maximum_stacks
	)

	crusher_effect.configure(
		owner_branch,
		sweeping_strike_effect
	)
	earthbreaker_effect.configure(owner_branch)
	warden_effect.configure(owner_branch, rebuff_effect)
	duelist_effect.configure(owner_branch, marked_prey_effect)


func set_active_effect_ids(
	effect_ids: Array[StringName]
) -> void:
	active_effect_ids.clear()

	var supported_effect_ids: Dictionary = {}

	for supported_effect_id in get_supported_effect_ids():
		supported_effect_ids[supported_effect_id] = true

	for effect_id in effect_ids:
		if effect_id == &"":
			continue

		if supported_effect_ids.has(effect_id):
			active_effect_ids[effect_id] = true
			continue

		if warned_unsupported_effect_ids.has(effect_id):
			continue

		warned_unsupported_effect_ids[effect_id] = true
		push_warning(
			"StrengthTalentEffectSet: Unsupported effect ID "
			+ "'%s' was ignored."
			% effect_id
		)

	crusher_effect.set_active_effect_ids(active_effect_ids)
	earthbreaker_effect.set_active_effect_ids(active_effect_ids)
	warden_effect.set_active_effect_ids(active_effect_ids)
	duelist_effect.set_active_effect_ids(active_effect_ids)


func get_supported_effect_ids() -> Array[StringName]:
	return [
		sweeping_strike_effect.get_effect_id(),
		rebuff_effect.get_effect_id(),
		marked_prey_effect.get_effect_id(),
		&"cleaver",
		&"serrated_arc",
		&"reaping_sweep",
		&"whirling_bough",
		&"earthbreaker",
		&"fault_line",
		&"aftershock",
		&"worldroot_slam",
		&"disruptor",
		&"staggering_blow",
		&"disruptive_arc",
		&"uproot",
		&"protector",
		&"hold_the_line",
		&"sentinel_reflex",
		&"last_bastion",
		&"executioner",
		&"cull_the_weak",
		&"finishing_rhythm",
		&"final_cut",
		&"relentless",
		&"pursuit",
		&"unbroken_combo",
		&"relentless_flurry"
	]


func has_active_effect(
	effect_id: StringName
) -> bool:
	return active_effect_ids.has(effect_id)


func get_primary_damage(
	target: Node2D,
	base_damage: float
) -> float:
	return duelist_effect.get_primary_damage(
		target,
		base_damage
	)


func find_secondary_target(
	primary_target: Node2D
) -> Node2D:
	if not has_active_effect(
		sweeping_strike_effect.get_effect_id()
	):
		return null

	return sweeping_strike_effect.find_secondary_target(
		primary_target
	)


func configure_secondary_context(
	context: AttackContext
) -> void:
	if not has_active_effect(
		sweeping_strike_effect.get_effect_id()
	):
		return

	sweeping_strike_effect.configure_secondary_context(
		context
	)


func apply_after_resolved_hit(
	target: Node2D
) -> void:
	warden_effect.apply_after_primary_resolved(target)


func apply_after_primary_resolved(
	target: Node2D,
	current_damage: float
) -> void:
	duelist_effect.on_primary_resolved(target, current_damage)
	warden_effect.apply_after_primary_resolved(target)
	crusher_effect.on_primary_resolved(target, current_damage, self)
	earthbreaker_effect.on_primary_resolved(target, current_damage, self)


func apply_after_resolved_secondary(target: Node2D) -> void:
	warden_effect.apply_after_secondary_resolved(target)


func cancel_pending_primary() -> void:
	duelist_effect.cancel_pending_primary()


func find_danger_target() -> Node2D:
	return warden_effect.find_danger_target()


func consume_next_cooldown_multiplier() -> float:
	return warden_effect.consume_next_cooldown_multiplier()


func reset_runtime_state() -> void:
	crusher_effect.reset_runtime_state()
	earthbreaker_effect.reset_runtime_state()
	warden_effect.reset_runtime_state()
	duelist_effect.reset_runtime_state()
