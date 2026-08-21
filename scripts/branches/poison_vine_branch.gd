extends CombatBranch


const UPGRADE_VENOM_POTENCY: StringName = &"venom_potency"
const UPGRADE_TOXIC_PERSISTENCE: StringName = &"toxic_persistence"
const UPGRADE_APPLICATION_SPEED: StringName = &"application_speed"
const POISON_STATUS_ID: StringName = &"poison"


@export_category("Poison Vine Combat")
@export var base_direct_damage: float = 4.0
@export var base_attack_interval: float = 1.8
@export var minimum_attack_interval: float = 0.60
@export var base_attack_range: float = 650.0
@export_range(0, 8, 1)
var target_lane_index: int = 3


@onready var branch_visual: PoisonVineBranchVisual = $Visual


var venom_potency_upgrade_level: int = 0
var toxic_persistence_upgrade_level: int = 0
var application_speed_upgrade_level: int = 0
var attack_time_remaining: float = 0.0
var active_projectiles: Array[PoisonVineProjectile] = []


func _ready() -> void:
	branch_display_name = "Poison Vine"
	branch_id = &"poison_vine"
	super._ready()
	add_to_group("poison_vine_branch")
	if is_instance_valid(tree_node):
		if tree_node.has_signal("growth_changed"):
			tree_node.growth_changed.connect(_on_tree_growth_changed)
	sync_visual_state()


func _process(delta: float) -> void:
	if not combat_enabled:
		return
	attack_time_remaining -= delta
	if attack_time_remaining > 0.0:
		return
	var target: Node2D = find_poison_target()
	if is_instance_valid(target):
		spawn_poison_projectile(target)
	attack_time_remaining = get_current_attack_interval()


func find_poison_target() -> Node2D:
	var preferred_target: Node2D = _find_under_stack_cap(true)
	if is_instance_valid(preferred_target):
		return preferred_target
	var fallback_lane_target: Node2D = _find_under_stack_cap(false)
	if is_instance_valid(fallback_lane_target):
		return fallback_lane_target
	return CombatTargeting.find_target(
		self,
		branch_definition.targeting_profile,
		_get_preferred_lane_index(),
		base_attack_range,
		get_facing_direction()
	)


func _find_under_stack_cap(require_preferred_lane: bool) -> Node2D:
	if not is_instance_valid(branch_definition):
		return null
	var profile: TargetingProfile = branch_definition.targeting_profile
	var poison_definition: StatusEffectDefinition = GameContent.get_status_effect(POISON_STATUS_ID)
	if not is_instance_valid(profile) or not is_instance_valid(poison_definition):
		return null
	var best_target: Node2D = null
	var best_health: float = -1.0
	for candidate in get_tree().get_nodes_in_group(profile.target_group):
		if not CombatTargeting.is_valid_target(
			self,
			candidate,
			profile,
			base_attack_range,
			get_facing_direction()
		):
			continue
		var candidate_node := candidate as Node2D
		if (
			require_preferred_lane
			and profile.lane_mode == TargetingProfile.LaneMode.PREFERRED
			and not CombatTargeting.is_target_in_preferred_lane(
				candidate_node,
				profile,
				_get_preferred_lane_index()
			)
		):
			continue
		var stacks: int = 0
		if candidate_node.has_method("get_status_effect_stack_count"):
			stacks = int(candidate_node.call("get_status_effect_stack_count", POISON_STATUS_ID))
		if stacks >= poison_definition.maximum_stacks:
			continue
		var health: float = CombatTargeting.get_target_health(candidate_node)
		if (
			not is_instance_valid(best_target)
			or health > best_health
			or (
				is_equal_approx(health, best_health)
				and CombatTargeting.is_better_target(self, candidate_node, best_target, profile)
			)
		):
			best_target = candidate_node
			best_health = health
	return best_target


func _get_preferred_lane_index() -> int:
	return target_lane_index


func spawn_poison_projectile(target: Node2D) -> bool:
	if not is_instance_valid(target) or not is_instance_valid(branch_visual):
		return false
	var projectile_parent: Node = get_tree().current_scene
	if not is_instance_valid(projectile_parent):
		projectile_parent = get_tree().root
	var projectile := PoisonVineProjectile.new()
	projectile_parent.add_child(projectile)
	projectile.global_position = to_global(branch_visual.get_endpoint_local_position())
	projectile.setup(
		target,
		self,
		get_current_direct_damage(),
		get_current_poison_damage_per_stack(),
		get_current_poison_duration()
	)
	active_projectiles.append(projectile)
	projectile.tree_exited.connect(
		_on_projectile_tree_exited.bind(projectile),
		CONNECT_ONE_SHOT
	)
	branch_visual.play_attack_feedback()
	return true


func _on_projectile_tree_exited(projectile: PoisonVineProjectile) -> void:
	active_projectiles.erase(projectile)


func get_current_direct_damage() -> float:
	return BranchStatCalculator.apply_branch_damage(base_direct_damage)


func get_current_poison_damage_per_stack() -> float:
	var definition: StatusEffectDefinition = GameContent.get_status_effect(POISON_STATUS_ID)
	if not is_instance_valid(definition):
		return 0.0
	var base_damage: float = (
		definition.base_periodic_value
		+ venom_potency_upgrade_level
		* get_upgrade_value_per_level(UPGRADE_VENOM_POTENCY)
	)
	return BranchStatCalculator.apply_branch_damage(base_damage)


func get_current_poison_duration() -> float:
	var definition: StatusEffectDefinition = GameContent.get_status_effect(POISON_STATUS_ID)
	if not is_instance_valid(definition):
		return 0.0
	return (
		definition.base_duration
		+ toxic_persistence_upgrade_level
		* get_upgrade_value_per_level(UPGRADE_TOXIC_PERSISTENCE)
	)


func get_current_attack_interval() -> float:
	var raw_interval: float = max(
		base_attack_interval
		- application_speed_upgrade_level
		* get_upgrade_value_per_level(UPGRADE_APPLICATION_SPEED),
		minimum_attack_interval
	)
	return BranchStatCalculator.get_modified_attack_cooldown(
		raw_interval,
		minimum_attack_interval
	)


func get_stat_summary_lines() -> Array[String]:
	return [
		"Direct Damage %.1f" % get_current_direct_damage(),
		"Poison %.1f per stack / tick" % get_current_poison_damage_per_stack(),
		"Poison Duration %.2f s" % get_current_poison_duration(),
		"Attack Speed %.2f /s" % (1.0 / get_current_attack_interval()),
		"Range %.0f" % base_attack_range
	]


func get_progress_upgrade_levels() -> Dictionary:
	return {
		UPGRADE_VENOM_POTENCY: venom_potency_upgrade_level,
		UPGRADE_TOXIC_PERSISTENCE: toxic_persistence_upgrade_level,
		UPGRADE_APPLICATION_SPEED: application_speed_upgrade_level
	}


func apply_progress_upgrade_levels(upgrade_levels: Dictionary) -> void:
	venom_potency_upgrade_level = max(int(upgrade_levels.get(UPGRADE_VENOM_POTENCY, 0)), 0)
	toxic_persistence_upgrade_level = max(int(upgrade_levels.get(UPGRADE_TOXIC_PERSISTENCE, 0)), 0)
	application_speed_upgrade_level = max(int(upgrade_levels.get(UPGRADE_APPLICATION_SPEED, 0)), 0)


func can_apply_progress_upgrade(upgrade_id: StringName, current_level: int) -> bool:
	if not super.can_apply_progress_upgrade(upgrade_id, current_level):
		return false
	if upgrade_id == UPGRADE_APPLICATION_SPEED:
		return (
			base_attack_interval
			- current_level * get_upgrade_value_per_level(upgrade_id)
			> minimum_attack_interval
		)
	return true


func get_upgrade_current_value_text(upgrade_id: StringName) -> String:
	match upgrade_id:
		UPGRADE_VENOM_POTENCY:
			return "%.1f / stack" % get_current_poison_damage_per_stack()
		UPGRADE_TOXIC_PERSISTENCE:
			return "%.2f s" % get_current_poison_duration()
		UPGRADE_APPLICATION_SPEED:
			return "%.2f /s" % (1.0 / get_current_attack_interval())
	return ""


func get_upgrade_next_value_text(upgrade_id: StringName) -> String:
	match upgrade_id:
		UPGRADE_VENOM_POTENCY:
			var next_base: float = (
				GameContent.get_status_effect(POISON_STATUS_ID).base_periodic_value
				+ (venom_potency_upgrade_level + 1) * get_upgrade_value_per_level(upgrade_id)
			)
			return "%.1f / stack" % BranchStatCalculator.apply_branch_damage(next_base)
		UPGRADE_TOXIC_PERSISTENCE:
			return "%.2f s" % (
				get_current_poison_duration() + get_upgrade_value_per_level(upgrade_id)
			)
		UPGRADE_APPLICATION_SPEED:
			var next_interval: float = max(
				base_attack_interval
				- (application_speed_upgrade_level + 1) * get_upgrade_value_per_level(upgrade_id),
				minimum_attack_interval
			)
			return "%.2f /s" % (1.0 / BranchStatCalculator.get_modified_attack_cooldown(next_interval, minimum_attack_interval))
	return ""


func sync_visual_state() -> void:
	if not is_instance_valid(branch_visual):
		return
	branch_visual.set_branch_level(branch_level)
	branch_visual.set_tree_growth_factor(_get_tree_growth_factor())
	branch_visual.set_facing_direction(get_facing_direction())


func _get_tree_growth_factor() -> float:
	if is_instance_valid(tree_node) and tree_node.has_method("get_tree_growth_factor"):
		return float(tree_node.call("get_tree_growth_factor"))
	return 1.0


func _on_tree_growth_changed(growth_factor: float) -> void:
	if is_instance_valid(branch_visual):
		branch_visual.set_tree_growth_factor(growth_factor)


func on_branch_level_changed() -> void:
	sync_visual_state()


func on_shared_progress_applied() -> void:
	sync_visual_state()


func stop_combat() -> void:
	super.stop_combat()
	attack_time_remaining = 0.0
	for projectile in active_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	active_projectiles.clear()
	if is_instance_valid(branch_visual):
		branch_visual.reset_feedback()


func resume_combat() -> void:
	super.resume_combat()
	attack_time_remaining = 0.0
