extends CombatBranch


@export_category("Healing Over Time")
@export var healing_per_tick: float = 3.0
@export var healing_tick_interval: float = 2.0
@export var healing_effect_duration: float = 6.0
@export var effect_refresh_interval: float = 6.0


@export_category("Ranged Combat")
@export var base_ranged_damage: float = 3.0
@export var ranged_attack_interval: float = 2.0
@export var ranged_attack_range: float = 650.0


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
		healing_per_tick,
		healing_tick_interval,
		healing_effect_duration,
		self,
		true
	)


func process_ranged_attack(delta: float) -> void:
	attack_time_remaining -= delta

	if attack_time_remaining > 0.0:
		return

	var target: Node2D = find_best_ranged_target()

	if is_instance_valid(target):
		perform_ranged_attack(target)

	attack_time_remaining = max(
		ranged_attack_interval,
		0.1
	)


func find_best_ranged_target() -> Node2D:
	var own_side_target: Node2D = (
		find_best_target_on_side(
			facing_side
		)
	)

	if is_instance_valid(own_side_target):
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
	var best_target: Node2D = null
	var best_tree_distance: float = INF

	for enemy in get_tree().get_nodes_in_group(
		"enemies"
	):
		if not is_instance_valid(enemy):
			continue

		if enemy is not Node2D:
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

		var distance_from_branch: float = (
			global_position.distance_to(
				enemy_node.global_position
			)
		)

		if distance_from_branch > ranged_attack_range:
			continue

		var distance_from_tree: float = abs(
			horizontal_difference
		)

		if distance_from_tree < best_tree_distance:
			best_tree_distance = (
				distance_from_tree
			)

			best_target = enemy_node

	return best_target


func perform_ranged_attack(
	target: Node2D
) -> void:
	if not is_instance_valid(target):
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
		base_ranged_damage,
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


func get_stat_summary_lines() -> Array[String]:
	return [
		"Healing %.1f per tick"
		% healing_per_tick,

		"Tick Interval %.1f s"
		% healing_tick_interval,

		"Effect Duration %.1f s"
		% healing_effect_duration,

		"Petal Damage %.1f"
		% base_ranged_damage,

		"Petal Attack Speed %.2f /s"
		% get_current_ranged_attack_speed(),

		"Petal Range %.0f"
		% ranged_attack_range
	]


func get_current_ranged_attack_speed() -> float:
	if ranged_attack_interval <= 0.0:
		return 0.0

	return 1.0 / ranged_attack_interval


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
