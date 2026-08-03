class_name StrengthTalentEffectSet
extends RefCounted


var owner_branch: Node2D
var sweeping_strike_effect: StrengthSweepingStrikeEffect
var rebuff_effect: StrengthRebuffEffect
var marked_prey_effect: StrengthMarkedPreyEffect

var active_effect_ids: Dictionary = {}
var warned_unsupported_effect_ids: Dictionary = {}


func _init() -> void:
	sweeping_strike_effect = StrengthSweepingStrikeEffect.new()
	rebuff_effect = StrengthRebuffEffect.new()
	marked_prey_effect = StrengthMarkedPreyEffect.new()


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

	if not has_active_effect(
		marked_prey_effect.get_effect_id()
	):
		marked_prey_effect.reset_runtime_state()


func get_supported_effect_ids() -> Array[StringName]:
	return [
		sweeping_strike_effect.get_effect_id(),
		rebuff_effect.get_effect_id(),
		marked_prey_effect.get_effect_id()
	]


func has_active_effect(
	effect_id: StringName
) -> bool:
	return active_effect_ids.has(effect_id)


func get_primary_damage(
	target: Node2D,
	base_damage: float
) -> float:
	if not has_active_effect(
		marked_prey_effect.get_effect_id()
	):
		marked_prey_effect.reset_runtime_state()
		return base_damage

	return marked_prey_effect.get_damage(
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
	if not has_active_effect(
		rebuff_effect.get_effect_id()
	):
		return

	rebuff_effect.apply_after_resolved_hit(
		target
	)


func reset_runtime_state() -> void:
	marked_prey_effect.reset_runtime_state()
