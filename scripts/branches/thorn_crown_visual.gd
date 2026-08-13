class_name ThornCrownVisual
extends Node2D


signal attack_animation_started(intensity: float)


@export_category("Visual Growth")
@export_range(2, 50, 1) var mature_branch_level: int = 10
@export var bud_arm_length: float = 62.0
@export var mature_arm_length: float = 118.0
@export var bud_thickness: float = 13.0
@export var mature_thickness: float = 25.0
@export var arm_rise_ratio: float = 0.48
@export var base_thorns_per_arm: int = 3
@export var maximum_thorns_per_arm: int = 7


var branch_level: int = 1
var tree_growth_factor: float = 1.0
var attack_progress: float = 0.0:
	set(value):
		attack_progress = clamp(value, 0.0, 1.0)
		queue_redraw()
var attack_intensity: float = 1.0
var attack_tween: Tween
var idle_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	idle_scale = scale


func _exit_tree() -> void:
	stop_attack_animation()


func play_attack(new_intensity: float = 1.0) -> void:
	stop_attack_animation()
	attack_intensity = clamp(new_intensity, 1.0, 1.2)
	attack_animation_started.emit(attack_intensity)
	attack_tween = create_tween()
	attack_tween.set_trans(Tween.TRANS_QUAD)
	attack_tween.set_ease(Tween.EASE_OUT)
	attack_tween.tween_property(self, "attack_progress", 1.0, 0.09)
	attack_tween.parallel().tween_property(
		self,
		"scale",
		idle_scale * (1.07 + 0.03 * (attack_intensity - 1.0)),
		0.09
	)
	attack_tween.set_ease(Tween.EASE_IN_OUT)
	attack_tween.tween_property(self, "attack_progress", 0.0, 0.19)
	attack_tween.parallel().tween_property(
		self,
		"scale",
		idle_scale,
		0.19
	)
	attack_tween.tween_callback(_finish_attack_animation)


func stop_attack_animation() -> void:
	if is_instance_valid(attack_tween):
		attack_tween.kill()
	attack_tween = null
	attack_progress = 0.0
	scale = idle_scale


func is_attack_animation_active() -> bool:
	return is_instance_valid(attack_tween)


func _finish_attack_animation() -> void:
	attack_tween = null
	attack_progress = 0.0
	scale = idle_scale


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


func get_growth_progress() -> float:
	var safe_mature_level: int = max(mature_branch_level, 2)
	var raw_progress: float = clamp(
		float(branch_level - 1) / float(safe_mature_level - 1),
		0.0,
		1.0
	)
	return 1.0 - pow(1.0 - raw_progress, 2.0)


func get_current_arm_length() -> float:
	return lerp(
		bud_arm_length,
		mature_arm_length,
		get_growth_progress()
	) * tree_growth_factor


func get_current_thickness() -> float:
	return lerp(
		bud_thickness,
		mature_thickness,
		get_growth_progress()
	) * lerp(0.88, 1.0, tree_growth_factor)


func get_thorns_per_arm() -> int:
	return clamp(
		base_thorns_per_arm + int(floor(float(branch_level - 1) / 2.0)),
		base_thorns_per_arm,
		maximum_thorns_per_arm
	)


func get_arm_tip(side_direction: float) -> Vector2:
	var direction: float = -1.0 if side_direction < 0.0 else 1.0
	var arm_length: float = get_current_arm_length() * (
		1.0 + 0.16 * attack_progress * attack_intensity
	)
	return Vector2(direction * arm_length, -arm_length * arm_rise_ratio)


func has_bilateral_geometry() -> bool:
	return get_arm_tip(-1.0).x < 0.0 and get_arm_tip(1.0).x > 0.0


func _draw() -> void:
	var flash_strength: float = attack_progress * attack_intensity
	var wood_color := Color("5d351f").lerp(Color("a86a35"), flash_strength * 0.55)
	var inner_wood_color := Color("80502b").lerp(Color("d4a84f"), flash_strength * 0.60)
	var thorn_color := Color("b7c96b").lerp(Color("f1ffb0"), flash_strength * 0.85)
	var leaf_color := Color("6f9348").lerp(Color("b7e873"), flash_strength * 0.65)
	var thickness: float = get_current_thickness()

	draw_circle(Vector2.ZERO, thickness * 0.72, wood_color)
	draw_circle(Vector2(0.0, -thickness * 0.12), thickness * 0.42, inner_wood_color)
	_draw_arm(-1.0, thickness, wood_color, thorn_color, leaf_color)
	_draw_arm(1.0, thickness, wood_color, thorn_color, leaf_color)


func _draw_arm(
	side_direction: float,
	thickness: float,
	wood_color: Color,
	thorn_color: Color,
	leaf_color: Color
) -> void:
	var tip: Vector2 = get_arm_tip(side_direction)
	draw_line(Vector2.ZERO, tip, wood_color, thickness, true)
	draw_circle(tip, thickness * 0.36, leaf_color)

	var thorn_count: int = get_thorns_per_arm()
	for thorn_index in range(thorn_count):
		var progress: float = float(thorn_index + 1) / float(thorn_count + 1)
		var base: Vector2 = tip * progress
		var thorn_direction := Vector2(side_direction * 0.32, -1.0).normalized()
		if thorn_index % 2 == 1:
			thorn_direction.y *= -0.55
		var thorn_length: float = lerp(10.0, 17.0, get_growth_progress())
		draw_line(
			base,
			base + thorn_direction * thorn_length * tree_growth_factor,
			thorn_color,
			3.0 * tree_growth_factor,
			true
		)
