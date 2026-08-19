class_name StrengthBranchVisual
extends Node2D


const LOWER_STAGE_LAYOUTS: Array[Dictionary] = [
	{
		BranchSlotRules.STANDARD_SLOT_1_ID: {
			&"position": Vector2(-32.0, -14.0),
			&"scale": Vector2(0.4, 0.4),
			&"flip_h": true,
			&"rotation": 0.0
		},
		BranchSlotRules.STANDARD_SLOT_3_ID: {
			&"position": Vector2(32.0, -14.0),
			&"scale": Vector2(0.4, 0.4),
			&"flip_h": false,
			&"rotation": 0.0
		}
	},
	{
		BranchSlotRules.STANDARD_SLOT_1_ID: {
			&"position": Vector2(-42.0, -18.0),
			&"scale": Vector2(0.5, 0.5),
			&"flip_h": true,
			&"rotation": 0.0
		},
		BranchSlotRules.STANDARD_SLOT_3_ID: {
			&"position": Vector2(42.0, -18.0),
			&"scale": Vector2(0.5, 0.5),
			&"flip_h": false,
			&"rotation": 0.0
		}
	},
	{
		BranchSlotRules.STANDARD_SLOT_1_ID: {
			&"position": Vector2(-57.0, -23.0),
			&"scale": Vector2(0.64, 0.64),
			&"flip_h": true,
			&"rotation": 0.0
		},
		BranchSlotRules.STANDARD_SLOT_3_ID: {
			&"position": Vector2(57.0, -23.0),
			&"scale": Vector2(0.64, 0.64),
			&"flip_h": false,
			&"rotation": 0.0
		}
	},
	{
		BranchSlotRules.STANDARD_SLOT_1_ID: {
			&"position": Vector2(-71.0, -28.0),
			&"scale": Vector2(0.78, 0.78),
			&"flip_h": true,
			&"rotation": 0.0
		},
		BranchSlotRules.STANDARD_SLOT_3_ID: {
			&"position": Vector2(71.0, -28.0),
			&"scale": Vector2(0.78, 0.78),
			&"flip_h": false,
			&"rotation": 0.0
		}
	}
]


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
var feedback_tween: Tween
var active_feedback_id: StringName = &""
var uses_lower_production_sprite: bool = false


@onready var production_sprite: Sprite2D = $ProductionSprite


func set_presentation_context(
	slot_id: StringName,
	tree_age: int
) -> void:
	var tree_stage: int = TreeGrowthVisual.resolve_stage_for_age(
		tree_age
	)
	var stage_layout: Dictionary = LOWER_STAGE_LAYOUTS[
		tree_stage - TreeGrowthVisual.STAGE_1
	]
	var slot_layout: Dictionary = stage_layout.get(
		slot_id,
		{}
	) as Dictionary

	uses_lower_production_sprite = not slot_layout.is_empty()
	production_sprite.visible = uses_lower_production_sprite

	if uses_lower_production_sprite:
		production_sprite.position = slot_layout[&"position"]
		production_sprite.scale = slot_layout[&"scale"]
		production_sprite.flip_h = bool(slot_layout[&"flip_h"])
		production_sprite.rotation = float(slot_layout[&"rotation"])

	queue_redraw()


func is_using_lower_production_sprite() -> bool:
	return uses_lower_production_sprite


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


func play_talent_feedback(feedback_id: StringName) -> void:
	if is_instance_valid(feedback_tween):
		feedback_tween.kill()
	modulate = Color.WHITE
	scale = Vector2.ONE
	active_feedback_id = feedback_id
	queue_redraw()
	var feedback_color := Color(1.0, 0.82, 0.32, 1.0)
	var scale_multiplier: float = 1.08
	match feedback_id:
		&"worldroot_slam":
			feedback_color = Color(1.0, 0.48, 0.18, 1.0)
			scale_multiplier = 1.18
		&"grand_sweep":
			feedback_color = Color(0.95, 0.95, 0.55, 1.0)
			scale_multiplier = 1.14
		&"uproot":
			feedback_color = Color(0.48, 0.9, 0.62, 1.0)
			scale_multiplier = 1.12
		&"finisher", &"final_cut":
			feedback_color = Color(1.0, 0.3, 0.24, 1.0)
			scale_multiplier = 1.12
	feedback_tween = create_tween()
	feedback_tween.set_parallel(true)
	feedback_tween.tween_property(self, "modulate", feedback_color, 0.06)
	feedback_tween.tween_property(self, "scale", Vector2.ONE * scale_multiplier, 0.06)
	feedback_tween.set_parallel(false)
	feedback_tween.tween_property(self, "modulate", Color.WHITE, 0.12)
	feedback_tween.tween_property(self, "scale", Vector2.ONE, 0.12)
	feedback_tween.tween_callback(reset_talent_feedback)


func reset_talent_feedback() -> void:
	if is_instance_valid(feedback_tween):
		feedback_tween.kill()
	feedback_tween = null
	active_feedback_id = &""
	modulate = Color.WHITE
	scale = Vector2.ONE
	queue_redraw()


func _draw() -> void:
	var current_length: float = get_current_length()

	if uses_lower_production_sprite:
		draw_talent_feedback(current_length)
		return

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
	draw_talent_feedback(current_length)


func draw_talent_feedback(current_length: float) -> void:
	if active_feedback_id == &"":
		return
	var branch_end := Vector2(facing_direction * current_length, 0.0)
	match active_feedback_id:
		&"earthbreaker":
			draw_arc(branch_end, 42.0, 0.0, TAU, 28, Color(1.0, 0.68, 0.25, 0.9), 5.0, true)
			draw_line(branch_end, branch_end + Vector2(facing_direction * 120.0, 0.0), Color(1.0, 0.58, 0.18, 0.8), 5.0, true)
		&"worldroot_slam":
			draw_arc(branch_end, 72.0, 0.0, TAU, 36, Color(1.0, 0.38, 0.12, 0.95), 8.0, true)
			draw_line(branch_end, branch_end + Vector2(facing_direction * 210.0, 0.0), Color(1.0, 0.32, 0.08, 0.9), 10.0, true)
		&"uproot":
			draw_arc(branch_end, 58.0, 0.0, TAU, 32, Color(0.38, 0.95, 0.58, 0.9), 7.0, true)
		&"grand_sweep":
			draw_arc(Vector2.ZERO, current_length * 0.75, -1.0, 1.0, 32, Color(0.95, 0.95, 0.48, 0.9), 7.0, true)
		&"finisher", &"final_cut":
			draw_circle(branch_end, 24.0, Color(1.0, 0.2, 0.16, 0.75))


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
