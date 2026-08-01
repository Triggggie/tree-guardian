extends CombatBranch

const TALENT_SWEEPING_STRIKE: StringName = &"sweeping_strike"
const TALENT_REBUFF: StringName = &"rebuff"
const TALENT_MARKED_PREY: StringName = &"marked_prey"

const UPGRADE_DAMAGE: StringName = &"damage"
const UPGRADE_ATTACK_SPEED: StringName = &"attack_speed"
const UPGRADE_RANGE: StringName = &"range"

@export_category("Combat")
@export var base_range_padding: float = 100.0
@export var base_damage: float = 10.0
@export var attack_angle_degrees: float = 18.0
@export var attack_duration: float = 0.12
@export var base_attack_cooldown: float = 1.5
@export var minimum_attack_cooldown: float = 0.45

@export_category("Targeting")

@export_range(0, 8, 1)
var target_lane_index: int = 3

@export_range(0, 4, 1)
var target_lane_span: int = 1

@export_category("Talent Balance")

@export_range(0.0, 2.0, 0.05)
var sweeping_strike_damage_multiplier: float = 0.60

@export_range(10.0, 500.0, 5.0)
var sweeping_strike_search_radius: float = 120.0

@export_range(0.0, 200.0, 5.0)
var rebuff_distance: float = 35.0

@export_range(0.0, 1.0, 0.01)
var marked_prey_damage_per_stack: float = 0.10

@export_range(1, 20, 1)
var marked_prey_maximum_stacks: int = 5

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
var marked_prey_target_id: int = 0
var marked_prey_stacks: int = 0

var targeting_profile: TargetingProfile = (
	TargetingProfile.new()
)

func _ready() -> void:
	branch_display_name = "Strength Branch"
	branch_id = &"strength_branch"

	targeting_profile.target_group = &"enemies"

	targeting_profile.target_priority = (
		TargetingProfile.TargetPriority.NEAREST
	)

	targeting_profile.lane_mode = (
		TargetingProfile.LaneMode.PREFERRED
	)

	targeting_profile.preferred_lane_span = (
		target_lane_span
	)

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
	var current_base_damage: float = (
		base_damage
		+ damage_upgrade_level
		* get_upgrade_value_per_level(
			UPGRADE_DAMAGE
		)
	)

	return BranchStatCalculator.apply_branch_damage(
		current_base_damage
	)


func get_current_attack_cooldown() -> float:
	var current_base_cooldown: float = max(
		(
			base_attack_cooldown
			- attack_speed_upgrade_level
			* get_upgrade_value_per_level(
				UPGRADE_ATTACK_SPEED
			)
		),
		minimum_attack_cooldown
	)

	return BranchStatCalculator.get_modified_attack_cooldown(
		current_base_cooldown,
		minimum_attack_cooldown
	)

func get_current_range_bonus() -> float:
	return (
		range_upgrade_level
		* get_upgrade_value_per_level(
			UPGRADE_RANGE
		)
	)

func get_current_attack_range() -> float:
	return (
		get_current_length()
		+ base_range_padding
		+ get_current_range_bonus()
	)

func get_damage_upgrade_cost() -> int:
	return get_upgrade_cost_by_id(
		UPGRADE_DAMAGE
	)

func get_attack_speed_upgrade_cost() -> int:
	return get_upgrade_cost_by_id(
		UPGRADE_ATTACK_SPEED
	)

func get_range_upgrade_cost() -> int:
	return get_upgrade_cost_by_id(
		UPGRADE_RANGE
	)

func purchase_damage_upgrade() -> bool:
	if not can_purchase_upgrade_by_id(
		UPGRADE_DAMAGE
	):
		return false
	var cost: int = get_damage_upgrade_cost()
	if not try_spend_essence(cost):
		return false
	damage_upgrade_level += 1
	upgrade_changed.emit(UPGRADE_DAMAGE, damage_upgrade_level)
	print_upgrade_result(
		get_upgrade_display_name(UPGRADE_DAMAGE),
		damage_upgrade_level,
		cost
	)
	return true

func purchase_attack_speed_upgrade() -> bool:
	if not can_purchase_upgrade_by_id(
		UPGRADE_ATTACK_SPEED
	):
		return false
	var cost: int = get_attack_speed_upgrade_cost()
	if not try_spend_essence(cost):
		return false
	attack_speed_upgrade_level += 1
	update_attack_cooldown()
	upgrade_changed.emit(
		UPGRADE_ATTACK_SPEED,
		attack_speed_upgrade_level
	)
	print_upgrade_result(
		get_upgrade_display_name(UPGRADE_ATTACK_SPEED),
		attack_speed_upgrade_level,
		cost
	)
	return true

func purchase_range_upgrade() -> bool:
	if not can_purchase_upgrade_by_id(
		UPGRADE_RANGE
	):
		return false
	var cost: int = get_range_upgrade_cost()
	if not try_spend_essence(cost):
		return false
	range_upgrade_level += 1
	upgrade_changed.emit(UPGRADE_RANGE, range_upgrade_level)
	print_upgrade_result(
		get_upgrade_display_name(UPGRADE_RANGE),
		range_upgrade_level,
		cost
	)
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

func is_valid_attack_target(target: Node) -> bool:
	if not is_instance_valid(target):
		return false

	if target is not Node2D:
		return false

	if not target.is_in_group("enemies"):
		return false

	if not target.has_method("take_damage"):
		return false

	if not target.has_method("is_targetable"):
		return false

	if not bool(target.call("is_targetable")):
		return false

	var target_node := target as Node2D

	var horizontal_difference: float = (
		target_node.global_position.x
		- global_position.x
	)

	if (
		horizontal_difference
		* get_facing_direction()
		<= 0.0
	):
		return false

	var horizontal_distance: float = abs(
		horizontal_difference
	)

	if horizontal_distance > get_current_attack_range():
		return false

	return true

func _on_cooldown_timer_timeout() -> void:
	if not combat_enabled:
		return

	current_target = find_nearest_enemy()

	if current_target == null:
		return

	perform_attack_animation()


func find_nearest_enemy() -> Node2D:
	targeting_profile.preferred_lane_span = (
		target_lane_span
	)

	return CombatTargeting.find_target(
		self,
		targeting_profile,
		target_lane_index,
		get_current_attack_range(),
		get_facing_direction()
	)

func perform_attack_animation() -> void:
	if not combat_enabled:
		return

	if not is_valid_attack_target(current_target):
		current_target = null
		return

	var target_instance_id: int = (
		current_target.get_instance_id()
	)

	var signed_attack_angle: float = (
		attack_angle_degrees
		* -get_facing_direction()
	)

	var attack_rotation: float = (
		resting_rotation
		+ deg_to_rad(signed_attack_angle)
	)

	var tween: Tween = create_tween()

	tween.set_trans(
		Tween.TRANS_QUAD
	)

	tween.set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		self,
		"rotation",
		attack_rotation,
		attack_duration
	)

	tween.tween_callback(
		func() -> void:
			if not combat_enabled:
				return

			var target_object: Object = (
				instance_from_id(
					target_instance_id
				)
			)

			if not is_instance_valid(
				target_object
			):
				return

			if target_object is not Node:
				return

			var target_node := (
				target_object as Node
			)

			if not is_valid_attack_target(
				target_node
			):
				return

			var primary_target := (
				target_node as Node2D
			)

			perform_strength_hit(
				primary_target
			)
	)

	tween.tween_property(
		self,
		"rotation",
		resting_rotation,
		attack_duration
	)
	
func perform_strength_hit(
	primary_target: Node2D
) -> void:
	if not is_valid_attack_target(
		primary_target
	):
		return

	var secondary_target: Node2D = null

	if has_talent(
		TALENT_SWEEPING_STRIKE
	):
		secondary_target = (
			find_sweeping_strike_target(
				primary_target
			)
		)

	var primary_context := AttackContext.new(
		self,
		primary_target,
		get_marked_prey_damage(
			primary_target
		)
	)

	primary_context.attack_id = (
		&"strength_basic_attack"
	)

	primary_context.add_tag(
		&"strength"
	)

	primary_context.add_tag(
		&"basic_attack"
	)

	var primary_hit_resolved: bool = (
		AttackResolver.resolve_damage(
			primary_context
		)
	)

	if primary_hit_resolved:
		apply_rebuff_to_target(
			primary_target
		)

	if not is_valid_attack_target(
		secondary_target
	):
		return

	var secondary_context := AttackContext.new(
		self,
		secondary_target,
		get_current_damage()
	)

	secondary_context.attack_id = (
		&"strength_sweeping_strike"
	)

	secondary_context.damage_multiplier = (
		sweeping_strike_damage_multiplier
	)

	secondary_context.is_secondary_attack = true

	secondary_context.add_tag(
		&"strength"
	)

	secondary_context.add_tag(
		&"secondary_attack"
	)

	secondary_context.add_tag(
		TALENT_SWEEPING_STRIKE
	)

	var secondary_hit_resolved: bool = (
		AttackResolver.resolve_damage(
			secondary_context
		)
	)

	if secondary_hit_resolved:
		apply_rebuff_to_target(
			secondary_target
		)

func get_marked_prey_damage(
	target: Node2D
) -> float:
	var base_attack_damage: float = (
		get_current_damage()
	)

	if not has_talent(
		TALENT_MARKED_PREY
	):
		reset_marked_prey()
		return base_attack_damage

	if not is_instance_valid(target):
		reset_marked_prey()
		return base_attack_damage

	var target_id: int = (
		target.get_instance_id()
	)

	if marked_prey_target_id != target_id:
		marked_prey_target_id = target_id
		marked_prey_stacks = 0
	else:
		marked_prey_stacks = min(
			marked_prey_stacks + 1,
			marked_prey_maximum_stacks
		)

	var damage_multiplier: float = (
		1.0
		+ marked_prey_stacks
		* marked_prey_damage_per_stack
	)

	return (
		base_attack_damage
		* damage_multiplier
	)


func reset_marked_prey() -> void:
	marked_prey_target_id = 0
	marked_prey_stacks = 0

func apply_rebuff_to_target(
	target: Node2D
) -> void:
	if not has_talent(
		TALENT_REBUFF
	):
		return

	if not is_valid_attack_target(
		target
	):
		return

	if not target.has_method(
		"apply_knockback"
	):
		return

	target.apply_knockback(
		rebuff_distance
	)


func find_sweeping_strike_target(
	primary_target: Node2D
) -> Node2D:
	if not is_valid_attack_target(
		primary_target
	):
		return null

	var best_target: Node2D = null
	var best_lane_difference: int = 999

	var closest_distance: float = (
		sweeping_strike_search_radius
		+ 0.001
	)

	var primary_lane_index: int = -1

	if primary_target.has_method(
		"get_lane_index"
	):
		primary_lane_index = int(
			primary_target.call(
				"get_lane_index"
			)
		)

	for enemy in get_tree().get_nodes_in_group(
		"enemies"
	):
		if enemy == primary_target:
			continue

		if not is_valid_attack_target(enemy):
			continue

		var enemy_node := enemy as Node2D

		var distance_from_primary: float = (
			enemy_node.global_position.distance_to(
				primary_target.global_position
			)
		)

		if (
			distance_from_primary
			> sweeping_strike_search_radius
		):
			continue

		var lane_difference: int = 999

		if (
			primary_lane_index >= 0
			and enemy.has_method(
				"get_lane_index"
			)
		):
			var enemy_lane_index: int = int(
				enemy.call(
					"get_lane_index"
				)
			)

			lane_difference = abs(
				enemy_lane_index
				- primary_lane_index
			)

		if (
			lane_difference
			> best_lane_difference
		):
			continue

		if (
			lane_difference
			== best_lane_difference
			and distance_from_primary
			>= closest_distance
		):
			continue

		best_lane_difference = lane_difference
		closest_distance = distance_from_primary
		best_target = enemy_node

	return best_target

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
	reset_marked_prey()
	cooldown_timer.stop()
	var active_tween: Tween = create_tween()
	active_tween.tween_property(self, "rotation", resting_rotation, 0.1)

func resume_combat() -> void:
	super.resume_combat()
	current_target = null
	reset_marked_prey()
	rotation = resting_rotation
	update_attack_cooldown()
	if cooldown_timer.is_stopped():
		cooldown_timer.start()

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


func get_upgrade_level(
	upgrade_id: StringName
) -> int:
	match upgrade_id:
		UPGRADE_DAMAGE:
			return damage_upgrade_level

		UPGRADE_ATTACK_SPEED:
			return attack_speed_upgrade_level

		UPGRADE_RANGE:
			return range_upgrade_level

	return 0


func get_upgrade_current_value_text(
	upgrade_id: StringName
) -> String:
	match upgrade_id:
		UPGRADE_DAMAGE:
			return "%.1f" % get_current_damage()

		UPGRADE_ATTACK_SPEED:
			var cooldown: float = (
				get_current_attack_cooldown()
			)

			if cooldown <= 0.0:
				return "0.00 /s"

			return "%.2f /s" % (
				1.0 / cooldown
			)

		UPGRADE_RANGE:
			return "%.0f" % (
				get_current_attack_range()
			)

	return ""


func get_upgrade_next_value_text(
	upgrade_id: StringName
) -> String:
	match upgrade_id:
		UPGRADE_DAMAGE:
			var next_damage: float = (
				get_current_damage()
				+ get_upgrade_value_per_level(
					UPGRADE_DAMAGE
				)
			)

			return "%.1f" % next_damage

		UPGRADE_ATTACK_SPEED:
			var next_level: int = (
				attack_speed_upgrade_level + 1
			)

			var next_cooldown: float = max(
				base_attack_cooldown
					- next_level
					* get_upgrade_value_per_level(
						UPGRADE_ATTACK_SPEED
					),
				minimum_attack_cooldown
			)

			if next_cooldown <= 0.0:
				return "0.00 /s"

			return "%.2f /s" % (
				1.0 / next_cooldown
			)

		UPGRADE_RANGE:
			var next_range_bonus: float = (
				(range_upgrade_level + 1)
				* get_upgrade_value_per_level(
					UPGRADE_RANGE
				)
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
		UPGRADE_DAMAGE:
			return purchase_damage_upgrade()

		UPGRADE_ATTACK_SPEED:
			return purchase_attack_speed_upgrade()

		UPGRADE_RANGE:
			return purchase_range_upgrade()

	return false
