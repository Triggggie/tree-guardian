extends CombatBranch


const ATTACK_ID: StringName = &"thorn_crown_burst"
const UPGRADE_THORN_DAMAGE: StringName = &"thorn_damage"
const UPGRADE_ATTACK_SPEED: StringName = &"attack_speed"
const UPGRADE_BURST_RADIUS: StringName = &"burst_radius"


@export_category("Thorn Burst")
@export var base_damage: float = 12.0
@export var base_attack_cooldown: float = 2.40
@export var minimum_attack_cooldown: float = 0.80
@export var attack_range: float = 350.0
@export var base_burst_radius: float = 90.0


@onready var branch_visual: ThornCrownVisual = $Visual
@onready var cooldown_timer: Timer = $CooldownTimer


var thorn_damage_upgrade_level: int = 0
var attack_speed_upgrade_level: int = 0
var burst_radius_upgrade_level: int = 0
var left_target: Node2D
var right_target: Node2D
var talent_effect_set: ThornCrownTalentEffectSet
var active_burst_visuals: Array[ThornBurstVisual] = []


func _ready() -> void:
	branch_display_name = "Thorn Crown"
	branch_id = &"thorn_crown"
	super._ready()
	talent_effect_set = ThornCrownTalentEffectSet.new()
	sync_active_talent_effects()
	add_to_group("thorn_crown")
	if is_instance_valid(tree_node) and tree_node.has_signal("growth_changed"):
		tree_node.growth_changed.connect(_on_tree_growth_changed)
	cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)
	update_attack_cooldown()
	sync_visual_state()
	if combat_enabled and cooldown_timer.is_stopped():
		cooldown_timer.start()


func _on_cooldown_timer_timeout() -> void:
	if combat_enabled:
		perform_attack_cycle()


func perform_attack_cycle() -> bool:
	if not combat_enabled:
		return false

	left_target = find_nearest_target_on_side(-1.0)
	right_target = find_nearest_target_on_side(1.0)
	var has_left_target: bool = is_valid_target_on_side(left_target, -1.0)
	var has_right_target: bool = is_valid_target_on_side(right_target, 1.0)
	if not has_left_target and not has_right_target:
		left_target = null
		right_target = null
		return false

	if not talent_effect_set.begin_attack_cycle(has_left_target, has_right_target):
		return false

	var hit_instance_ids: Dictionary = {}
	var cycle_damage_multiplier: float = talent_effect_set.get_cycle_damage_multiplier()
	var cycle_radius: float = (
		get_current_burst_radius()
		* talent_effect_set.get_cycle_radius_multiplier()
	)
	if has_left_target:
		perform_burst(
			left_target,
			-1.0,
			cycle_radius,
			cycle_damage_multiplier,
			hit_instance_ids
		)
	if has_right_target:
		perform_burst(
			right_target,
			1.0,
			cycle_radius,
			cycle_damage_multiplier,
			hit_instance_ids
		)
	left_target = null
	right_target = null
	return true


func find_nearest_target_on_side(side_direction: float) -> Node2D:
	if not is_inside_tree():
		return null
	var best_target: Node2D
	var best_distance: float = INF
	for candidate in get_tree().get_nodes_in_group(get_target_group()):
		if not is_valid_target_on_side(candidate, side_direction):
			continue
		var candidate_node := candidate as Node2D
		var distance: float = abs(candidate_node.global_position.x - global_position.x)
		if (
			distance < best_distance
			or (
				is_equal_approx(distance, best_distance)
				and is_instance_valid(best_target)
				and candidate_node.get_instance_id() < best_target.get_instance_id()
			)
		):
			best_target = candidate_node
			best_distance = distance
	return best_target


func is_valid_target_on_side(target: Node, side_direction: float) -> bool:
	if not is_instance_valid(target) or target is not Node2D:
		return false
	var target_node := target as Node2D
	if (
		not target_node.is_inside_tree()
		or target_node.is_queued_for_deletion()
		or not target_node.is_in_group(get_target_group())
		or not target_node.has_method("take_damage")
		or not target_node.has_method("is_targetable")
		or not bool(target_node.call("is_targetable"))
	):
		return false
	var horizontal_difference: float = target_node.global_position.x - global_position.x
	var safe_side_direction: float = -1.0 if side_direction < 0.0 else 1.0
	return (
		horizontal_difference * safe_side_direction > 0.0
		and abs(horizontal_difference) <= get_current_attack_range()
	)


func perform_burst(
	primary_target: Node2D,
	side_direction: float,
	burst_radius: float,
	cycle_damage_multiplier: float,
	hit_instance_ids: Dictionary
) -> void:
	if not is_valid_target_on_side(primary_target, side_direction):
		return
	var burst_center: Vector2 = primary_target.global_position
	spawn_burst_feedback(burst_center, burst_radius)
	for candidate in get_tree().get_nodes_in_group(get_target_group()):
		if not is_valid_target_on_side(candidate, side_direction):
			continue
		var target := candidate as Node2D
		if target.global_position.distance_to(burst_center) > burst_radius:
			continue
		var instance_id: int = target.get_instance_id()
		if hit_instance_ids.has(instance_id):
			continue
		hit_instance_ids[instance_id] = true
		var is_primary: bool = target == primary_target
		var context: AttackContext = create_burst_attack_context(
			target,
			cycle_damage_multiplier,
			is_primary
		)
		context.set_metadata_value(&"burst_center", burst_center)
		context.set_metadata_value(&"side", &"left" if side_direction < 0.0 else &"right")
		AttackResolver.resolve_damage(context)


func create_burst_attack_context(
	target: Node2D,
	cycle_damage_multiplier: float,
	is_primary: bool
) -> AttackContext:
	var context := AttackContext.new(self, target, get_current_damage())
	context.attack_id = ATTACK_ID
	context.damage_multiplier = max(cycle_damage_multiplier, 0.0)
	context.is_secondary_attack = not is_primary
	for tag_id in [&"thorn_crown", &"legendary", &"apex", &"area_attack"]:
		context.add_tag(tag_id)
	if is_primary:
		context.add_tag(&"primary_target")
		context.damage_multiplier *= talent_effect_set.get_primary_damage_multiplier()
	else:
		context.add_tag(&"splash_target")
	return context


func spawn_burst_feedback(world_position: Vector2, radius: float) -> ThornBurstVisual:
	var visual_parent: Node = get_tree().current_scene
	if not is_instance_valid(visual_parent):
		visual_parent = get_parent()
	if not is_instance_valid(visual_parent):
		return null
	var burst_visual := ThornBurstVisual.new()
	visual_parent.add_child(burst_visual)
	burst_visual.global_position = world_position
	burst_visual.setup(radius)
	active_burst_visuals.append(burst_visual)
	return burst_visual


func get_target_group() -> StringName:
	if is_instance_valid(branch_definition) and is_instance_valid(branch_definition.targeting_profile):
		return branch_definition.targeting_profile.target_group
	return &"enemies"


func get_current_damage() -> float:
	return get_damage_for_upgrade_level(thorn_damage_upgrade_level)


func get_damage_for_upgrade_level(upgrade_level: int) -> float:
	return BranchStatCalculator.apply_branch_damage(
		base_damage
		+ max(upgrade_level, 0) * get_upgrade_value_per_level(UPGRADE_THORN_DAMAGE)
	)


func get_current_attack_cooldown() -> float:
	return get_attack_cooldown_for_upgrade_level(attack_speed_upgrade_level)


func get_attack_cooldown_for_upgrade_level(upgrade_level: int) -> float:
	var base_cooldown: float = max(
		base_attack_cooldown
		- max(upgrade_level, 0) * get_upgrade_value_per_level(UPGRADE_ATTACK_SPEED),
		minimum_attack_cooldown
	)
	return BranchStatCalculator.get_modified_attack_cooldown(
		base_cooldown,
		minimum_attack_cooldown
	)


func get_current_attack_range() -> float:
	return attack_range


func get_current_burst_radius() -> float:
	return get_burst_radius_for_upgrade_level(burst_radius_upgrade_level)


func get_burst_radius_for_upgrade_level(upgrade_level: int) -> float:
	return base_burst_radius + max(upgrade_level, 0) * get_upgrade_value_per_level(UPGRADE_BURST_RADIUS)


func update_attack_cooldown() -> void:
	if is_instance_valid(cooldown_timer):
		cooldown_timer.wait_time = get_current_attack_cooldown()


func sync_visual_state() -> void:
	if not is_instance_valid(branch_visual):
		return
	branch_visual.set_branch_level(branch_level)
	branch_visual.set_tree_growth_factor(get_tree_growth_factor())


func get_tree_growth_factor() -> float:
	if is_instance_valid(tree_node) and tree_node.has_method("get_tree_growth_factor"):
		return float(tree_node.call("get_tree_growth_factor"))
	return 1.0


func _on_tree_growth_changed(growth_factor: float) -> void:
	if is_instance_valid(branch_visual):
		branch_visual.set_tree_growth_factor(growth_factor)


func sync_active_talent_effects() -> void:
	if is_instance_valid(talent_effect_set):
		talent_effect_set.set_active_effect_ids(get_active_talent_effect_ids())


func on_talent_purchased(_talent_id: StringName) -> void:
	sync_active_talent_effects()


func get_stat_summary_lines() -> Array[String]:
	var cooldown: float = get_current_attack_cooldown()
	return [
		"Damage %.1f" % get_current_damage(),
		"Attack Speed %.2f /s" % (0.0 if cooldown <= 0.0 else 1.0 / cooldown),
		"Range %.0f" % get_current_attack_range(),
		"Burst Radius %.0f" % get_current_burst_radius()
	]


func get_progress_upgrade_levels() -> Dictionary:
	return {
		UPGRADE_THORN_DAMAGE: thorn_damage_upgrade_level,
		UPGRADE_ATTACK_SPEED: attack_speed_upgrade_level,
		UPGRADE_BURST_RADIUS: burst_radius_upgrade_level
	}


func apply_progress_upgrade_levels(upgrade_levels: Dictionary) -> void:
	thorn_damage_upgrade_level = max(int(upgrade_levels.get(UPGRADE_THORN_DAMAGE, 0)), 0)
	attack_speed_upgrade_level = max(int(upgrade_levels.get(UPGRADE_ATTACK_SPEED, 0)), 0)
	burst_radius_upgrade_level = max(int(upgrade_levels.get(UPGRADE_BURST_RADIUS, 0)), 0)


func on_shared_progress_applied() -> void:
	update_attack_cooldown()
	sync_visual_state()
	sync_active_talent_effects()


func get_upgrade_current_value_text(upgrade_id: StringName) -> String:
	match upgrade_id:
		UPGRADE_THORN_DAMAGE:
			return "%.1f" % get_current_damage()
		UPGRADE_ATTACK_SPEED:
			var cooldown: float = get_current_attack_cooldown()
			return "%.2f /s" % (0.0 if cooldown <= 0.0 else 1.0 / cooldown)
		UPGRADE_BURST_RADIUS:
			return "%.0f px" % get_current_burst_radius()
	return ""


func get_upgrade_next_value_text(upgrade_id: StringName) -> String:
	match upgrade_id:
		UPGRADE_THORN_DAMAGE:
			return "%.1f" % get_damage_for_upgrade_level(thorn_damage_upgrade_level + 1)
		UPGRADE_ATTACK_SPEED:
			var cooldown: float = get_attack_cooldown_for_upgrade_level(attack_speed_upgrade_level + 1)
			return "%.2f /s" % (0.0 if cooldown <= 0.0 else 1.0 / cooldown)
		UPGRADE_BURST_RADIUS:
			return "%.0f px" % get_burst_radius_for_upgrade_level(burst_radius_upgrade_level + 1)
	return ""


func stop_combat() -> void:
	super.stop_combat()
	left_target = null
	right_target = null
	if is_instance_valid(cooldown_timer):
		cooldown_timer.stop()
	if is_instance_valid(talent_effect_set):
		talent_effect_set.reset_runtime_state()
	clear_burst_visuals()


func resume_combat() -> void:
	super.resume_combat()
	left_target = null
	right_target = null
	if is_instance_valid(talent_effect_set):
		talent_effect_set.reset_runtime_state()
	clear_burst_visuals()
	update_attack_cooldown()
	if combat_enabled and cooldown_timer.is_stopped():
		cooldown_timer.start()


func clear_burst_visuals() -> void:
	for burst_visual in active_burst_visuals:
		if is_instance_valid(burst_visual):
			burst_visual.queue_free()
	active_burst_visuals.clear()
