class_name CombatBranch
extends Node2D


signal level_changed(new_level: int)

signal talent_points_changed(
	available_points: int,
	total_points_earned: int
)

signal talent_point_gained(
	new_level: int,
	available_points: int
)

signal talent_changed(
	talent_id: StringName,
	is_purchased: bool
)

signal upgrade_changed(
	upgrade_id: StringName,
	new_level: int
)

signal xp_changed(
	current_xp: int,
	xp_required: int
)


@export_category("Branch Identity")
@export var branch_display_name: String = "Combat Branch"
@export var branch_id: StringName = &"combat_branch"


@export_category("Branch Position")
@export_enum("Left", "Right")
var facing_side: int = 0


@export_category("Branch Slot")
@export_range(1, 5, 1)
var slot_index: int = 1


@export_category("Progression")
@export var xp_required_per_level: int = 2

@export var talent_point_levels: Array[int] = [
	2,
	4,
	7,
	10,
	14
]


@export_category("Upgrade Limits")
@export_range(1, 20, 1)
var upgrade_levels_per_branch_level: int = 3

@export_range(1.01, 5.0, 0.01)
var upgrade_cost_growth: float = 1.35


var branch_level: int = 1
var current_xp: int = 0

var available_talent_points: int = 0
var total_talent_points_earned: int = 0

var purchased_talents: Dictionary = {}

var combat_enabled: bool = true
var tree_node: Node2D


func _ready() -> void:
	add_to_group("combat_branch")
	find_tree_node()


func find_tree_node() -> void:
	tree_node = null

	var current_node: Node = get_parent()

	while current_node != null:
		if current_node is Node2D:
			if current_node.has_method(
				"spend_forest_essence"
			):
				if current_node.has_method(
					"get_tree_growth_factor"
				):
					tree_node = (
						current_node as Node2D
					)

					return

		current_node = current_node.get_parent()

	var grouped_tree: Node = (
		get_tree().get_first_node_in_group(
			"tree"
		)
	)

	if grouped_tree is Node2D:
		tree_node = grouped_tree as Node2D


func get_facing_direction() -> float:
	if facing_side == 0:
		return -1.0

	return 1.0


func get_available_talent_points() -> int:
	return available_talent_points


func get_total_talent_points_earned() -> int:
	return total_talent_points_earned


func get_maximum_essence_upgrade_level() -> int:
	return max(
		branch_level
		* upgrade_levels_per_branch_level,
		1
	)


func get_upgrade_cost(
	base_cost: int,
	current_upgrade_level: int
) -> int:
	var calculated_cost: float = (
		float(base_cost)
		* pow(
			upgrade_cost_growth,
			current_upgrade_level
		)
	)

	return max(
		int(round(calculated_cost)),
		1
	)


func can_upgrade_stat(
	current_upgrade_level: int
) -> bool:
	return (
		current_upgrade_level
		< get_maximum_essence_upgrade_level()
	)


func try_spend_essence(
	amount: int
) -> bool:
	if amount <= 0:
		return false

	if not is_instance_valid(tree_node):
		find_tree_node()

	if not is_instance_valid(tree_node):
		push_warning(
			"%s: Tree node was not found."
			% branch_display_name
		)

		return false

	if not tree_node.has_method(
		"spend_forest_essence"
	):
		push_warning(
			"%s: Tree does not implement "
			+ "spend_forest_essence()."
			% branch_display_name
		)

		return false

	return tree_node.spend_forest_essence(
		amount
	)


func get_safe_xp_required_per_level() -> int:
	return max(
		xp_required_per_level,
		1
	)


func add_xp(
	amount: int
) -> void:
	if amount <= 0:
		return

	var safe_xp_required: int = (
		get_safe_xp_required_per_level()
	)

	current_xp += amount

	print(
		branch_display_name,
		" gained ",
		amount,
		" XP | XP: ",
		current_xp,
		"/",
		safe_xp_required
	)

	while current_xp >= safe_xp_required:
		current_xp -= safe_xp_required
		level_up()

	xp_changed.emit(
		current_xp,
		safe_xp_required
	)


func level_up() -> void:
	branch_level += 1

	level_changed.emit(
		branch_level
	)

	check_for_talent_point()
	on_branch_level_changed()

	print(
		branch_display_name,
		" reached Level ",
		branch_level,
		" | Maximum Essence Upgrade Level: ",
		get_maximum_essence_upgrade_level(),
		" | Talent Points: ",
		available_talent_points
	)


func on_branch_level_changed() -> void:
	pass


func check_for_talent_point() -> void:
	if branch_level not in talent_point_levels:
		return

	available_talent_points += 1
	total_talent_points_earned += 1

	talent_points_changed.emit(
		available_talent_points,
		total_talent_points_earned
	)

	talent_point_gained.emit(
		branch_level,
		available_talent_points
	)

	print(
		branch_display_name,
		" gained a Talent Point at Level ",
		branch_level,
		" | Available: ",
		available_talent_points
	)


func spend_talent_points(
	amount: int
) -> bool:
	if amount <= 0:
		return false

	if available_talent_points < amount:
		return false

	available_talent_points -= amount

	talent_points_changed.emit(
		available_talent_points,
		total_talent_points_earned
	)

	return true


# -------------------------------------------------------------------
# Talent system
# -------------------------------------------------------------------


func has_talent(
	talent_id: StringName
) -> bool:
	return purchased_talents.get(
		talent_id,
		false
	)


func can_purchase_talent(
	talent_id: StringName
) -> bool:
	if talent_id not in get_talent_ids():
		return false

	if has_talent(talent_id):
		return false

	var required_level: int = (
		get_talent_required_level(
			talent_id
		)
	)

	if branch_level < required_level:
		return false

	var cost: int = get_talent_cost(
		talent_id
	)

	if available_talent_points < cost:
		return false

	var prerequisites: Array[StringName] = (
		get_talent_prerequisites(
			talent_id
		)
	)

	for prerequisite_id in prerequisites:
		if not has_talent(prerequisite_id):
			return false

	var conflicting_talents: Array[StringName] = (
		get_talent_conflicts(
			talent_id
		)
	)

	for conflicting_talent_id in conflicting_talents:
		if has_talent(conflicting_talent_id):
			return false

	return true


func purchase_talent(
	talent_id: StringName
) -> bool:
	if not can_purchase_talent(
		talent_id
	):
		return false

	var cost: int = get_talent_cost(
		talent_id
	)

	if not spend_talent_points(cost):
		return false

	purchased_talents[
		talent_id
	] = true

	on_talent_purchased(
		talent_id
	)

	talent_changed.emit(
		talent_id,
		true
	)

	print(
		branch_display_name,
		" purchased talent ",
		get_talent_display_name(
			talent_id
		),
		" | Cost: ",
		cost,
		" | Remaining Talent Points: ",
		available_talent_points
	)

	return true


func on_talent_purchased(
	_talent_id: StringName
) -> void:
	pass


func get_talent_ids() -> Array[StringName]:
	return []


func get_talent_display_name(
	_talent_id: StringName
) -> String:
	return "Unknown Talent"


func get_talent_description(
	_talent_id: StringName
) -> String:
	return ""


func get_talent_branch_name(
	_talent_id: StringName
) -> String:
	return ""


func get_talent_required_level(
	_talent_id: StringName
) -> int:
	return 1


func get_talent_cost(
	_talent_id: StringName
) -> int:
	return 1


func get_talent_prerequisites(
	_talent_id: StringName
) -> Array[StringName]:
	return []


func get_talent_conflicts(
	_talent_id: StringName
) -> Array[StringName]:
	return []


func get_talent_status_text(
	talent_id: StringName
) -> String:
	if has_talent(talent_id):
		return "PURCHASED"

	var required_level: int = (
		get_talent_required_level(
			talent_id
		)
	)

	if branch_level < required_level:
		return (
			"REQUIRES LEVEL %d"
			% required_level
		)

	var prerequisites: Array[StringName] = (
		get_talent_prerequisites(
			talent_id
		)
	)

	for prerequisite_id in prerequisites:
		if not has_talent(prerequisite_id):
			return "REQUIRES PREVIOUS TALENT"

	var conflicting_talents: Array[StringName] = (
		get_talent_conflicts(
			talent_id
		)
	)

	for conflicting_talent_id in conflicting_talents:
		if has_talent(conflicting_talent_id):
			return "LOCKED BY YOUR CHOICE"

	var cost: int = get_talent_cost(
		talent_id
	)

	if available_talent_points < cost:
		return (
			"NEEDS %d TALENT POINTS"
			% cost
		)

	return (
		"UNLOCK — %d TP"
		% cost
	)


# -------------------------------------------------------------------
# Combat state
# -------------------------------------------------------------------


func stop_combat() -> void:
	combat_enabled = false


func resume_combat() -> void:
	combat_enabled = true


# -------------------------------------------------------------------
# General branch UI interface
# -------------------------------------------------------------------


func get_branch_display_name() -> String:
	return branch_display_name


func get_branch_side_name() -> String:
	if facing_side == 0:
		return "Left"

	return "Right"


func get_progress_summary_lines() -> Array[String]:
	return [
		"Level %d"
		% branch_level,

		"XP %d / %d"
		% [
			current_xp,
			get_safe_xp_required_per_level()
		],

		"Talent Points %d"
		% available_talent_points
	]


func get_stat_summary_lines() -> Array[String]:
	return []


# -------------------------------------------------------------------
# General Essence-upgrade UI interface
# -------------------------------------------------------------------


func get_upgrade_ids() -> Array[StringName]:
	return []


func get_upgrade_display_name(
	_upgrade_id: StringName
) -> String:
	return "Upgrade"


func get_upgrade_level(
	_upgrade_id: StringName
) -> int:
	return 0


func get_upgrade_maximum_level(
	_upgrade_id: StringName
) -> int:
	return 0


func get_upgrade_cost_by_id(
	_upgrade_id: StringName
) -> int:
	return 0


func get_upgrade_current_value_text(
	_upgrade_id: StringName
) -> String:
	return ""


func get_upgrade_next_value_text(
	_upgrade_id: StringName
) -> String:
	return ""


func purchase_upgrade(
	_upgrade_id: StringName
) -> bool:
	return false
