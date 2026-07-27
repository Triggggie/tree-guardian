extends Panel


@onready var vbox_container: VBoxContainer = $VBoxContainer
@onready var game_over_label: Label = (
	$VBoxContainer/GameOverLabel
)
@onready var restart_button: Button = (
	$VBoxContainer/RestartButton
)

var tree_node: Node


func _ready() -> void:
	# Pevné rozložení obsahu uvnitř panelu.
	vbox_container.position = Vector2(110.0, 120.0)
	vbox_container.size = Vector2(400.0, 140.0)
	vbox_container.visible = true

	game_over_label.text = "TREE DEAD"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.custom_minimum_size = Vector2(400.0, 50.0)
	game_over_label.visible = true

	restart_button.text = "Restart"
	restart_button.custom_minimum_size = Vector2(400.0, 60.0)
	restart_button.visible = true

	restart_button.pressed.connect(
		_on_restart_button_pressed
	)

	tree_node = get_tree().get_first_node_in_group("tree")

	if (
		is_instance_valid(tree_node)
		and tree_node.has_signal("died")
	):
		tree_node.died.connect(_on_tree_died)

	hide()


func _on_tree_died() -> void:
	show()
	restart_button.grab_focus()


func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()
