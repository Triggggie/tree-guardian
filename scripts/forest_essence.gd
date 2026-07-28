extends Node2D


@export var pickup_delay: float = 0.4
@export var move_speed: float = 550.0
@export var collect_distance: float = 24.0
@export var essence_value: int = 1

var target_tree: Node2D
var elapsed_time: float = 0.0


func _ready() -> void:
	target_tree = (
		get_tree().get_first_node_in_group("tree")
		as Node2D
	)

	# Orby nevylétnou všechny ve zcela stejný okamžik.
	pickup_delay += randf_range(
		0.0,
		0.18
	)


func _process(delta: float) -> void:
	elapsed_time += delta

	if elapsed_time < pickup_delay:
		return

	if not is_instance_valid(target_tree):
		return

	global_position = global_position.move_toward(
		target_tree.global_position,
		move_speed * delta
	)

	if (
		global_position.distance_to(
			target_tree.global_position
		)
		<= collect_distance
	):
		collect()


func collect() -> void:
	if (
		is_instance_valid(target_tree)
		and target_tree.has_method(
			"add_forest_essence"
		)
	):
		target_tree.add_forest_essence(
			essence_value
		)

	queue_free()


func _draw() -> void:
	draw_circle(
		Vector2.ZERO,
		14.0,
		Color("63d471")
	)
