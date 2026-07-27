extends Label


var tree_node: Node


func _ready() -> void:
	tree_node = get_tree().get_first_node_in_group("tree")

	if tree_node == null:
		text = "Age: ?"
		return

	tree_node.age_changed.connect(_on_age_changed)
	_on_age_changed(tree_node.age)


func _on_age_changed(new_age: int) -> void:
	text = "Age: %d" % new_age
