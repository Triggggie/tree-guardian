extends Node


signal wave_changed(
	new_wave: int,
	enemies_per_side: int
)

signal wave_message_changed(
	message: String
)


@onready var game_over_panel: Panel = (
	$"../UI/GameOverPanel"
)


var tree_node: Node2D
var wave_director: WaveDirector
var tree_defeated: bool = false

var current_wave: int:
	get:
		if not is_instance_valid(wave_director):
			return 0

		return wave_director.get_current_wave()


func _ready() -> void:
	add_to_group("wave_manager")

	wave_director = (
		get_tree().get_first_node_in_group(
			"wave_director"
		)
		as WaveDirector
	)

	tree_node = (
		get_tree().get_first_node_in_group("tree")
		as Node2D
	)

	if (
		is_instance_valid(tree_node)
		and tree_node.has_signal("died")
	):
		tree_node.died.connect(
			_on_tree_died
		)

	if (
		is_instance_valid(game_over_panel)
		and game_over_panel.has_signal(
			"retry_requested"
		)
	):
		game_over_panel.retry_requested.connect(
			_on_retry_requested
		)

	if not is_instance_valid(wave_director):
		push_error(
			"WaveManager could not find WaveDirector; "
			+ "wave cycle will not start."
		)
		return

	wave_director.wave_changed.connect(
		_on_director_wave_changed
	)
	wave_director.wave_message_changed.connect(
		_on_director_wave_message_changed
	)
	wave_director.new_highest_wave_completed.connect(
		_on_new_highest_wave_completed
	)

	if not wave_director.is_ready_to_run():
		return

	start_wave_cycle(false)


func _exit_tree() -> void:
	if not is_instance_valid(wave_director):
		return

	wave_director.cancel_cycle(false)


func start_wave_cycle(
	retry_current_wave: bool
) -> void:
	if not is_instance_valid(wave_director):
		push_error(
			"WaveManager cannot start a cycle without WaveDirector."
		)
		return

	wave_director.start_cycle(
		retry_current_wave
	)


func get_current_enemies_per_side() -> int:
	if not is_instance_valid(wave_director):
		return 0

	return wave_director.get_current_enemies_per_side()


func _on_director_wave_changed(
	new_wave: int,
	enemies_per_side: int
) -> void:
	wave_changed.emit(
		new_wave,
		enemies_per_side
	)


func _on_director_wave_message_changed(
	message: String
) -> void:
	wave_message_changed.emit(message)


func _on_new_highest_wave_completed(
	_global_wave: int
) -> void:
	if (
		is_instance_valid(tree_node)
		and tree_node.has_method("add_age")
	):
		tree_node.add_age(1)


func _on_tree_died() -> void:
	if tree_defeated:
		return

	tree_defeated = true

	if is_instance_valid(wave_director):
		wave_director.cancel_cycle(true)

	get_tree().call_group(
		"combat_branch",
		"stop_combat"
	)

	get_tree().call_group(
		"enemies",
		"stop_combat"
	)

	remove_remaining_enemies()

	var current_stage: int = 1
	var current_wave_in_stage: int = 1

	if is_instance_valid(wave_director):
		current_stage = (
			wave_director.get_current_stage_number()
		)
		current_wave_in_stage = (
			wave_director.get_current_wave_in_stage()
		)

	print(
		"Strom zemřel ve Stage ",
		current_stage,
		" | Wave ",
		current_wave_in_stage,
		" – po oživení začne Stage znovu"
	)


func remove_remaining_enemies() -> void:
	var enemies: Array[Node] = (
		get_tree().get_nodes_in_group("enemies")
	)

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		enemy.remove_from_group("enemies")
		enemy.queue_free()


func _on_retry_requested() -> void:
	if not tree_defeated:
		return

	if not is_instance_valid(wave_director):
		push_error(
			"WaveManager cannot retry without WaveDirector."
		)
		return

	var failed_stage: int = (
		wave_director.get_current_stage_number()
	)
	var failed_wave_in_stage: int = (
		wave_director.get_current_wave_in_stage()
	)

	remove_remaining_enemies()

	if (
		is_instance_valid(tree_node)
		and tree_node.has_method("revive")
	):
		tree_node.revive()

	get_tree().call_group(
		"combat_branch",
		"resume_combat"
	)

	tree_defeated = false

	print(
		"Strom byl oživen | selhání ve Stage ",
		failed_stage,
		" | Wave ",
		failed_wave_in_stage,
		" | Stage ",
		failed_stage,
		" začíná znovu od Wave 1"
	)

	var restarted: bool = (
		wave_director.restart_current_stage()
	)

	if restarted:
		return

	tree_defeated = true
	push_error(
		"WaveManager could not restart the current Stage."
	)
