class_name PoisonVineProjectile
extends Node2D


@export var travel_speed: float = 320.0
@export var maximum_lifetime: float = 2.0


var target: Node2D
var damage_source: Node
var direct_damage: float = 0.0
var poison_damage_per_stack: float = 0.0
var poison_duration: float = 0.0
var lifetime_remaining: float = 0.0


func setup(
	new_target: Node2D,
	new_damage_source: Node,
	new_direct_damage: float,
	new_poison_damage_per_stack: float,
	new_poison_duration: float
) -> void:
	target = new_target
	damage_source = new_damage_source
	direct_damage = max(new_direct_damage, 0.0)
	poison_damage_per_stack = max(new_poison_damage_per_stack, 0.0)
	poison_duration = max(new_poison_duration, 0.0)
	lifetime_remaining = maximum_lifetime
	queue_redraw()


func _process(delta: float) -> void:
	lifetime_remaining -= delta
	if lifetime_remaining <= 0.0 or not _is_target_valid():
		queue_free()
		return

	var target_position: Vector2 = target.global_position
	global_position = global_position.move_toward(
		target_position,
		travel_speed * max(delta, 0.0)
	)
	rotation = global_position.direction_to(target_position).angle()
	if global_position.distance_to(target_position) <= 8.0:
		_hit_target()


func _is_target_valid() -> bool:
	return (
		is_instance_valid(target)
		and target.is_inside_tree()
		and not target.is_queued_for_deletion()
		and target.is_in_group("enemies")
		and target.has_method("is_targetable")
		and bool(target.call("is_targetable"))
		and target.has_method("take_damage")
	)


func _hit_target() -> void:
	if not _is_target_valid():
		queue_free()
		return

	var attack_context := AttackContext.new(
		damage_source,
		target,
		direct_damage
	)
	attack_context.attack_id = &"poison_vine_direct_hit"
	attack_context.add_tag(&"poison_vine")
	attack_context.add_tag(&"projectile")
	attack_context.add_tag(&"basic_attack")
	attack_context.add_tag(&"direct_damage")
	var hit_resolved: bool = AttackResolver.resolve_damage(attack_context)
	if hit_resolved and target.has_method("apply_status_effect"):
		target.call(
			"apply_status_effect",
			&"poison",
			damage_source,
			1,
			poison_damage_per_stack,
			poison_duration
		)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color("56b83f"))
	draw_circle(Vector2.ZERO, 3.0, Color("d6ff61"))
	draw_line(Vector2(-10.0, 0.0), Vector2(-3.0, 0.0), Color("347c36"), 3.0)
