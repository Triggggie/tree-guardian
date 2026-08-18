extends Panel


signal retry_requested


@export_category("Respawn")
@export_range(0.1, 5.0, 0.1)
var automatic_retry_delay: float = 1.5


@onready var vbox_container: VBoxContainer = (
	$VBoxContainer
)

@onready var game_over_label: Label = (
	$VBoxContainer/GameOverLabel
)

@onready var restart_button: Button = (
	$VBoxContainer/RestartButton
)


var tree_node: Node
var automatic_retry_timer: Timer
var retry_already_requested: bool = false


func _ready() -> void:
	vbox_container.position = Vector2(
		110.0,
		100.0
	)

	vbox_container.custom_minimum_size = Vector2(
		400.0,
		180.0
	)

	vbox_container.visible = true

	game_over_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	game_over_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	game_over_label.custom_minimum_size = Vector2(
		400.0,
		90.0
	)

	game_over_label.visible = true

	restart_button.visible = false
	restart_button.disabled = true

	automatic_retry_timer = Timer.new()
	automatic_retry_timer.name = "AutomaticRetryTimer"
	automatic_retry_timer.one_shot = true
	automatic_retry_timer.timeout.connect(request_retry)
	add_child(automatic_retry_timer)

	tree_node = (
		get_tree().get_first_node_in_group("tree")
	)

	if (
		is_instance_valid(tree_node)
		and tree_node.has_signal("died")
	):
		tree_node.died.connect(
			_on_tree_died
		)

	hide()


func _on_tree_died() -> void:
	retry_already_requested = false

	show()
	game_over_label.text = (
		"TREE DEFEATED\n"
		+ "The Tree will awaken..."
	)
	if is_instance_valid(automatic_retry_timer):
		automatic_retry_timer.start(max(automatic_retry_delay, 0.1))


func request_retry() -> void:
	if retry_already_requested:
		return

	retry_already_requested = true
	if is_instance_valid(automatic_retry_timer):
		automatic_retry_timer.stop()

	game_over_label.text = (
		"THE TREE AWAKENS..."
	)

	hide()

	retry_requested.emit()
