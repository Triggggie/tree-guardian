class_name BlossomProjectile
extends Node2D


@export var travel_speed: float = 420.0
@export var projectile_radius: float = 7.0
@export var maximum_lifetime: float = 5.0

var target: Node2D
var damage: float = 0.0
var damage_source: Node
var lifetime_remaining: float


func setup(
	new_target: Node2D,
	new_damage: float,
	new_damage_source: Node
) -> void:
	target = new_target
	damage = new_damage
	damage_source = new_damage_source
	lifetime_remaining = maximum_lifetime

	queue_redraw()


func _process(delta: float) -> void:
	lifetime_remaining -= delta

	if lifetime_remaining <= 0.0:
		queue_free()
		return

	if not is_instance_valid(target):
		queue_free()
		return

	var target_position: Vector2 = (
		target.global_position
	)

	global_position = global_position.move_toward(
		target_position,
		travel_speed * delta
	)

	var distance_to_target: float = (
		global_position.distance_to(
			target_position
		)
	)

	if distance_to_target > 8.0:
		return

	hit_target()


func hit_target() -> void:
	if not is_instance_valid(target):
		queue_free()
		return

	if target.has_method("take_damage"):
		target.take_damage(
			damage,
			damage_source
		)

	queue_free()


func _draw() -> void:
	var outer_color := Color("f3a4cf")
	var inner_color := Color("fff0fa")

	draw_circle(
		Vector2.ZERO,
		projectile_radius,
		outer_color
	)

	draw_circle(
		Vector2.ZERO,
		projectile_radius * 0.45,
		inner_color
	)
