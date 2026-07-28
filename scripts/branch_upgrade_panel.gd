extends Panel


@onready var branch_name_label: Label = (
	$VBoxContainer/BranchNameLabel
)

@onready var branch_stats_label: Label = (
	$VBoxContainer/BranchStatsLabel
)

@onready var branch_select_button: Button = (
	$VBoxContainer/BranchSelectButton
)

@onready var damage_button: Button = (
	$VBoxContainer/DamageButton
)

@onready var attack_speed_button: Button = (
	$VBoxContainer/AttackSpeedButton
)

@onready var range_button: Button = (
	$VBoxContainer/RangeButton
)


var tree_node: Node
var available_branches: Array[Node] = []

var selected_branch_index: int = 0
var selected_branch: Node


func _ready() -> void:
	tree_node = (
		get_tree().get_first_node_in_group("tree")
	)

	branch_select_button.pressed.connect(
		_on_branch_select_button_pressed
	)

	damage_button.pressed.connect(
		_on_damage_button_pressed
	)

	attack_speed_button.pressed.connect(
		_on_attack_speed_button_pressed
	)

	range_button.pressed.connect(
		_on_range_button_pressed
	)

	if (
		is_instance_valid(tree_node)
		and tree_node.has_signal(
			"forest_essence_changed"
		)
	):
		tree_node.forest_essence_changed.connect(
			_on_forest_essence_changed
		)

	find_available_branches()
	select_branch(0)


func find_available_branches() -> void:
	available_branches.clear()

	var found_branches: Array[Node] = (
		get_tree().get_nodes_in_group(
			"strength_branch"
		)
	)

	for branch in found_branches:
		if not is_instance_valid(branch):
			continue

		available_branches.append(branch)

	available_branches.sort_custom(
		func(
			first_branch: Node,
			second_branch: Node
		) -> bool:
			if (
				first_branch is Node2D
				and second_branch is Node2D
			):
				return (
					first_branch.global_position.x
					< second_branch.global_position.x
				)

			return false
	)


func select_branch(branch_index: int) -> void:
	if available_branches.is_empty():
		selected_branch = null
		update_panel()
		return

	selected_branch_index = wrapi(
		branch_index,
		0,
		available_branches.size()
	)

	selected_branch = (
		available_branches[
			selected_branch_index
		]
	)

	connect_selected_branch_signals()
	update_panel()


func connect_selected_branch_signals() -> void:
	if not is_instance_valid(selected_branch):
		return

	if selected_branch.has_signal("level_changed"):
		var level_callable := Callable(
			self,
			"_on_branch_level_changed"
		)

		if not selected_branch.level_changed.is_connected(
			level_callable
		):
			selected_branch.level_changed.connect(
				level_callable
			)

	if selected_branch.has_signal("upgrade_changed"):
		var upgrade_callable := Callable(
			self,
			"_on_branch_upgrade_changed"
		)

		if not selected_branch.upgrade_changed.is_connected(
			upgrade_callable
		):
			selected_branch.upgrade_changed.connect(
				upgrade_callable
			)

func update_panel() -> void:
	if not is_instance_valid(selected_branch):
		branch_name_label.text = "NO BRANCH"
		branch_stats_label.text = ""

		branch_select_button.disabled = true
		damage_button.disabled = true
		attack_speed_button.disabled = true
		range_button.disabled = true
		return

	branch_select_button.disabled = (
		available_branches.size() <= 1
	)

	var branch_side: String = get_branch_side_name()

	branch_name_label.text = (
		"%s STRENGTH BRANCH"
		% branch_side
	)

	branch_select_button.text = (
		"SELECT NEXT BRANCH"
	)

	var essence_amount: int = get_current_essence()

	var damage: float = (
		selected_branch.get_current_damage()
	)

	var cooldown: float = (
		selected_branch.get_current_attack_cooldown()
	)

	var attack_speed: float = 0.0

	if cooldown > 0.0:
		attack_speed = 1.0 / cooldown

	var attack_range: float = (
		selected_branch.get_current_attack_range()
	)

	branch_stats_label.text = (
		"Forest Essence: %d\n"
		+ "Branch Level: %d\n"
		+ "Damage: %.1f\n"
		+ "Attack Speed: %.2f /s\n"
		+ "Range: %.1f"
	) % [
		essence_amount,
		selected_branch.branch_level,
		damage,
		attack_speed,
		attack_range
	]

	update_damage_button(essence_amount)
	update_attack_speed_button(essence_amount)
	update_range_button(essence_amount)

func get_branch_side_name() -> String:
	if not is_instance_valid(selected_branch):
		return ""

	if selected_branch.facing_side == 0:
		return "LEFT"

	return "RIGHT"


func get_current_essence() -> int:
	if not is_instance_valid(tree_node):
		return 0

	if tree_node.has_method("get_forest_essence"):
		return tree_node.get_forest_essence()

	return 0


func update_damage_button(
	essence_amount: int
) -> void:
	var current_level: int = (
		selected_branch.damage_upgrade_level
	)

	var maximum_level: int = (
		selected_branch
		.get_maximum_essence_upgrade_level()
	)

	if current_level >= maximum_level:
		damage_button.text = (
			"DAMAGE Lv.%d — MAX"
			% current_level
		)

		damage_button.disabled = true
		return

	var cost: int = (
		selected_branch.get_damage_upgrade_cost()
	)

	damage_button.text = (
		"DAMAGE Lv.%d → %d Essence"
		% [
			current_level,
			cost
		]
	)

	damage_button.disabled = (
		essence_amount < cost
	)

func update_attack_speed_button(
	essence_amount: int
) -> void:
	var current_level: int = (
		selected_branch.attack_speed_upgrade_level
	)

	var maximum_level: int = (
		selected_branch
		.get_maximum_essence_upgrade_level()
	)

	if current_level >= maximum_level:
		attack_speed_button.text = (
			"ATTACK SPEED Lv.%d — MAX"
			% current_level
		)

		attack_speed_button.disabled = true
		return

	var cost: int = (
		selected_branch
		.get_attack_speed_upgrade_cost()
	)

	var current_cooldown: float = (
		selected_branch.get_current_attack_cooldown()
	)

	var next_cooldown: float = max(
		selected_branch.base_attack_cooldown
		- (current_level + 1)
		* selected_branch.cooldown_reduction_per_upgrade,
		selected_branch.minimum_attack_cooldown
	)

	var current_attack_speed: float = 0.0
	var next_attack_speed: float = 0.0

	if current_cooldown > 0.0:
		current_attack_speed = (
			1.0 / current_cooldown
		)

	if next_cooldown > 0.0:
		next_attack_speed = (
			1.0 / next_cooldown
		)

	attack_speed_button.text = (
		"ATTACK SPEED Lv.%d | %.2f → %.2f /s | %d Essence"
		% [
			current_level,
			current_attack_speed,
			next_attack_speed,
			cost
		]
	)

	attack_speed_button.disabled = (
		essence_amount < cost
	)
	
func update_range_button(
	essence_amount: int
) -> void:
	var current_level: int = (
		selected_branch.range_upgrade_level
	)

	var maximum_level: int = min(
		selected_branch
		.get_maximum_essence_upgrade_level(),
		selected_branch
		.get_maximum_range_upgrade_level()
	)

	if current_level >= maximum_level:
		range_button.text = (
			"RANGE Lv.%d — MAX"
			% current_level
		)

		range_button.disabled = true
		return

	var cost: int = (
		selected_branch.get_range_upgrade_cost()
	)

	var current_range: float = (
		selected_branch.get_current_attack_range()
	)

	var next_range_bonus: float = min(
		(current_level + 1)
		* selected_branch.range_per_upgrade,
		selected_branch.maximum_range_bonus
	)

	var next_range: float = (
		selected_branch.get_current_length()
		+ selected_branch.base_range_padding
		+ next_range_bonus
	)

	range_button.text = (
		"RANGE Lv.%d | %.0f → %.0f | %d Essence"
		% [
			current_level,
			current_range,
			next_range,
			cost
		]
	)

	range_button.disabled = (
		essence_amount < cost
	)

func _on_branch_select_button_pressed() -> void:
	select_branch(
		selected_branch_index + 1
	)


func _on_damage_button_pressed() -> void:
	if not is_instance_valid(selected_branch):
		return

	selected_branch.purchase_damage_upgrade()
	update_panel()


func _on_attack_speed_button_pressed() -> void:
	if not is_instance_valid(selected_branch):
		return

	selected_branch.purchase_attack_speed_upgrade()
	update_panel()


func _on_range_button_pressed() -> void:
	if not is_instance_valid(selected_branch):
		return

	selected_branch.purchase_range_upgrade()
	update_panel()


func _on_forest_essence_changed(
	_new_amount: int
) -> void:
	update_panel()


func _on_branch_level_changed(
	_new_level: int
) -> void:
	update_panel()


func _on_branch_upgrade_changed(
	_upgrade_id: StringName,
	_new_level: int
) -> void:
	update_panel()
