extends ProgressBar


var tree_node: Node


func _ready() -> void:
	tree_node = get_tree().get_first_node_in_group("tree")

	if tree_node == null:
		value = 0.0
		return

	tree_node.health_changed.connect(
		_on_health_changed
	)

	_on_health_changed(
		tree_node.current_health,
		tree_node.max_health
	)


func _on_health_changed(
	current_health: float,
	maximum_health: float
) -> void:
	min_value = 0.0
	max_value = maximum_health
	value = current_health
