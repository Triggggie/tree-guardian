class_name AttackContext
extends RefCounted


var attack_id: StringName = &""

var source: Node
var target: Node2D

var base_damage: float = 0.0
var additive_damage: float = 0.0
var damage_multiplier: float = 1.0

var is_secondary_attack: bool = false

var tags: Array[StringName] = []
var metadata: Dictionary = {}


func _init(
	source_node: Node = null,
	target_node: Node2D = null,
	initial_base_damage: float = 0.0
) -> void:
	source = source_node
	target = target_node
	base_damage = initial_base_damage


func get_final_damage() -> float:
	var safe_multiplier: float = max(
		damage_multiplier,
		0.0
	)

	return max(
		(
			base_damage
			+ additive_damage
		)
		* safe_multiplier,
		0.0
	)


func is_valid_context() -> bool:
	if attack_id == &"":
		return false

	if not is_instance_valid(source):
		return false

	if not is_instance_valid(target):
		return false

	if base_damage < 0.0:
		return false

	if damage_multiplier < 0.0:
		return false

	return true


func add_tag(
	tag_id: StringName
) -> void:
	if tag_id == &"":
		return

	if tag_id in tags:
		return

	tags.append(tag_id)


func has_tag(
	tag_id: StringName
) -> bool:
	return tag_id in tags


func set_metadata_value(
	key: StringName,
	value: Variant
) -> void:
	if key == &"":
		return

	metadata[key] = value


func get_metadata_value(
	key: StringName,
	default_value: Variant = null
) -> Variant:
	return metadata.get(
		key,
		default_value
	)


func create_for_target(
	new_target: Node2D,
	secondary_attack: bool = true
) -> AttackContext:
	var new_context := AttackContext.new(
		source,
		new_target,
		base_damage
	)

	new_context.attack_id = attack_id
	new_context.additive_damage = additive_damage
	new_context.damage_multiplier = damage_multiplier
	new_context.is_secondary_attack = secondary_attack

	for tag_id in tags:
		new_context.tags.append(tag_id)

	new_context.metadata = metadata.duplicate(
		true
	)

	return new_context
