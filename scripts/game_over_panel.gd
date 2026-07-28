extends Panel


signal retry_requested


@export_category("Respawn")
@export_range(1, 60, 1)
var automatic_respawn_seconds: int = 10


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
var countdown_id: int = 0
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

	restart_button.text = "RETRY NOW"

	restart_button.custom_minimum_size = Vector2(
		400.0,
		60.0
	)

	restart_button.visible = true

	restart_button.pressed.connect(
		_on_restart_button_pressed
	)

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
	countdown_id += 1

	var active_countdown_id: int = (
		countdown_id
	)

	show()
	restart_button.grab_focus()

	run_respawn_countdown(
		active_countdown_id
	)


func run_respawn_countdown(
	active_countdown_id: int
) -> void:
	for seconds_left in range(
		automatic_respawn_seconds,
		0,
		-1
	):
		if active_countdown_id != countdown_id:
			return

		if retry_already_requested:
			return

		game_over_label.text = (
			"TREE DEFEATED\n"
			+ "Respawning in %d s"
			% seconds_left
		)

		await get_tree().create_timer(
			1.0
		).timeout

	if active_countdown_id != countdown_id:
		return

	request_retry()


func _on_restart_button_pressed() -> void:
	request_retry()


func request_retry() -> void:
	if retry_already_requested:
		return

	retry_already_requested = true
	countdown_id += 1

	restart_button.disabled = true

	game_over_label.text = (
		"THE TREE AWAKENS..."
	)

	hide()

	retry_requested.emit()

	# Připraví tlačítko pro případ další smrti.
	restart_button.disabled = false
