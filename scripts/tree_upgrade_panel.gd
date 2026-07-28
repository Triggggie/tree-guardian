extends Panel


@onready var title_label: Label = (
	$VBoxContainer/TitleLabel
)

@onready var tree_stats_label: Label = (
	$VBoxContainer/TreeStatsLabel
)

@onready var max_health_button: Button = (
	$VBoxContainer/MaxHealthButton
)

@onready var health_regen_button: Button = (
	$VBoxContainer/HealthRegenButton
)

@onready var essence_gain_button: Button = (
	$VBoxContainer/EssenceGainButton
)


var tree_node: Node


func _ready() -> void:
	tree_node = (
		get_tree().get_first_node_in_group("tree")
	)

	title_label.text = "TREE UPGRADES"

	max_health_button.pressed.connect(
		_on_max_health_button_pressed
	)

	health_regen_button.pressed.connect(
		_on_health_regen_button_pressed
	)

	essence_gain_button.pressed.connect(
		_on_essence_gain_button_pressed
	)

	connect_tree_signals()
	update_panel()


func connect_tree_signals() -> void:
	if not is_instance_valid(tree_node):
		return

	if tree_node.has_signal(
		"forest_essence_changed"
	):
		tree_node.forest_essence_changed.connect(
			_on_forest_essence_changed
		)

	if tree_node.has_signal(
		"health_changed"
	):
		tree_node.health_changed.connect(
			_on_health_changed
		)

	if tree_node.has_signal(
		"age_changed"
	):
		tree_node.age_changed.connect(
			_on_age_changed
		)

	if tree_node.has_signal(
		"tree_upgrade_changed"
	):
		tree_node.tree_upgrade_changed.connect(
			_on_tree_upgrade_changed
		)


func update_panel() -> void:
	if not is_instance_valid(tree_node):
		title_label.text = "TREE NOT FOUND"
		tree_stats_label.text = ""

		max_health_button.disabled = true
		health_regen_button.disabled = true
		essence_gain_button.disabled = true

		return

	title_label.text = "TREE UPGRADES"

	var essence_amount: int = 0

	if tree_node.has_method(
		"get_forest_essence"
	):
		essence_amount = (
			tree_node.get_forest_essence()
		)

	var health_regeneration: float = 0.0

	if tree_node.has_method(
		"get_current_health_regeneration"
	):
		health_regeneration = (
			tree_node
			.get_current_health_regeneration()
		)

	var essence_multiplier: float = 1.0

	if tree_node.has_method(
		"get_current_essence_multiplier"
	):
		essence_multiplier = (
			tree_node
			.get_current_essence_multiplier()
		)

	tree_stats_label.text = (
		"Age: %d\n"
		+ "Forest Essence: %d\n"
		+ "HP: %.1f / %.1f\n"
		+ "HP Regen: %.2f /s\n"
		+ "Essence Gain: +%.0f%%"
	) % [
		tree_node.age,
		essence_amount,
		tree_node.current_health,
		tree_node.max_health,
		health_regeneration,
		(essence_multiplier - 1.0) * 100.0
	]

	update_max_health_button(
		essence_amount
	)

	update_health_regen_button(
		essence_amount
	)

	update_essence_gain_button(
		essence_amount
	)


func update_max_health_button(
	essence_amount: int
) -> void:
	var current_level: int = (
		tree_node.max_health_upgrade_level
	)

	var maximum_level: int = (
		tree_node.get_maximum_tree_upgrade_level()
	)

	if current_level >= maximum_level:
		max_health_button.text = (
			"MAX HP Lv.%d — MAX"
			% current_level
		)

		max_health_button.disabled = true
		return

	var cost: int = (
		tree_node.get_max_health_upgrade_cost()
	)

	var next_max_health: float = (
		tree_node.max_health
		+ tree_node.max_health_per_upgrade
	)

	max_health_button.text = (
		"MAX HP Lv.%d | %.0f → %.0f | %d Essence"
		% [
			current_level,
			tree_node.max_health,
			next_max_health,
			cost
		]
	)

	max_health_button.disabled = (
		essence_amount < cost
	)


func update_health_regen_button(
	essence_amount: int
) -> void:
	var current_level: int = (
		tree_node.health_regeneration_upgrade_level
	)

	var maximum_level: int = (
		tree_node.get_maximum_tree_upgrade_level()
	)

	if current_level >= maximum_level:
		health_regen_button.text = (
			"HP REGEN Lv.%d — MAX"
			% current_level
		)

		health_regen_button.disabled = true
		return

	var cost: int = (
		tree_node
		.get_health_regeneration_upgrade_cost()
	)

	var current_regeneration: float = (
		tree_node.get_current_health_regeneration()
	)

	var next_regeneration: float = (
		current_regeneration
		+ tree_node.health_regeneration_per_upgrade
	)

	health_regen_button.text = (
		"HP REGEN Lv.%d | %.2f → %.2f/s | %d Essence"
		% [
			current_level,
			current_regeneration,
			next_regeneration,
			cost
		]
	)

	health_regen_button.disabled = (
		essence_amount < cost
	)


func update_essence_gain_button(
	essence_amount: int
) -> void:
	var current_level: int = (
		tree_node.essence_gain_upgrade_level
	)

	var maximum_level: int = (
		tree_node.get_maximum_tree_upgrade_level()
	)

	if current_level >= maximum_level:
		essence_gain_button.text = (
			"ESSENCE GAIN Lv.%d — MAX"
			% current_level
		)

		essence_gain_button.disabled = true
		return

	var cost: int = (
		tree_node.get_essence_gain_upgrade_cost()
	)

	var current_bonus: float = (
		(
			tree_node.get_current_essence_multiplier()
			- 1.0
		)
		* 100.0
	)

	var next_bonus: float = (
		current_bonus
		+ tree_node.essence_gain_per_upgrade
		* 100.0
	)

	essence_gain_button.text = (
		"ESSENCE Lv.%d | +%.0f%% → +%.0f%% | %d Essence"
		% [
			current_level,
			current_bonus,
			next_bonus,
			cost
		]
	)

	essence_gain_button.disabled = (
		essence_amount < cost
	)


func _on_max_health_button_pressed() -> void:
	if not is_instance_valid(tree_node):
		return

	if tree_node.has_method(
		"purchase_max_health_upgrade"
	):
		tree_node.purchase_max_health_upgrade()

	update_panel()


func _on_health_regen_button_pressed() -> void:
	if not is_instance_valid(tree_node):
		return

	if tree_node.has_method(
		"purchase_health_regeneration_upgrade"
	):
		tree_node.purchase_health_regeneration_upgrade()

	update_panel()


func _on_essence_gain_button_pressed() -> void:
	if not is_instance_valid(tree_node):
		return

	if tree_node.has_method(
		"purchase_essence_gain_upgrade"
	):
		tree_node.purchase_essence_gain_upgrade()

	update_panel()


func _on_forest_essence_changed(
	_new_amount: int
) -> void:
	update_panel()


func _on_health_changed(
	_current_health: float,
	_maximum_health: float
) -> void:
	update_panel()


func _on_age_changed(
	_new_age: int
) -> void:
	update_panel()


func _on_tree_upgrade_changed(
	_upgrade_id: StringName,
	_new_level: int
) -> void:
	update_panel()
