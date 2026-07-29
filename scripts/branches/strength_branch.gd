extends CombatBranch

@export_category("Combat")
@export var base_range_padding: float = 100.0
@export var base_damage: float = 10.0
@export var attack_angle_degrees: float = 18.0
@export var attack_duration: float = 0.12
@export var base_attack_cooldown: float = 1.5
@export var minimum_attack_cooldown: float = 0.45

@export_category("Essence Upgrades")
@export var damage_per_upgrade: float = 2.0
@export var damage_upgrade_base_cost: int = 8
@export var cooldown_reduction_per_upgrade: float = 0.08
@export var attack_speed_upgrade_base_cost: int = 10
@export var range_per_upgrade: float = 15.0
@export var maximum_range_bonus: float = 150.0
@export var range_upgrade_base_cost: int = 7

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

@onready var cooldown_timer: Timer = $CooldownTimer

var damage_upgrade_level: int = 0
var attack_speed_upgrade_level: int = 0
var range_upgrade_level: int = 0
var resting_rotation: float
var current_target: Node2D

func _ready() -> void:
	branch_display_name = "Strength Branch"
	branch_id = &"strength_branch"
	super._ready()
	add_to_group("strength_branch")
	resting_rotation = rotation
	if is_instance_valid(tree_node):
		if tree_node.has_signal("growth_changed"):
			tree_node.growth_changed.connect(_on_tree_growth_changed)
	cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)
	update_attack_cooldown()
	queue_redraw()
	if cooldown_timer.is_stopped():
		cooldown_timer.start()

func get_branch_growth_progress() -> float:
	var safe_mature_level: int = max(mature_branch_level, 2)
	var raw_progress: float = clamp(
		float(branch_level - 1) / float(safe_mature_level - 1),
		0.0,
		1.0
	)
	return 1.0 - pow(1.0 - raw_progress, 2.0)

func get_tree_growth_factor() -> float:
	if not is_instance_valid(tree_node):
		return 1.0
	if tree_node.has_method("get_tree_growth_factor"):
		return tree_node.get_tree_growth_factor()
	return 1.0

func get_current_length() -> float:
	var branch_length: float = lerp(
		bud_length,
		mature_length,
		get_branch_growth_progress()
	)
	return branch_length * get_tree_growth_factor()

func get_current_thickness() -> float:
	var branch_thickness: float = lerp(
		bud_thickness,
		mature_thickness,
		get_branch_growth_progress()
	)
	var tree_thickness_factor: float = lerp(
		0.88,
		1.0,
		get_tree_growth_factor()
	)
	return branch_thickness * tree_thickness_factor

func get_current_damage() -> float:
	return base_damage + damage_upgrade_level * damage_per_upgrade

func get_current_attack_cooldown() -> float:
	var calculated_cooldown: float = (
		base_attack_cooldown
		- attack_speed_upgrade_level
		* cooldown_reduction_per_upgrade
	)
	return max(calculated_cooldown, minimum_attack_cooldown)

func get_current_range_bonus() -> float:
	return min(
		range_upgrade_level * range_per_upgrade,
		maximum_range_bonus
	)

func get_current_attack_range() -> float:
	return (
		get_current_length()
		+ base_range_padding
		+ get_current_range_bonus()
	)

func get_damage_upgrade_cost() -> int:
	return get_upgrade_cost(damage_upgrade_base_cost, damage_upgrade_level)

func get_attack_speed_upgrade_cost() -> int:
	return get_upgrade_cost(
		attack_speed_upgrade_base_cost,
		attack_speed_upgrade_level
	)

func get_range_upgrade_cost() -> int:
	return get_upgrade_cost(range_upgrade_base_cost, range_upgrade_level)

func purchase_damage_upgrade() -> bool:
	if not can_upgrade_stat(damage_upgrade_level):
		return false
	var cost: int = get_damage_upgrade_cost()
	if not try_spend_essence(cost):
		return false
	damage_upgrade_level += 1
	upgrade_changed.emit(&"damage", damage_upgrade_level)
	print_upgrade_result("Damage", damage_upgrade_level, cost)
	return true

func purchase_attack_speed_upgrade() -> bool:
	if not can_upgrade_stat(attack_speed_upgrade_level):
		return false
	var cost: int = get_attack_speed_upgrade_cost()
	if not try_spend_essence(cost):
		return false
	attack_speed_upgrade_level += 1
	update_attack_cooldown()
	upgrade_changed.emit(&"attack_speed", attack_speed_upgrade_level)
	print_upgrade_result("Attack Speed", attack_speed_upgrade_level, cost)
	return true

func purchase_range_upgrade() -> bool:
	if range_upgrade_level >= get_maximum_range_upgrade_level():
		return false
	if not can_upgrade_stat(range_upgrade_level):
		return false
	var cost: int = get_range_upgrade_cost()
	if not try_spend_essence(cost):
		return false
	range_upgrade_level += 1
	upgrade_changed.emit(&"range", range_upgrade_level)
	print_upgrade_result("Range", range_upgrade_level, cost)
	return true

func print_upgrade_result(
	upgrade_name: String,
	new_upgrade_level: int,
	cost: int
) -> void:
	print(
		upgrade_name,
		" upgraded to Level ",
		new_upgrade_level,
		" | Cost: ",
		cost,
		" | Damage: ",
		get_current_damage(),
		" | Cooldown: ",
		get_current_attack_cooldown(),
		" s | Range: ",
		get_current_attack_range()
	)

func update_attack_cooldown() -> void:
	cooldown_timer.wait_time = get_current_attack_cooldown()

func _draw() -> void:
	var current_length: float = get_current_length()
	var current_thickness: float = get_current_thickness()
	var facing_direction: float = get_facing_direction()
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
	facing_direction: float,
	branch_color: Color,
	bud_color: Color
) -> void:
	var branch_end := Vector2(facing_direction * current_length, 0.0)
	draw_line(
		Vector2.ZERO,
		branch_end,
		branch_color,
		current_thickness,
		true
	)
	if branch_level <= 2:
		var current_bud_radius: float = bud_radius + (2 - branch_level) * 2.0
		draw_circle(branch_end, current_bud_radius, bud_color)
	else:
		draw_circle(branch_end, current_thickness * 0.45, branch_color)

func draw_natural_shoots(
	current_length: float,
	facing_direction: float,
	shoot_color: Color,
	bud_color: Color
) -> void:
	if branch_level < first_shoot_level:
		return
	var unlocked_shoots: int = branch_level - first_shoot_level + 1
	var shoot_count: int = min(unlocked_shoots, maximum_shoots)
	for shoot_index in range(shoot_count):
		var relative_position: float = (
			float(shoot_index + 1)
			/ float(shoot_count + 1)
		)
		var distance_from_trunk: float = (
			current_length
			* lerp(0.30, 0.76, relative_position)
		)
		var shoot_points_up: bool = shoot_index % 2 == 0
		var direction_y: float = -1.0 if shoot_points_up else 1.0
		var branch_position := Vector2(
			facing_direction * distance_from_trunk,
			0.0
		)
		var tree_factor: float = get_tree_growth_factor()
		var current_shoot_length: float = shoot_length * tree_factor
		var shoot_tip := Vector2(
			branch_position.x
			+ facing_direction
			* current_shoot_length
			* 0.45,
			direction_y * current_shoot_length
		)
		draw_line(
			branch_position,
			shoot_tip,
			shoot_color,
			shoot_thickness * tree_factor,
			true
		)
		draw_circle(shoot_tip, bud_radius * tree_factor, bud_color)

func _on_tree_growth_changed(_growth_factor: float) -> void:
	queue_redraw()

func _on_cooldown_timer_timeout() -> void:
	if not combat_enabled:
		return
	current_target = find_nearest_enemy()
	if current_target == null:
		return
	perform_attack_animation()

func find_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_horizontal_distance: float = get_current_attack_range()
	var facing_direction: float = get_facing_direction()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy is not Node2D:
			continue
		var horizontal_difference: float = (
			enemy.global_position.x - global_position.x
		)
		var enemy_is_on_correct_side: bool = (
			horizontal_difference * facing_direction > 0.0
		)
		if not enemy_is_on_correct_side:
			continue
		var horizontal_distance: float = abs(horizontal_difference)
		if horizontal_distance < nearest_horizontal_distance:
			nearest_horizontal_distance = horizontal_distance
			nearest_enemy = enemy
	return nearest_enemy

func perform_attack_animation() -> void:
	if not combat_enabled:
		return
	if not is_instance_valid(current_target):
		return
	var target_instance_id: int = current_target.get_instance_id()
	var signed_attack_angle: float = (
		attack_angle_degrees * -get_facing_direction()
	)
	var attack_rotation: float = (
		resting_rotation + deg_to_rad(signed_attack_angle)
	)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", attack_rotation, attack_duration)
	tween.tween_callback(
		func() -> void:
			if not combat_enabled:
				return
			var target_object: Object = instance_from_id(target_instance_id)
			if not is_instance_valid(target_object):
				return
			if target_object is not Node2D:
				return
			var target_node := target_object as Node2D
			if not target_node.has_method("take_damage"):
				return
			target_node.take_damage(get_current_damage(), self)
	)
	tween.tween_property(self, "rotation", resting_rotation, attack_duration)

func on_branch_level_changed() -> void:
	queue_redraw()
	print(
		branch_display_name,
		" stats | Damage: ",
		get_current_damage(),
		" | Cooldown: ",
		get_current_attack_cooldown(),
		" s | Range: ",
		get_current_attack_range()
	)

func stop_combat() -> void:
	super.stop_combat()
	current_target = null
	cooldown_timer.stop()
	var active_tween: Tween = create_tween()
	active_tween.tween_property(self, "rotation", resting_rotation, 0.1)

func resume_combat() -> void:
	super.resume_combat()
	current_target = null
	rotation = resting_rotation
	update_attack_cooldown()
	if cooldown_timer.is_stopped():
		cooldown_timer.start()

func get_maximum_range_upgrade_level() -> int:
	if range_per_upgrade <= 0.0:
		return 0
	return max(
		int(floor(maximum_range_bonus / range_per_upgrade)),
		0
	)

func get_stat_summary_lines() -> Array[String]:
	var attack_speed: float = 0.0
	var cooldown: float = (
		get_current_attack_cooldown()
	)

	if cooldown > 0.0:
		attack_speed = 1.0 / cooldown

	return [
		"Damage %.1f"
		% get_current_damage(),

		"Attack Speed %.2f /s"
		% attack_speed,

		"Range %.0f"
		% get_current_attack_range()
	]


func get_upgrade_ids() -> Array[StringName]:
	return [
		&"damage",
		&"attack_speed",
		&"range"
	]


func get_upgrade_display_name(
	upgrade_id: StringName
) -> String:
	match upgrade_id:
		&"damage":
			return "Damage"

		&"attack_speed":
			return "Attack Speed"

		&"range":
			return "Range"

	return "Unknown Upgrade"


func get_upgrade_level(
	upgrade_id: StringName
) -> int:
	match upgrade_id:
		&"damage":
			return damage_upgrade_level

		&"attack_speed":
			return attack_speed_upgrade_level

		&"range":
			return range_upgrade_level

	return 0


func get_upgrade_maximum_level(
	upgrade_id: StringName
) -> int:
	var branch_maximum: int = (
		get_maximum_essence_upgrade_level()
	)

	if upgrade_id == &"range":
		return min(
			branch_maximum,
			get_maximum_range_upgrade_level()
		)

	return branch_maximum


func get_upgrade_cost_by_id(
	upgrade_id: StringName
) -> int:
	match upgrade_id:
		&"damage":
			return get_damage_upgrade_cost()

		&"attack_speed":
			return get_attack_speed_upgrade_cost()

		&"range":
			return get_range_upgrade_cost()

	return 0


func get_upgrade_current_value_text(
	upgrade_id: StringName
) -> String:
	match upgrade_id:
		&"damage":
			return "%.1f" % get_current_damage()

		&"attack_speed":
			var cooldown: float = (
				get_current_attack_cooldown()
			)

			if cooldown <= 0.0:
				return "0.00 /s"

			return "%.2f /s" % (
				1.0 / cooldown
			)

		&"range":
			return "%.0f" % (
				get_current_attack_range()
			)

	return ""


func get_upgrade_next_value_text(
	upgrade_id: StringName
) -> String:
	match upgrade_id:
		&"damage":
			var next_damage: float = (
				get_current_damage()
				+ damage_per_upgrade
			)

			return "%.1f" % next_damage

		&"attack_speed":
			var next_level: int = (
				attack_speed_upgrade_level + 1
			)

			var next_cooldown: float = max(
				base_attack_cooldown
				- next_level
				* cooldown_reduction_per_upgrade,
				minimum_attack_cooldown
			)

			if next_cooldown <= 0.0:
				return "0.00 /s"

			return "%.2f /s" % (
				1.0 / next_cooldown
			)

		&"range":
			var next_range_bonus: float = min(
				(range_upgrade_level + 1)
				* range_per_upgrade,
				maximum_range_bonus
			)

			var next_range: float = (
				get_current_length()
				+ base_range_padding
				+ next_range_bonus
			)

			return "%.0f" % next_range

	return ""


func purchase_upgrade(
	upgrade_id: StringName
) -> bool:
	match upgrade_id:
		&"damage":
			return purchase_damage_upgrade()

		&"attack_speed":
			return purchase_attack_speed_upgrade()

		&"range":
			return purchase_range_upgrade()

	return false
