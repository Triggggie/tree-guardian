class_name PoisonVineBranchVisual
extends Node2D


@export_range(2, 50, 1)
var mature_branch_level: int = 10

@export var bud_length: float = 92.0
@export var mature_length: float = 150.0
@export var bud_thickness: float = 8.0
@export var mature_thickness: float = 15.0


var branch_level: int = 1
var tree_growth_factor: float = 1.0
var facing_direction: float = 1.0
var attack_flash: float = 0.0
var attack_tween: Tween


func set_branch_level(new_branch_level: int) -> void:
	branch_level = max(new_branch_level, 1)
	queue_redraw()


func set_tree_growth_factor(new_growth_factor: float) -> void:
	tree_growth_factor = max(new_growth_factor, 0.0)
	queue_redraw()


func set_facing_direction(new_facing_direction: float) -> void:
	facing_direction = -1.0 if new_facing_direction < 0.0 else 1.0
	queue_redraw()


func get_branch_growth_progress() -> float:
	var safe_mature_level: int = max(mature_branch_level, 2)
	return clamp(
		float(branch_level - 1) / float(safe_mature_level - 1),
		0.0,
		1.0
	)


func get_current_length() -> float:
	return lerp(bud_length, mature_length, get_branch_growth_progress()) * tree_growth_factor


func get_current_thickness() -> float:
	return lerp(bud_thickness, mature_thickness, get_branch_growth_progress()) * tree_growth_factor


func get_endpoint_local_position() -> Vector2:
	return Vector2(facing_direction * get_current_length(), -5.0)


func play_attack_feedback() -> void:
	if is_instance_valid(attack_tween):
		attack_tween.kill()
	attack_flash = 0.0
	attack_tween = create_tween()
	attack_tween.tween_method(_set_attack_flash, 0.0, 1.0, 0.08)
	attack_tween.tween_method(_set_attack_flash, 1.0, 0.0, 0.14)


func reset_feedback() -> void:
	if is_instance_valid(attack_tween):
		attack_tween.kill()
	attack_tween = null
	attack_flash = 0.0
	queue_redraw()


func _set_attack_flash(value: float) -> void:
	attack_flash = clamp(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var length: float = get_current_length()
	var thickness: float = get_current_thickness()
	var points := PackedVector2Array([
		Vector2.ZERO,
		Vector2(facing_direction * length * 0.34, -7.0),
		Vector2(facing_direction * length * 0.68, 5.0),
		get_endpoint_local_position()
	])
	draw_polyline(points, Color("315d32"), thickness, true)
	draw_polyline(points, Color("58a447"), max(thickness * 0.38, 2.0), true)
	for thorn_index in range(1, 5):
		var progress: float = float(thorn_index) / 5.0
		var thorn_position := Vector2(facing_direction * length * progress, 0.0)
		var thorn_tip := thorn_position + Vector2(
			facing_direction * 5.0,
			-10.0 if thorn_index % 2 == 0 else 10.0
		)
		draw_line(thorn_position, thorn_tip, Color("9ad64d"), 3.0, true)
	var bulb_color: Color = Color("b9ef48").lerp(Color.WHITE, attack_flash * 0.7)
	draw_circle(get_endpoint_local_position(), 10.0, Color("316d32"))
	draw_circle(get_endpoint_local_position(), 6.0, bulb_color)
