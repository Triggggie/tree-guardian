extends CombatBranch


const UPGRADE_HEALING_PER_TICK: StringName = &"healing_per_tick"
const UPGRADE_HEALING_SPEED: StringName = &"healing_speed"
const UPGRADE_PETAL_DAMAGE: StringName = &"petal_damage"
const HEALING_EFFECT_ID_PREFIX: String = "blossom_healing"


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


@export_category("Talent Balance")

@export_range(1.0, 5.0, 0.05)
var abundant_bloom_healing_multiplier: float = 1.50

@export_range(0.1, 1.0, 0.05)
var quickening_pollen_interval_multiplier: float = 0.80

@export_range(0.0, 2.0, 0.05)
var twin_petals_damage_multiplier: float = 0.60


@onready var branch_visual: BlossomBranchVisual = $Visual


var healing_per_tick_upgrade_level: int = 0
var healing_speed_upgrade_level: int = 0
var petal_damage_upgrade_level: int = 0

var healing_refresh_time_remaining: float = 0.0
var attack_time_remaining: float = 0.0
var healing_effect_id: StringName = &""
var has_warned_missing_branch_visual: bool = false
var talent_effect_set: BlossomTalentEffectSet
var active_projectiles: Array[BlossomProjectile] = []


func _ready() -> void:
	branch_display_name = "Blossom Branch"
	branch_id = &"blossom_branch"

	super._ready()
	initialize_talent_effects()

	add_to_group("blossom_branch")

	if is_instance_valid(tree_node):
		if tree_node.has_signal("growth_changed"):
			tree_node.growth_changed.connect(
				_on_tree_growth_changed
			)

	healing_refresh_time_remaining = 0.0
	attack_time_remaining = 0.0

	sync_visual_state()


func initialize_talent_effects() -> void:
	talent_effect_set = BlossomTalentEffectSet.new()

	talent_effect_set.configure(
		self,
		abundant_bloom_healing_multiplier,
		quickening_pollen_interval_multiplier,
		twin_petals_damage_multiplier
	)

	sync_active_talent_effects()


func sync_active_talent_effects() -> void:
	if not is_instance_valid(talent_effect_set):
		return

	talent_effect_set.set_active_effect_ids(
		get_active_talent_effect_ids()
	)


func on_talent_purchased(
	_talent_id: StringName
) -> void:
	sync_active_talent_effects()
	refresh_healing_effect()


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
		get_healing_effect_id(),
		get_current_healing_per_tick(),
		get_current_healing_tick_interval(),
		healing_effect_duration,
		self,
		true
	)


func get_healing_effect_id() -> StringName:
	if healing_effect_id == &"":
		healing_effect_id = StringName(
			"%s_%d"
			% [
				HEALING_EFFECT_ID_PREFIX,
				get_instance_id()
			]
		)

	return healing_effect_id


func get_current_healing_per_tick() -> float:
	return get_healing_per_tick_for_upgrade_level(
		healing_per_tick_upgrade_level
	)


func get_healing_per_tick_for_upgrade_level(
	upgrade_level: int
) -> float:
	var current_base_healing: float = (
		base_healing_per_tick
		+ max(upgrade_level, 0)
		* get_upgrade_value_per_level(
			UPGRADE_HEALING_PER_TICK
		)
	)

	var current_healing: float = (
		BranchStatCalculator.apply_healing_power(
			current_base_healing
		)
	)

	if is_instance_valid(talent_effect_set):
		current_healing = (
			talent_effect_set.apply_healing_per_tick(
				current_healing
			)
		)

	return current_healing


func get_healing_tick_interval_before_talents(
	upgrade_level: int
) -> float:
	return max(
		base_healing_tick_interval
		- max(upgrade_level, 0)
		* get_upgrade_value_per_level(
			UPGRADE_HEALING_SPEED
		),
		0.0
	)


func get_healing_tick_interval_for_upgrade_level(
	upgrade_level: int
) -> float:
	var calculated_interval: float = (
		get_healing_tick_interval_before_talents(
			upgrade_level
		)
	)

	if is_instance_valid(talent_effect_set):
		return talent_effect_set.apply_healing_tick_interval(
			calculated_interval,
			minimum_healing_tick_interval
		)

	return max(
		calculated_interval,
		minimum_healing_tick_interval
	)


func get_current_healing_tick_interval() -> float:
	return get_healing_tick_interval_for_upgrade_level(
		healing_speed_upgrade_level
	)


func get_current_petal_damage() -> float:
	var current_base_damage: float = (
		base_ranged_damage
		+ petal_damage_upgrade_level
		* get_upgrade_value_per_level(
			UPGRADE_PETAL_DAMAGE
		)
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
	target_side: int,
	excluded_target: Node2D = null
) -> Node2D:
	if not is_instance_valid(tree_node):
		return null

	var best_target: Node2D = null
	var best_tree_distance: float = INF

	for enemy in get_tree().get_nodes_in_group(
		"enemies"
	):
		if enemy == excluded_target:
			continue

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

	var secondary_target: Node2D = null
	var primary_damage: float = get_current_petal_damage()

	if is_instance_valid(talent_effect_set):
		secondary_target = (
			talent_effect_set.find_secondary_petal_target(
				target
			)
		)

	if not spawn_petal_projectile(
		target,
		primary_damage
	):
		return

	if (
		is_valid_ranged_target(secondary_target)
		and is_instance_valid(talent_effect_set)
	):
		var secondary_damage: float = (
			talent_effect_set.get_secondary_petal_damage(
				primary_damage
			)
		)

		spawn_petal_projectile(
			secondary_target,
			secondary_damage
		)

	play_ranged_attack_feedback()


func spawn_petal_projectile(
	target: Node2D,
	damage: float
) -> bool:
	if not is_valid_ranged_target(target):
		return false

	var projectile_parent: Node = get_tree().current_scene

	if not is_instance_valid(projectile_parent):
		return false

	var projectile := BlossomProjectile.new()

	projectile_parent.add_child(
		projectile
	)

	projectile.global_position = (
		get_projectile_spawn_position()
	)

	projectile.setup(
		target,
		max(damage, 0.0),
		self
	)
	active_projectiles.append(projectile)
	projectile.tree_exited.connect(
		_on_projectile_tree_exited.bind(projectile),
		CONNECT_ONE_SHOT
	)

	return true


func _on_projectile_tree_exited(projectile: BlossomProjectile) -> void:
	active_projectiles.erase(projectile)


func clear_active_projectiles() -> void:
	for projectile in active_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	active_projectiles.clear()


func clear_healing_effect() -> void:
	if (
		healing_effect_id == &""
		or not is_instance_valid(tree_node)
		or not tree_node.has_method("remove_healing_over_time_effect")
	):
		return
	tree_node.call("remove_healing_over_time_effect", healing_effect_id)


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
	if not is_instance_valid(branch_visual):
		warn_missing_branch_visual_once()
		return 0.0

	return branch_visual.get_branch_growth_progress()


func get_tree_growth_factor() -> float:
	if not is_instance_valid(tree_node):
		return 1.0

	if tree_node.has_method(
		"get_tree_growth_factor"
	):
		return tree_node.get_tree_growth_factor()

	return 1.0


func get_current_length() -> float:
	if not is_instance_valid(branch_visual):
		warn_missing_branch_visual_once()
		return 0.0

	return branch_visual.get_current_length()


func get_current_thickness() -> float:
	if not is_instance_valid(branch_visual):
		warn_missing_branch_visual_once()
		return 0.0

	return branch_visual.get_current_thickness()


func sync_visual_state() -> void:
	if not is_instance_valid(branch_visual):
		warn_missing_branch_visual_once()
		return

	branch_visual.set_branch_level(
		branch_level
	)

	branch_visual.set_tree_growth_factor(
		get_tree_growth_factor()
	)

	branch_visual.set_facing_direction(
		get_facing_direction()
	)


func warn_missing_branch_visual_once() -> void:
	if has_warned_missing_branch_visual:
		return

	has_warned_missing_branch_visual = true

	push_warning(
		"Blossom Branch: Visual node is missing."
	)


func get_healing_per_tick_upgrade_cost() -> int:
	return get_upgrade_cost_by_id(
		UPGRADE_HEALING_PER_TICK
	)


func get_healing_speed_upgrade_cost() -> int:
	return get_upgrade_cost_by_id(
		UPGRADE_HEALING_SPEED
	)


func get_petal_damage_upgrade_cost() -> int:
	return get_upgrade_cost_by_id(
		UPGRADE_PETAL_DAMAGE
	)


func purchase_healing_per_tick_upgrade() -> bool:
	return super.purchase_upgrade(UPGRADE_HEALING_PER_TICK)


func purchase_healing_speed_upgrade() -> bool:
	return super.purchase_upgrade(UPGRADE_HEALING_SPEED)


func purchase_petal_damage_upgrade() -> bool:
	return super.purchase_upgrade(UPGRADE_PETAL_DAMAGE)


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


func get_upgrade_level(
	upgrade_id: StringName
) -> int:
	return super.get_upgrade_level(upgrade_id)


func get_progress_upgrade_levels() -> Dictionary:
	return {
		UPGRADE_HEALING_PER_TICK: healing_per_tick_upgrade_level,
		UPGRADE_HEALING_SPEED: healing_speed_upgrade_level,
		UPGRADE_PETAL_DAMAGE: petal_damage_upgrade_level
	}


func apply_progress_upgrade_levels(
	upgrade_levels: Dictionary
) -> void:
	healing_per_tick_upgrade_level = max(
		int(upgrade_levels.get(UPGRADE_HEALING_PER_TICK, 0)),
		0
	)
	healing_speed_upgrade_level = max(
		int(upgrade_levels.get(UPGRADE_HEALING_SPEED, 0)),
		0
	)
	petal_damage_upgrade_level = max(
		int(upgrade_levels.get(UPGRADE_PETAL_DAMAGE, 0)),
		0
	)


func on_shared_progress_applied() -> void:
	refresh_healing_effect()
	sync_visual_state()
	sync_active_talent_effects()


func can_apply_progress_upgrade(
	upgrade_id: StringName,
	current_level: int
) -> bool:
	if not super.can_apply_progress_upgrade(upgrade_id, current_level):
		return false

	if upgrade_id == UPGRADE_HEALING_SPEED:
		return (
			get_healing_tick_interval_before_talents(current_level)
			> minimum_healing_tick_interval
		)

	return true


func get_upgrade_current_value_text(
	upgrade_id: StringName
) -> String:
	match upgrade_id:
		UPGRADE_HEALING_PER_TICK:
			return (
				"%.1f HP"
				% get_current_healing_per_tick()
			)

		UPGRADE_HEALING_SPEED:
			return (
				"%.2f /s"
				% get_current_healing_speed()
			)

		UPGRADE_PETAL_DAMAGE:
			return (
				"%.1f"
				% get_current_petal_damage()
			)

	return ""


func get_upgrade_next_value_text(
	upgrade_id: StringName
) -> String:
	match upgrade_id:
		UPGRADE_HEALING_PER_TICK:
			var next_healing: float = (
				get_healing_per_tick_for_upgrade_level(
					healing_per_tick_upgrade_level + 1
				)
			)

			return (
				"%.1f HP"
				% next_healing
			)

		UPGRADE_HEALING_SPEED:
			var next_level: int = (
				healing_speed_upgrade_level + 1
			)

			var next_interval: float = (
				get_healing_tick_interval_for_upgrade_level(
					next_level
				)
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

		UPGRADE_PETAL_DAMAGE:
			var next_damage: float = (
				get_current_petal_damage()
				+ get_upgrade_value_per_level(
					UPGRADE_PETAL_DAMAGE
				)
			)

			return (
				"%.1f"
				% next_damage
			)

	return ""


func purchase_upgrade(
	upgrade_id: StringName
) -> bool:
	return super.purchase_upgrade(upgrade_id)


func on_branch_level_changed() -> void:
	sync_visual_state()


func _on_tree_growth_changed(
	_growth_factor: float
) -> void:
	if not is_instance_valid(branch_visual):
		warn_missing_branch_visual_once()
		return

	branch_visual.set_tree_growth_factor(
		_growth_factor
	)


func stop_combat() -> void:
	super.stop_combat()

	if is_instance_valid(talent_effect_set):
		talent_effect_set.reset_runtime_state()

	healing_refresh_time_remaining = 0.0
	attack_time_remaining = 0.0
	clear_active_projectiles()
	clear_healing_effect()


func resume_combat() -> void:
	super.resume_combat()

	if is_instance_valid(talent_effect_set):
		talent_effect_set.reset_runtime_state()

	healing_refresh_time_remaining = 0.0
	attack_time_remaining = 0.0
