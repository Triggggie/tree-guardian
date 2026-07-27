extends Label


var tree_node: Node


func _ready() -> void:
	tree_node = get_tree().get_first_node_in_group("tree")

	if tree_node == null:
		text = "Tree HP: ?"
		return

	tree_node.health_changed.connect(
		_on_health_changed
	)

	tree_node.died.connect(
		_on_tree_died
	)

	_on_health_changed(
		tree_node.current_health,
		tree_node.max_health
	)


func _on_health_changed(
	current_health: float,
	maximum_health: float
) -> void:
	text = (
		"Tree HP: %.0f / %.0f"
		% [
			current_health,
			maximum_health
		]
	)


func _on_tree_died() -> void:
	text += "\nTREE DEAD"
