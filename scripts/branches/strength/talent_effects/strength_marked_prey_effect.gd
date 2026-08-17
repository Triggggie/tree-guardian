class_name StrengthMarkedPreyEffect
extends RefCounted


const EFFECT_ID: StringName = &"marked_prey"


var damage_per_stack: float = 0.10
var maximum_stacks: int = 5
var target_instance_id: int = 0
var stacks: int = 0


func configure(
	configured_damage_per_stack: float,
	configured_maximum_stacks: int
) -> void:
	damage_per_stack = configured_damage_per_stack
	maximum_stacks = max(
		configured_maximum_stacks,
		1
	)


func get_effect_id() -> StringName:
	return EFFECT_ID


func get_damage(
	target: Node2D,
	base_damage: float
) -> float:
	if not is_instance_valid(target):
		reset_runtime_state()
		return base_damage

	var current_target_id: int = (
		target.get_instance_id()
	)

	if target_instance_id != current_target_id:
		target_instance_id = current_target_id
		stacks = 0
	else:
		stacks = min(
			stacks + 1,
			maximum_stacks
		)

	var damage_multiplier: float = (
		1.0
		+ stacks
		* damage_per_stack
	)

	return base_damage * damage_multiplier


func begin_target(
	target: Node2D,
	starting_stacks: int = 0
) -> void:
	if not is_instance_valid(target):
		reset_runtime_state()
		return

	target_instance_id = target.get_instance_id()
	stacks = clamp(
		starting_stacks,
		0,
		maximum_stacks
	) - 1


func set_stack_count(new_stacks: int) -> void:
	stacks = clamp(
		new_stacks,
		0,
		maximum_stacks
	)


func get_maximum_stacks() -> int:
	return maximum_stacks


func reset_runtime_state() -> void:
	target_instance_id = 0
	stacks = 0


func get_target_instance_id() -> int:
	return target_instance_id


func get_stack_count() -> int:
	return stacks
