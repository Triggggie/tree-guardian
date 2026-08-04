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


@export_category("Talent Definitions")
@export var talent_tree_definition: TalentTreeDefinition


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
var branch_definition: BranchDefinition
var branch_progress_service: BranchProgressService
var has_warned_invalid_slot_assignment: bool = false


func _ready() -> void:
	load_branch_definition()
	resolve_branch_progress_service()

	if is_instance_valid(branch_progress_service):
		branch_progress_service.register_branch(self)

	validate_slot_assignment()
	add_to_group("combat_branch")
	find_tree_node()


func _exit_tree() -> void:
	if is_instance_valid(branch_progress_service):
		branch_progress_service.unregister_branch(self)


func resolve_branch_progress_service() -> void:
	if is_instance_valid(branch_progress_service):
		return

	branch_progress_service = get_node_or_null(
		"/root/BranchProgress"
	) as BranchProgressService

	if not is_instance_valid(branch_progress_service):
		push_warning(
			"%s: BranchProgress service was not found."
			% branch_display_name
		)


func load_branch_definition() -> void:
	branch_definition = null

	if branch_id == &"":
		push_warning(
			"CombatBranch: Cannot load a BranchDefinition "
			+ "without a branch_id."
		)
		return

	branch_definition = GameContent.get_branch(
		branch_id
	)

	if not is_instance_valid(branch_definition):
		push_warning(
			"CombatBranch: BranchDefinition '%s' was not found."
			% branch_id
		)
		return

	talent_tree_definition = branch_definition.talent_tree


func is_slot_assignment_valid() -> bool:
	return BranchSlotRules.can_place_definition(
		branch_definition,
		slot_index
	)


func get_branch_category_id() -> StringName:
	if not is_instance_valid(branch_definition):
		return &""

	return branch_definition.category_id


func is_legendary_branch() -> bool:
	if not is_instance_valid(branch_definition):
		return false

	return branch_definition.is_legendary_branch()


func validate_slot_assignment() -> void:
	if is_slot_assignment_valid():
		return

	combat_enabled = false
	warn_invalid_slot_assignment_once()


func warn_invalid_slot_assignment_once() -> void:
	if has_warned_invalid_slot_assignment:
		return

	has_warned_invalid_slot_assignment = true

	push_warning(
		"%s: BranchDefinition category '%s' cannot use slot %d."
		% [
			branch_display_name,
			get_branch_category_id(),
			slot_index
		]
	)


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
	if not is_instance_valid(branch_progress_service):
		return

	branch_progress_service.add_xp(self, amount)


func level_up() -> void:
	add_xp(get_safe_xp_required_per_level())


func on_branch_level_changed() -> void:
	pass


func check_for_talent_point() -> void:
	push_warning(
		"CombatBranch.check_for_talent_point() is managed by BranchProgress."
	)


func spend_talent_points(
	amount: int
) -> bool:
	return false


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


func get_active_talent_effect_ids() -> Array[StringName]:
	var active_effect_ids: Array[StringName] = []
	var seen_effect_ids: Dictionary = {}

	if not is_instance_valid(
		talent_tree_definition
	):
		return active_effect_ids

	for talent_definition in talent_tree_definition.talents:
		if not is_instance_valid(talent_definition):
			continue

		if not has_talent(
			talent_definition.talent_id
		):
			continue

		for effect_id in talent_definition.effect_ids:
			if effect_id == &"":
				continue

			if seen_effect_ids.has(effect_id):
				continue

			seen_effect_ids[effect_id] = true
			active_effect_ids.append(effect_id)

	return active_effect_ids


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
	if not is_instance_valid(branch_progress_service):
		return false

	return branch_progress_service.purchase_talent(
		self,
		talent_id
	)


func on_talent_purchased(
	_talent_id: StringName
) -> void:
	pass


func get_talent_definition(
	talent_id: StringName
) -> TalentDefinition:
	if not is_instance_valid(
		talent_tree_definition
	):
		return null

	return talent_tree_definition.get_talent_by_id(
		talent_id
	)


func get_talent_ids() -> Array[StringName]:
	if not is_instance_valid(
		talent_tree_definition
	):
		return []

	return talent_tree_definition.get_talent_ids()


func get_talent_display_name(
	talent_id: StringName
) -> String:
	var talent_definition: TalentDefinition = (
		get_talent_definition(talent_id)
	)

	if not is_instance_valid(talent_definition):
		return "Unknown Talent"

	return talent_definition.display_name


func get_talent_description(
	talent_id: StringName
) -> String:
	var talent_definition: TalentDefinition = (
		get_talent_definition(talent_id)
	)

	if not is_instance_valid(talent_definition):
		return ""

	return talent_definition.description


func get_talent_branch_name(
	talent_id: StringName
) -> String:
	var talent_definition: TalentDefinition = (
		get_talent_definition(talent_id)
	)

	if not is_instance_valid(talent_definition):
		return ""

	return talent_definition.path_name


func get_talent_required_level(
	talent_id: StringName
) -> int:
	var talent_definition: TalentDefinition = (
		get_talent_definition(talent_id)
	)

	if not is_instance_valid(talent_definition):
		return 1

	return talent_definition.required_branch_level


func get_talent_cost(
	talent_id: StringName
) -> int:
	var talent_definition: TalentDefinition = (
		get_talent_definition(talent_id)
	)

	if not is_instance_valid(talent_definition):
		return 1

	return talent_definition.talent_point_cost


func get_talent_prerequisites(
	talent_id: StringName
) -> Array[StringName]:
	var talent_definition: TalentDefinition = (
		get_talent_definition(talent_id)
	)

	if not is_instance_valid(talent_definition):
		return []

	return talent_definition.prerequisite_ids


func get_talent_conflicts(
	talent_id: StringName
) -> Array[StringName]:
	var talent_definition: TalentDefinition = (
		get_talent_definition(talent_id)
	)

	if not is_instance_valid(talent_definition):
		return []

	return talent_definition.conflicting_ids


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
	if not is_slot_assignment_valid():
		combat_enabled = false
		warn_invalid_slot_assignment_once()
		return

	combat_enabled = true


# -------------------------------------------------------------------
# General branch UI interface
# -------------------------------------------------------------------


func get_branch_display_name() -> String:
	return branch_display_name


func get_branch_side_name() -> String:
	if BranchSlotRules.is_apex_slot(slot_index):
		return "Apex"

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


func get_upgrade_definition(
	upgrade_id: StringName
) -> UpgradeDefinition:
	if not is_instance_valid(branch_definition):
		return null

	return branch_definition.get_upgrade_by_id(
		upgrade_id
	)


func get_upgrade_value_per_level(
	upgrade_id: StringName
) -> float:
	var upgrade_definition: UpgradeDefinition = (
		get_upgrade_definition(upgrade_id)
	)

	if not is_instance_valid(upgrade_definition):
		return 0.0

	return upgrade_definition.value_per_level


func can_purchase_upgrade_by_id(
	upgrade_id: StringName
) -> bool:
	if not is_instance_valid(
		get_upgrade_definition(upgrade_id)
	):
		return false

	return (
		get_upgrade_level(upgrade_id)
		< get_upgrade_maximum_level(upgrade_id)
	)


func get_upgrade_ids() -> Array[StringName]:
	if not is_instance_valid(branch_definition):
		return []

	return branch_definition.get_upgrade_ids()


func get_upgrade_display_name(
	upgrade_id: StringName
) -> String:
	var upgrade_definition: UpgradeDefinition = (
		get_upgrade_definition(upgrade_id)
	)

	if not is_instance_valid(upgrade_definition):
		return "Unknown Upgrade"

	return upgrade_definition.display_name


func get_upgrade_level(
	_upgrade_id: StringName
) -> int:
	if not is_instance_valid(branch_progress_service):
		return 0

	var progress: BranchProgressRecord = (
		branch_progress_service.get_progress(branch_id)
	)

	if progress == null:
		return 0

	return progress.get_upgrade_level(_upgrade_id)


func get_upgrade_maximum_level(
	upgrade_id: StringName
) -> int:
	var upgrade_definition: UpgradeDefinition = (
		get_upgrade_definition(upgrade_id)
	)

	if not is_instance_valid(upgrade_definition):
		return 0

	var branch_maximum: int = (
		get_maximum_essence_upgrade_level()
	)

	if upgrade_definition.maximum_level <= 0:
		return branch_maximum

	return min(
		branch_maximum,
		upgrade_definition.maximum_level
	)


func get_upgrade_cost_by_id(
	upgrade_id: StringName
) -> int:
	var upgrade_definition: UpgradeDefinition = (
		get_upgrade_definition(upgrade_id)
	)

	if not is_instance_valid(upgrade_definition):
		return 0

	return upgrade_definition.get_cost_for_level(
		get_upgrade_level(upgrade_id)
	)


func get_upgrade_current_value_text(
	_upgrade_id: StringName
) -> String:
	return ""


func get_upgrade_next_value_text(
	_upgrade_id: StringName
) -> String:
	return ""


func purchase_upgrade(
	upgrade_id: StringName
) -> bool:
	if not is_instance_valid(branch_progress_service):
		return false

	return branch_progress_service.purchase_upgrade(
		self,
		upgrade_id
	)


func can_apply_progress_upgrade(
	upgrade_id: StringName,
	current_level: int
) -> bool:
	if not is_instance_valid(get_upgrade_definition(upgrade_id)):
		return false

	return current_level < get_upgrade_maximum_level(upgrade_id)


func get_progress_upgrade_levels() -> Dictionary:
	return {}


func apply_progress_upgrade_levels(
	_upgrade_levels: Dictionary
) -> void:
	pass


func on_shared_progress_applied() -> void:
	on_branch_level_changed()
	on_talent_purchased(&"")


func apply_shared_progress(
	progress: BranchProgressRecord
) -> void:
	if progress == null or progress.branch_id != branch_id:
		return

	branch_level = progress.branch_level
	current_xp = progress.current_xp
	available_talent_points = progress.available_talent_points
	total_talent_points_earned = progress.total_talent_points_earned
	purchased_talents = progress.purchased_talents.duplicate(true)

	apply_progress_upgrade_levels(
		progress.upgrade_levels.duplicate(true)
	)
	on_shared_progress_applied()
