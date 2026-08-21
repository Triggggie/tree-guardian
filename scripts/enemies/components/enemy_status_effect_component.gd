class_name EnemyStatusEffectComponent
extends Node2D


signal status_effect_changed(
	status_effect_id: StringName,
	stack_count: int,
	remaining_duration: float
)

signal status_effect_removed(status_effect_id: StringName)


var affected_enemy: Node2D
var active_effects_by_id: Dictionary = {}


func initialize(enemy: Node2D) -> bool:
	if not is_instance_valid(enemy):
		return false

	affected_enemy = enemy
	position = _resolve_indicator_position()
	return true


func apply_effect(
	definition: StatusEffectDefinition,
	source: Node,
	stack_amount: int = 1,
	periodic_value_override: float = -1.0,
	duration_override: float = -1.0
) -> bool:
	if (
		not is_instance_valid(affected_enemy)
		or not is_instance_valid(definition)
		or not definition.is_valid_definition()
		or stack_amount < 1
	):
		return false

	var status_effect_id: StringName = definition.status_effect_id
	var state: Dictionary = active_effects_by_id.get(status_effect_id, {}) as Dictionary
	var current_stacks: int = int(state.get(&"stacks", 0))
	var new_stacks: int = 1
	var applied_duration: float = (
		duration_override
		if duration_override > 0.0
		else definition.base_duration
	)
	var remaining_duration: float = applied_duration

	match definition.stack_mode:
		StatusEffectDefinition.StackMode.ADD_DURATION:
			new_stacks = max(current_stacks, 1)
			remaining_duration = float(state.get(&"remaining_duration", 0.0)) + applied_duration
		StatusEffectDefinition.StackMode.STACK_INTENSITY:
			new_stacks = min(current_stacks + stack_amount, definition.maximum_stacks)
		StatusEffectDefinition.StackMode.REPLACE:
			new_stacks = min(stack_amount, definition.maximum_stacks)
		_:
			new_stacks = max(current_stacks, 1)

	var periodic_value: float = definition.base_periodic_value
	if periodic_value_override >= 0.0:
		periodic_value = periodic_value_override

	active_effects_by_id[status_effect_id] = {
		&"definition": definition,
		&"stacks": new_stacks,
		&"remaining_duration": remaining_duration,
		&"tick_progress": float(state.get(&"tick_progress", 0.0)),
		&"periodic_value": max(periodic_value, 0.0),
		&"source": weakref(source) if is_instance_valid(source) else null
	}
	status_effect_changed.emit(status_effect_id, new_stacks, remaining_duration)
	queue_redraw()
	return true


func get_stack_count(status_effect_id: StringName) -> int:
	var state: Dictionary = active_effects_by_id.get(status_effect_id, {}) as Dictionary
	return int(state.get(&"stacks", 0))


func get_remaining_duration(status_effect_id: StringName) -> float:
	var state: Dictionary = active_effects_by_id.get(status_effect_id, {}) as Dictionary
	return max(float(state.get(&"remaining_duration", 0.0)), 0.0)


func has_effect(status_effect_id: StringName) -> bool:
	return active_effects_by_id.has(status_effect_id)


func clear_all_effects() -> void:
	var effect_ids: Array = active_effects_by_id.keys()
	active_effects_by_id.clear()
	for effect_id_value in effect_ids:
		status_effect_removed.emit(StringName(effect_id_value))
	queue_redraw()


func _process(delta: float) -> void:
	if active_effects_by_id.is_empty():
		return
	if not _is_enemy_available():
		clear_all_effects()
		return

	for status_effect_id_value in active_effects_by_id.keys():
		var status_effect_id := StringName(status_effect_id_value)
		var state: Dictionary = active_effects_by_id.get(status_effect_id, {}) as Dictionary
		var definition: StatusEffectDefinition = state.get(&"definition") as StatusEffectDefinition
		if not is_instance_valid(definition):
			_remove_effect(status_effect_id)
			continue

		var elapsed: float = max(delta, 0.0)
		if not definition.is_permanent:
			elapsed = min(elapsed, max(float(state.get(&"remaining_duration", 0.0)), 0.0))
			state[&"remaining_duration"] = max(
				float(state.get(&"remaining_duration", 0.0)) - max(delta, 0.0),
				0.0
			)

		if definition.periodic_effect_id != &"":
			state[&"tick_progress"] = float(state.get(&"tick_progress", 0.0)) + elapsed
			while float(state[&"tick_progress"]) + 0.00001 >= definition.tick_interval:
				state[&"tick_progress"] = float(state[&"tick_progress"]) - definition.tick_interval
				if not _apply_periodic_effect(definition, state):
					break

		if not active_effects_by_id.has(status_effect_id):
			continue
		if not definition.is_permanent and float(state[&"remaining_duration"]) <= 0.0:
			_remove_effect(status_effect_id)
		else:
			active_effects_by_id[status_effect_id] = state


func _apply_periodic_effect(
	definition: StatusEffectDefinition,
	state: Dictionary
) -> bool:
	if not _is_enemy_available():
		clear_all_effects()
		return false
	if definition.periodic_effect_id != StatusEffectDefinition.PERIODIC_DAMAGE:
		return true

	var stacks: int = int(state.get(&"stacks", 0))
	var damage_per_stack: float = float(state.get(&"periodic_value", 0.0))
	var attack_context := AttackContext.new(
		self,
		affected_enemy,
		damage_per_stack * stacks
	)
	attack_context.attack_id = &"status_effect_tick"
	attack_context.add_tag(&"status_effect")
	attack_context.add_tag(&"periodic_damage")
	attack_context.set_metadata_value(&"status_effect_id", definition.status_effect_id)
	return AttackResolver.resolve_damage(attack_context)


func add_xp(amount: int) -> void:
	for state_value in active_effects_by_id.values():
		var state := state_value as Dictionary
		var source_reference: WeakRef = state.get(&"source") as WeakRef
		if source_reference == null:
			continue
		var source: Object = source_reference.get_ref()
		if is_instance_valid(source) and source.has_method("add_xp"):
			source.call("add_xp", amount)
			return


func _is_enemy_available() -> bool:
	return (
		is_instance_valid(affected_enemy)
		and affected_enemy.is_inside_tree()
		and not affected_enemy.is_queued_for_deletion()
		and affected_enemy.has_method("is_targetable")
		and bool(affected_enemy.call("is_targetable"))
	)


func _remove_effect(status_effect_id: StringName) -> void:
	if not active_effects_by_id.erase(status_effect_id):
		return
	status_effect_removed.emit(status_effect_id)
	queue_redraw()


func _resolve_indicator_position() -> Vector2:
	if not is_instance_valid(affected_enemy):
		return Vector2.ZERO
	var health_bar: Control = affected_enemy.get_node_or_null("HealthBar") as Control
	if is_instance_valid(health_bar):
		return Vector2(0.0, health_bar.position.y - 12.0)
	return Vector2(0.0, -60.0)


func _draw() -> void:
	var poison_stacks: int = get_stack_count(&"poison")
	if poison_stacks <= 0:
		return
	for stack_index in range(poison_stacks):
		var x_offset: float = (float(stack_index) - float(poison_stacks - 1) * 0.5) * 10.0
		draw_circle(Vector2(x_offset, 0.0), 4.0, Color("73d13d"))
		draw_circle(Vector2(x_offset, 0.0), 1.5, Color("d9ff79"))
