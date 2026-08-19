extends CombatBranch

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

@onready var cooldown_timer: Timer = $CooldownTimer
@onready var branch_visual: StrengthBranchVisual = $Visual

var damage_upgrade_level: int = 0
var attack_speed_upgrade_level: int = 0
var range_upgrade_level: int = 0
var resting_rotation: float
var current_target: Node2D
var talent_effect_set: StrengthTalentEffectSet
var has_warned_missing_branch_visual: bool = false
var attack_tween: Tween

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
	initialize_talent_effects()
	add_to_group("strength_branch")
	resting_rotation = rotation
	if is_instance_valid(tree_node):
		if tree_node.has_signal("growth_changed"):
			tree_node.growth_changed.connect(_on_tree_growth_changed)
		if tree_node.has_signal("age_changed"):
			tree_node.age_changed.connect(_on_tree_age_changed)
	cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)
	update_attack_cooldown()
	sync_visual_state()
	if cooldown_timer.is_stopped():
		cooldown_timer.start()


func initialize_talent_effects() -> void:
	talent_effect_set = StrengthTalentEffectSet.new()

	talent_effect_set.configure(
		self,
		sweeping_strike_damage_multiplier,
		sweeping_strike_search_radius,
		rebuff_distance,
		marked_prey_damage_per_stack,
		marked_prey_maximum_stacks
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

func get_branch_growth_progress() -> float:
	if not is_instance_valid(branch_visual):
		warn_missing_branch_visual_once()
		return 0.0

	return branch_visual.get_branch_growth_progress()

func get_tree_growth_factor() -> float:
	if not is_instance_valid(tree_node):
		return 1.0
	if tree_node.has_method("get_tree_growth_factor"):
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

	branch_visual.set_presentation_context(
		get_slot_id(),
		get_tree_age()
	)


func get_tree_age() -> int:
	if not is_instance_valid(tree_node):
		return 1

	return int(tree_node.get("age"))


func warn_missing_branch_visual_once() -> void:
	if has_warned_missing_branch_visual:
		return

	has_warned_missing_branch_visual = true

	push_warning(
		"Strength Branch: Visual node is missing."
	)

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
	return super.purchase_upgrade(UPGRADE_DAMAGE)

func purchase_attack_speed_upgrade() -> bool:
	return super.purchase_upgrade(UPGRADE_ATTACK_SPEED)

func purchase_range_upgrade() -> bool:
	return super.purchase_upgrade(UPGRADE_RANGE)

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


func on_runtime_modifiers_changed() -> void:
	update_attack_cooldown()

func _on_tree_growth_changed(_growth_factor: float) -> void:
	if not is_instance_valid(branch_visual):
		warn_missing_branch_visual_once()
		return

	branch_visual.set_tree_growth_factor(
		_growth_factor
	)


func _on_tree_age_changed(new_age: int) -> void:
	if not is_instance_valid(branch_visual):
		warn_missing_branch_visual_once()
		return

	branch_visual.set_presentation_context(
		get_slot_id(),
		new_age
	)

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
	if is_instance_valid(talent_effect_set):
		var danger_target: Node2D = talent_effect_set.find_danger_target()
		if is_instance_valid(danger_target):
			return danger_target

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

	if is_instance_valid(attack_tween):
		attack_tween.kill()
	attack_tween = create_tween()

	attack_tween.set_trans(
		Tween.TRANS_QUAD
	)

	attack_tween.set_ease(
		Tween.EASE_OUT
	)

	attack_tween.tween_property(
		self,
		"rotation",
		attack_rotation,
		attack_duration
	)

	attack_tween.tween_callback(
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

	attack_tween.tween_property(
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

	var primary_damage: float = get_current_damage()

	if is_instance_valid(talent_effect_set):
		primary_damage = (
			talent_effect_set.get_primary_damage(
				primary_target,
				primary_damage
			)
		)

	var primary_context := AttackContext.new(
		self,
		primary_target,
		primary_damage
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

	if (
		primary_hit_resolved
		and is_instance_valid(talent_effect_set)
	):
		talent_effect_set.apply_after_primary_resolved(
			primary_target,
			get_current_damage()
		)
		var cooldown_multiplier: float = (
			talent_effect_set.consume_next_cooldown_multiplier()
		)
		cooldown_timer.start(
			max(
				get_current_attack_cooldown() * cooldown_multiplier,
				minimum_attack_cooldown
			)
		)
	elif is_instance_valid(talent_effect_set):
		talent_effect_set.cancel_pending_primary()


func play_strength_talent_feedback(feedback_id: StringName) -> void:
	if is_instance_valid(branch_visual) and branch_visual.has_method("play_talent_feedback"):
		branch_visual.call("play_talent_feedback", feedback_id)

func on_branch_level_changed() -> void:
	sync_visual_state()
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
	if is_instance_valid(attack_tween):
		attack_tween.kill()
		attack_tween = null
	if is_instance_valid(talent_effect_set):
		talent_effect_set.reset_runtime_state()
	if is_instance_valid(branch_visual) and branch_visual.has_method("reset_talent_feedback"):
		branch_visual.call("reset_talent_feedback")
	cooldown_timer.stop()
	var active_tween: Tween = create_tween()
	active_tween.tween_property(self, "rotation", resting_rotation, 0.1)

func resume_combat() -> void:
	super.resume_combat()
	current_target = null
	if is_instance_valid(talent_effect_set):
		talent_effect_set.reset_runtime_state()
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
	return super.get_upgrade_level(upgrade_id)


func get_progress_upgrade_levels() -> Dictionary:
	return {
		UPGRADE_DAMAGE: damage_upgrade_level,
		UPGRADE_ATTACK_SPEED: attack_speed_upgrade_level,
		UPGRADE_RANGE: range_upgrade_level
	}


func apply_progress_upgrade_levels(
	upgrade_levels: Dictionary
) -> void:
	damage_upgrade_level = max(
		int(upgrade_levels.get(UPGRADE_DAMAGE, 0)),
		0
	)
	attack_speed_upgrade_level = max(
		int(upgrade_levels.get(UPGRADE_ATTACK_SPEED, 0)),
		0
	)
	range_upgrade_level = max(
		int(upgrade_levels.get(UPGRADE_RANGE, 0)),
		0
	)


func on_shared_progress_applied() -> void:
	update_attack_cooldown()
	sync_visual_state()
	sync_active_talent_effects()


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
	return super.purchase_upgrade(upgrade_id)
