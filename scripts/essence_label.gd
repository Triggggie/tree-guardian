extends Label


var tree_node: Node


func _ready() -> void:
	tree_node = get_tree().get_first_node_in_group("tree")

	if tree_node == null:
		return

	tree_node.forest_essence_changed.connect(
		_on_forest_essence_changed
	)

	_on_forest_essence_changed(tree_node.forest_essence)


func _on_forest_essence_changed(new_amount: int) -> void:
	text = "Forest Essence: %d" % new_amount
