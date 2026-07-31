extends CombatBranch


@export_category("Healing Over Time")
@export var base_healing_per_tick: float = 3.0
@export var base_healing_tick_interval: float = 2.0
@export var minimum_healing_tick_interval: float = 0.75

@export var healing_effect_duration: float = 6.0
@export var effect_refresh_interval: float = 6.0


@export_category("Ranged Combat")
@export var base_ranged_damage: float = 3.0
@export var ranged_attack_interval: float = 2.0
@export var ranged_attack_range: float = 650.0


@export_category("Essence Upgrades")
@export var healing_per_tick_per_upgrade: float = 1.0
@export var healing_per_tick_upgrade_base_cost: int = 9

@export var healing_interval_reduction_per_upgrade: float = 0.10
@export var healing_speed_upgrade_base_cost: int = 11

@export var petal_damage_per_upgrade: float = 1.0
@export var petal_damage_upgrade_base_cost: int = 8


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


var healing_per_tick_upgrade_level: int = 0
var healing_speed_upgrade_level: int = 0
var petal_damage_upgrade_level: int = 0

var healing_refresh_time_remaining: float = 0.0
var attack_time_remaining: float = 0.0


func _ready() -> void:
	branch_display_name = "Blossom Branch"
	branch_id = &"blossom_branch"

	super._ready()

	add_to_group("blossom_branch")

	if is_instance_valid(tree_node):
		if tree_node.has_signal("growth_changed"):
			tree_node.growth_changed.connect(
				_on_tree_growth_changed
			)

	healing_refresh_time_remaining = 0.0
	attack_time_remaining = 0.0

	queue_redraw()


func _process(delta: float) -> void:
	if not combat_enabled:
		return

	if not is_instance_valid(tree_node):
		find_tree_node()

	if not is_instance_valid(tree_node):
		return

	process_healing(delta)
	process_ranged_attack(delta)


func process_healing(delta: float) -> void:
	healing_refresh_time_remaining -= delta

	if healing_refresh_time_remaining > 0.0:
		return

	apply_blossom_healing()

	healing_refresh_time_remaining = max(
		effect_refresh_interval,
		0.1
	)


func apply_blossom_healing() -> void:
	if not is_instance_valid(tree_node):
		return

	if not tree_node.has_method(
		"apply_healing_over_time"
	):
		push_warning(
			"Blossom Branch: Tree does not implement "
			+ "apply_healing_over_time()."
		)
		return

	tree_node.apply_healing_over_time(
		&"blossom_healing",
		get_current_healing_per_tick(),
		get_current_healing_tick_interval(),
		healing_effect_duration,
		self,
		true
	)


func get_current_healing_per_tick() -> float:
	var current_base_healing: float = (
		base_healing_per_tick
		+ healing_per_tick_upgrade_level
		* healing_per_tick_per_upgrade
	)

	return BranchStatCalculator.apply_healing_power(
		current_base_healing
	)


func get_current_healing_tick_interval() -> float:
	var calculated_interval: float = (
		base_healing_tick_interval
		- healing_speed_upgrade_level
		* healing_interval_reduction_per_upgrade
	)

	return max(
		calculated_interval,
		minimum_healing_tick_interval
	)


func get_current_petal_damage() -> float:
	var current_base_damage: float = (
		base_ranged_damage
		+ petal_damage_upgrade_level
		* petal_damage_per_upgrade
	)

	return BranchStatCalculator.apply_branch_damage(
		current_base_damage
	)

func get_current_ranged_attack_interval() -> float:
	return BranchStatCalculator.get_modified_attack_cooldown(
		ranged_attack_interval,
		0.1
	)

func is_valid_ranged_target(
	target: Node
) -> bool:
	if not is_instance_valid(target):
		return false

	if target is not Node2D:
		return false

	var target_node := target as Node2D

	if not target_node.is_inside_tree():
		return false

	if target_node.is_queued_for_deletion():
		return false

	if not target_node.is_in_group("enemies"):
		return false

	if not target_node.has_method("take_damage"):
		return false

	if not target_node.has_method("is_targetable"):
		return false

	if not bool(
		target_node.call("is_targetable")
	):
		return false

	var distance_from_branch: float = (
		global_position.distance_to(
			target_node.global_position
		)
	)

	if distance_from_branch > ranged_attack_range:
		return false

	return true


func process_ranged_attack(delta: float) -> void:
	attack_time_remaining -= delta

	if attack_time_remaining > 0.0:
		return

	var target: Node2D = find_best_ranged_target()

	if is_valid_ranged_target(target):
		perform_ranged_attack(target)

	attack_time_remaining = (
		get_current_ranged_attack_interval()
	)

func find_best_ranged_target() -> Node2D:
	var own_side_target: Node2D = (
		find_best_target_on_side(
			facing_side
		)
	)

	if is_valid_ranged_target(own_side_target):
		return own_side_target

	var opposite_side: int = 1

	if facing_side == 1:
		opposite_side = 0

	return find_best_target_on_side(
		opposite_side
	)


func find_best_target_on_side(
	target_side: int
) -> Node2D:
	if not is_instance_valid(tree_node):
		return null

	var best_target: Node2D = null
	var best_tree_distance: float = INF

	for enemy in get_tree().get_nodes_in_group(
		"enemies"
	):
		if not is_valid_ranged_target(enemy):
			continue

		var enemy_node := enemy as Node2D

		var horizontal_difference: float = (
			enemy_node.global_position.x
			- tree_node.global_position.x
		)

		var enemy_side: int = 0

		if horizontal_difference > 0.0:
			enemy_side = 1

		if enemy_side != target_side:
			continue

		var distance_from_tree: float = abs(
			horizontal_difference
		)

		if distance_from_tree < best_tree_distance:
			best_tree_distance = distance_from_tree
			best_target = enemy_node

	return best_target


func perform_ranged_attack(
	target: Node2D
) -> void:
	if not is_valid_ranged_target(target):
		return

	var projectile := BlossomProjectile.new()

	get_tree().current_scene.add_child(
		projectile
	)

	projectile.global_position = (
		get_projectile_spawn_position()
	)

	projectile.setup(
		target,
		get_current_petal_damage(),
		self
	)

	play_ranged_attack_feedback()



func get_projectile_spawn_position() -> Vector2:
	var facing_direction: float = (
		get_facing_direction()
	)

	var local_spawn_position := Vector2(
		facing_direction
		* get_current_length(),
		0.0
	)

	return to_global(
		local_spawn_position
	)


func play_ranged_attack_feedback() -> void:
	var original_scale: Vector2 = scale

	var tween: Tween = create_tween()

	tween.tween_property(
		self,
		"scale",
		original_scale * 1.08,
		0.08
	)

	tween.tween_property(
		self,
		"scale",
		original_scale,
		0.12
	)


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


func get_tree_growth_factor() -> float:
	if not is_instance_valid(tree_node):
		return 1.0

	if tree_node.has_method(
		"get_tree_growth_factor"
	):
		return tree_node.get_tree_growth_factor()

	return 1.0


func get_current_length() -> float:
	var current_length: float = lerp(
		bud_length,
		mature_length,
		get_branch_growth_progress()
	)

	return (
		current_length
		* get_tree_growth_factor()
	)


func get_current_thickness() -> float:
	var current_thickness: float = lerp(
		bud_thickness,
		mature_thickness,
		get_branch_growth_progress()
	)

	return (
		current_thickness
		* get_tree_growth_factor()
	)


func _draw() -> void:
	var current_length: float = (
		get_current_length()
	)

	var current_thickness: float = (
		get_current_thickness()
	)

	var facing_direction: float = (
		get_facing_direction()
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
	facing_direction: float
) -> void:
	if branch_level < first_flower_level:
		return

	var flower_count: int = clamp(
		branch_level
		- first_flower_level
		+ 1,
		1,
		maximum_flowers
	)

	for flower_index in range(flower_count):
		var progress: float = (
			float(flower_index + 1)
			/ float(flower_count + 1)
		)

		var vertical_offset: float = 10.0

		if flower_index % 2 == 0:
			vertical_offset = -10.0

		var flower_position := Vector2(
			facing_direction
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


func get_healing_per_tick_upgrade_cost() -> int:
	return get_upgrade_cost(
		healing_per_tick_upgrade_base_cost,
		healing_per_tick_upgrade_level
	)


func get_healing_speed_upgrade_cost() -> int:
	return get_upgrade_cost(
		healing_speed_upgrade_base_cost,
		healing_speed_upgrade_level
	)


func get_petal_damage_upgrade_cost() -> int:
	return get_upgrade_cost(
		petal_damage_upgrade_base_cost,
		petal_damage_upgrade_level
	)


func purchase_healing_per_tick_upgrade() -> bool:
	if not can_upgrade_stat(
		healing_per_tick_upgrade_level
	):
		return false

	var cost: int = (
		get_healing_per_tick_upgrade_cost()
	)

	if not try_spend_essence(cost):
		return false

	healing_per_tick_upgrade_level += 1

	refresh_healing_effect()

	upgrade_changed.emit(
		&"healing_per_tick",
		healing_per_tick_upgrade_level
	)

	return true


func purchase_healing_speed_upgrade() -> bool:
	if not can_upgrade_stat(
		healing_speed_upgrade_level
	):
		return false

	if (
		get_current_healing_tick_interval()
		<= minimum_healing_tick_interval
	):
		return false

	var cost: int = (
		get_healing_speed_upgrade_cost()
	)

	if not try_spend_essence(cost):
		return false

	healing_speed_upgrade_level += 1

	refresh_healing_effect()

	upgrade_changed.emit(
		&"healing_speed",
		healing_speed_upgrade_level
	)

	return true


func purchase_petal_damage_upgrade() -> bool:
	if not can_upgrade_stat(
		petal_damage_upgrade_level
	):
		return false

	var cost: int = (
		get_petal_damage_upgrade_cost()
	)

	if not try_spend_essence(cost):
		return false

	petal_damage_upgrade_level += 1

	upgrade_changed.emit(
		&"petal_damage",
		petal_damage_upgrade_level
	)

	return true


func refresh_healing_effect() -> void:
	healing_refresh_time_remaining = 0.0


func get_stat_summary_lines() -> Array[String]:
	return [
		"Healing %.1f per tick"
		% get_current_healing_per_tick(),

		"Healing Speed %.2f /s"
		% get_current_healing_speed(),

		"Effect Duration %.1f s"
		% healing_effect_duration,

		"Petal Damage %.1f"
		% get_current_petal_damage(),

		"Petal Attack Speed %.2f /s"
		% get_current_ranged_attack_speed(),

		"Petal Range %.0f"
		% ranged_attack_range
	]


func get_current_healing_speed() -> float:
	var interval: float = (
		get_current_healing_tick_interval()
	)

	if interval <= 0.0:
		return 0.0

	return 1.0 / interval


func get_current_ranged_attack_speed() -> float:
	var current_interval: float = (
		get_current_ranged_attack_interval()
	)

	if current_interval <= 0.0:
		return 0.0

	return 1.0 / current_interval


func get_upgrade_ids() -> Array[StringName]:
	return [
		&"healing_per_tick",
		&"healing_speed",
		&"petal_damage"
	]


func get_upgrade_display_name(
	upgrade_id: StringName
) -> String:
	match upgrade_id:
		&"healing_per_tick":
			return "Healing per Tick"

		&"healing_speed":
			return "Healing Speed"

		&"petal_damage":
			return "Petal Damage"

	return "Unknown Upgrade"


func get_upgrade_level(
	upgrade_id: StringName
) -> int:
	match upgrade_id:
		&"healing_per_tick":
			return healing_per_tick_upgrade_level

		&"healing_speed":
			return healing_speed_upgrade_level

		&"petal_damage":
			return petal_damage_upgrade_level

	return 0


func get_upgrade_maximum_level(
	upgrade_id: StringName
) -> int:
	var branch_maximum: int = (
		get_maximum_essence_upgrade_level()
	)

	if upgrade_id == &"healing_speed":
		return min(
			branch_maximum,
			get_maximum_healing_speed_upgrade_level()
		)

	return branch_maximum


func get_maximum_healing_speed_upgrade_level() -> int:
	if healing_interval_reduction_per_upgrade <= 0.0:
		return 0

	return max(
		int(
			ceil(
				(
					base_healing_tick_interval
					- minimum_healing_tick_interval
				)
				/ healing_interval_reduction_per_upgrade
			)
		),
		0
	)


func get_upgrade_cost_by_id(
	upgrade_id: StringName
) -> int:
	match upgrade_id:
		&"healing_per_tick":
			return get_healing_per_tick_upgrade_cost()

		&"healing_speed":
			return get_healing_speed_upgrade_cost()

		&"petal_damage":
			return get_petal_damage_upgrade_cost()

	return 0


func get_upgrade_current_value_text(
	upgrade_id: StringName
) -> String:
	match upgrade_id:
		&"healing_per_tick":
			return (
				"%.1f HP"
				% get_current_healing_per_tick()
			)

		&"healing_speed":
			return (
				"%.2f /s"
				% get_current_healing_speed()
			)

		&"petal_damage":
			return (
				"%.1f"
				% get_current_petal_damage()
			)

	return ""


func get_upgrade_next_value_text(
	upgrade_id: StringName
) -> String:
	match upgrade_id:
		&"healing_per_tick":
			var next_healing: float = (
				get_current_healing_per_tick()
				+ healing_per_tick_per_upgrade
			)

			return (
				"%.1f HP"
				% next_healing
			)

		&"healing_speed":
			var next_level: int = (
				healing_speed_upgrade_level + 1
			)

			var next_interval: float = max(
				base_healing_tick_interval
				- next_level
				* healing_interval_reduction_per_upgrade,
				minimum_healing_tick_interval
			)

			var next_speed: float = 0.0

			if next_interval > 0.0:
				next_speed = (
					1.0 / next_interval
				)

			return (
				"%.2f /s"
				% next_speed
			)

		&"petal_damage":
			var next_damage: float = (
				get_current_petal_damage()
				+ petal_damage_per_upgrade
			)

			return (
				"%.1f"
				% next_damage
			)

	return ""


func purchase_upgrade(
	upgrade_id: StringName
) -> bool:
	match upgrade_id:
		&"healing_per_tick":
			return purchase_healing_per_tick_upgrade()

		&"healing_speed":
			return purchase_healing_speed_upgrade()

		&"petal_damage":
			return purchase_petal_damage_upgrade()

	return false


func on_branch_level_changed() -> void:
	queue_redraw()


func _on_tree_growth_changed(
	_growth_factor: float
) -> void:
	queue_redraw()


func stop_combat() -> void:
	super.stop_combat()

	healing_refresh_time_remaining = 0.0
	attack_time_remaining = 0.0


func resume_combat() -> void:
	super.resume_combat()

	healing_refresh_time_remaining = 0.0
	attack_time_remaining = 0.0
