class_name BlossomBranchVisual
extends Node2D


@export_category("Visual Growth")

@export_range(2, 50, 1)
var mature_branch_level: int = 10

@export var bud_length: float = 34.0
@export var mature_length: float = 155.0

@export var bud_thickness: float = 8.0
@export var mature_thickness: float = 22.0

@export var first_flower_level: int = 1
@export var maximum_flowers: int = 7

@export var flower_radius: float = 8.0
@export var flower_center_radius: float = 3.0


var branch_level: int = 1
var tree_growth_factor: float = 1.0
var facing_direction: float = 1.0


func set_branch_level(
	new_branch_level: int
) -> void:
	var safe_branch_level: int = max(
		new_branch_level,
		1
	)

	if branch_level == safe_branch_level:
		return

	branch_level = safe_branch_level
	queue_redraw()


func set_tree_growth_factor(
	new_growth_factor: float
) -> void:
	var safe_growth_factor: float = max(
		new_growth_factor,
		0.0
	)

	if is_equal_approx(
		tree_growth_factor,
		safe_growth_factor
	):
		return

	tree_growth_factor = safe_growth_factor
	queue_redraw()


func set_facing_direction(
	new_facing_direction: float
) -> void:
	var safe_facing_direction: float = (
		-1.0
		if new_facing_direction < 0.0
		else 1.0
	)

	if facing_direction == safe_facing_direction:
		return

	facing_direction = safe_facing_direction
	queue_redraw()


func get_branch_growth_progress() -> float:
	var safe_mature_level: int = max(
		mature_branch_level,
		2
	)

	var raw_progress: float = clamp(
		float(branch_level - 1)
		/ float(safe_mature_level - 1),
		0.0,
		1.0
	)

	return 1.0 - pow(
		1.0 - raw_progress,
		2.0
	)


func get_current_length() -> float:
	var current_length: float = lerp(
		bud_length,
		mature_length,
		get_branch_growth_progress()
	)

	return current_length * tree_growth_factor


func get_current_thickness() -> float:
	var current_thickness: float = lerp(
		bud_thickness,
		mature_thickness,
		get_branch_growth_progress()
	)

	return current_thickness * tree_growth_factor


func get_visible_flower_count() -> int:
	if branch_level < first_flower_level:
		return 0

	return clamp(
		branch_level
		- first_flower_level
		+ 1,
		1,
		maximum_flowers
	)


func _draw() -> void:
	var current_length: float = (
		get_current_length()
	)

	var current_thickness: float = (
		get_current_thickness()
	)

	var branch_end := Vector2(
		facing_direction * current_length,
		0.0
	)

	draw_line(
		Vector2.ZERO,
		branch_end,
		Color("6f5532"),
		current_thickness,
		true
	)

	draw_flowers(
		current_length,
		facing_direction
	)


func draw_flowers(
	current_length: float,
	current_facing_direction: float
) -> void:
	var flower_count: int = get_visible_flower_count()

	for flower_index in range(flower_count):
		var progress: float = (
			float(flower_index + 1)
			/ float(flower_count + 1)
		)

		var vertical_offset: float = 10.0

		if flower_index % 2 == 0:
			vertical_offset = -10.0

		var flower_position := Vector2(
			current_facing_direction
			* current_length
			* lerp(
				0.25,
				0.95,
				progress
			),
			vertical_offset
		)

		draw_flower(flower_position)


func draw_flower(
	flower_position: Vector2
) -> void:
	var petal_color := Color("ef9fc2")
	var flower_center_color := Color("f2c94c")

	var petal_distance: float = (
		flower_radius * 0.65
	)

	var petal_radius: float = (
		flower_radius * 0.55
	)

	for petal_index in range(5):
		var angle: float = (
			TAU
			* float(petal_index)
			/ 5.0
		)

		var petal_position := (
			flower_position
			+ Vector2(
				cos(angle),
				sin(angle)
			)
			* petal_distance
		)

		draw_circle(
			petal_position,
			petal_radius,
			petal_color
		)

	draw_circle(
		flower_position,
		flower_center_radius,
		flower_center_color
	)
