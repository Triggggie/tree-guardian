class_name StrengthBranchVisual
extends Node2D


@export_category("Visual Growth")

@export_range(2, 50, 1)
var mature_branch_level: int = 10

@export var bud_length: float = 38.0
@export var bud_thickness: float = 10.0

@export var mature_length: float = 185.0
@export var mature_thickness: float = 30.0

@export var first_shoot_level: int = 3
@export var shoot_length: float = 27.0
@export var shoot_thickness: float = 6.0

@export var maximum_shoots: int = 5
@export var bud_radius: float = 6.0


var branch_level: int = 1
var tree_growth_factor: float = 1.0
var facing_direction: float = 1.0


func set_branch_level(new_level: int) -> void:
	var safe_level: int = max(new_level, 1)

	if branch_level == safe_level:
		return

	branch_level = safe_level
	queue_redraw()


func set_tree_growth_factor(new_factor: float) -> void:
	var safe_factor: float = max(new_factor, 0.0)

	if is_equal_approx(tree_growth_factor, safe_factor):
		return

	tree_growth_factor = safe_factor
	queue_redraw()


func set_facing_direction(new_direction: float) -> void:
	var safe_direction: float = (
		-1.0 if new_direction < 0.0 else 1.0
	)

	if facing_direction == safe_direction:
		return

	facing_direction = safe_direction
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
	var branch_length: float = lerp(
		bud_length,
		mature_length,
		get_branch_growth_progress()
	)

	return branch_length * tree_growth_factor


func get_current_thickness() -> float:
	var branch_thickness: float = lerp(
		bud_thickness,
		mature_thickness,
		get_branch_growth_progress()
	)

	var tree_thickness_factor: float = lerp(
		0.88,
		1.0,
		tree_growth_factor
	)

	return branch_thickness * tree_thickness_factor


func get_unlocked_shoot_count() -> int:
	if branch_level < first_shoot_level:
		return 0

	return min(
		branch_level - first_shoot_level + 1,
		maximum_shoots
	)


func _draw() -> void:
	var current_length: float = get_current_length()
	var current_thickness: float = get_current_thickness()
	var branch_color := Color("6b4423")
	var young_shoot_color := Color("76502b")
	var bud_color := Color("789447")

	draw_main_branch(
		current_length,
		current_thickness,
		facing_direction,
		branch_color,
		bud_color
	)

	draw_natural_shoots(
		current_length,
		facing_direction,
		young_shoot_color,
		bud_color
	)


func draw_main_branch(
	current_length: float,
	current_thickness: float,
	current_facing_direction: float,
	branch_color: Color,
	bud_color: Color
) -> void:
	var branch_end := Vector2(
		current_facing_direction * current_length,
		0.0
	)

	draw_line(
		Vector2.ZERO,
		branch_end,
		branch_color,
		current_thickness,
		true
	)

	if branch_level <= 2:
		var current_bud_radius: float = (
			bud_radius
			+ (2 - branch_level) * 2.0
		)

		draw_circle(
			branch_end,
			current_bud_radius,
			bud_color
		)
	else:
		draw_circle(
			branch_end,
			current_thickness * 0.45,
			branch_color
		)


func draw_natural_shoots(
	current_length: float,
	current_facing_direction: float,
	shoot_color: Color,
	bud_color: Color
) -> void:
	var shoot_count: int = get_unlocked_shoot_count()

	for shoot_index in range(shoot_count):
		var relative_position: float = (
			float(shoot_index + 1)
			/ float(shoot_count + 1)
		)

		var distance_from_trunk: float = (
			current_length
			* lerp(
				0.30,
				0.76,
				relative_position
			)
		)

		var shoot_points_up: bool = (
			shoot_index % 2 == 0
		)

		var direction_y: float = (
			-1.0 if shoot_points_up else 1.0
		)

		var branch_position := Vector2(
			current_facing_direction
			* distance_from_trunk,
			0.0
		)

		var current_shoot_length: float = (
			shoot_length * tree_growth_factor
		)

		var shoot_tip := Vector2(
			branch_position.x
			+ current_facing_direction
			* current_shoot_length
			* 0.45,
			direction_y * current_shoot_length
		)

		draw_line(
			branch_position,
			shoot_tip,
			shoot_color,
			shoot_thickness * tree_growth_factor,
			true
		)

		draw_circle(
			shoot_tip,
			bud_radius * tree_growth_factor,
			bud_color
		)
