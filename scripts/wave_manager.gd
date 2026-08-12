extends Node


signal wave_changed(
	new_wave: int,
	enemies_per_side: int
)

signal wave_message_changed(
	message: String
)

signal preparation_state_changed(
	is_active: bool,
	reason: StringName
)


const PREPARATION_REASON_NONE: StringName = &""
const PREPARATION_REASON_INITIAL: StringName = &"initial"
const PREPARATION_REASON_SUBSTAGE_COMPLETE: StringName = &"substage_complete"
const PREPARATION_REASON_RETRY: StringName = &"retry"


@onready var game_over_panel: Panel = (
	$"../UI/GameOverPanel"
)


var tree_node: Node2D
var wave_director: WaveDirector
var branch_loadout_controller: TreeBranchLoadoutController
var tree_defeated: bool = false
var preparation_active: bool = false
var preparation_reason: StringName = PREPARATION_REASON_NONE

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
	wave_director.substage_checkpoint_reached.connect(
		_on_substage_checkpoint_reached
	)

	branch_loadout_controller = get_tree().get_first_node_in_group(
		"branch_loadout_controller"
	) as TreeBranchLoadoutController
	if (
		is_instance_valid(branch_loadout_controller)
		and not branch_loadout_controller.runtime_standard_slot_changed.is_connected(
			_on_runtime_standard_slot_changed
		)
	):
		branch_loadout_controller.runtime_standard_slot_changed.connect(
			_on_runtime_standard_slot_changed
		)
	if (
		is_instance_valid(branch_loadout_controller)
		and not branch_loadout_controller.runtime_apex_slot_changed.is_connected(
			_on_runtime_apex_slot_changed
		)
	):
		branch_loadout_controller.runtime_apex_slot_changed.connect(
			_on_runtime_apex_slot_changed
		)

	if not wave_director.is_ready_to_run():
		return

	_enter_preparation(PREPARATION_REASON_INITIAL)


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


func is_preparation_active() -> bool:
	return preparation_active


func get_preparation_reason() -> StringName:
	return preparation_reason


func is_standard_loadout_edit_allowed() -> bool:
	return is_branch_loadout_edit_allowed()


func is_branch_loadout_edit_allowed() -> bool:
	return is_instance_valid(tree_node) and not tree_defeated


func continue_from_preparation() -> bool:
	if not preparation_active or tree_defeated:
		return false
	if not is_instance_valid(wave_director):
		return false

	var previous_reason: StringName = preparation_reason
	_exit_preparation()
	if wave_director.start_cycle(false):
		return true

	_enter_preparation(previous_reason)
	return false


func get_current_enemies_per_side() -> int:
	if not is_instance_valid(wave_director):
		return 0

	return wave_director.get_current_enemies_per_side()


func get_current_stage_number() -> int:
	if not is_instance_valid(wave_director):
		return 1

	return wave_director.get_current_stage_number()


func get_current_substage_number() -> int:
	if not is_instance_valid(wave_director):
		return 1

	return wave_director.get_current_substage_number()


func get_current_wave_in_substage() -> int:
	if not is_instance_valid(wave_director):
		return 1

	return wave_director.get_current_wave_in_substage()


func get_substages_per_stage() -> int:
	if not is_instance_valid(wave_director):
		return 10

	return wave_director.get_safe_substages_per_stage()


func get_waves_per_substage() -> int:
	if not is_instance_valid(wave_director):
		return 100

	return wave_director.get_safe_waves_per_substage()


func get_current_progress_code() -> String:
	if not is_instance_valid(wave_director):
		return "1-1-1"

	return wave_director.get_current_progress_code()


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


func _on_substage_checkpoint_reached(
	_completed_global_wave: int
) -> void:
	_enter_preparation(PREPARATION_REASON_SUBSTAGE_COMPLETE)


func _on_tree_died() -> void:
	if tree_defeated:
		return

	var failed_progress_code: String = (
		get_current_progress_code()
	)
	var failed_stage: int = get_current_stage_number()
	var failed_substage: int = (
		get_current_substage_number()
	)

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

	print(
		"Strom zemřel v ",
		failed_progress_code,
		" – po oživení začne Substage ",
		failed_stage,
		"-",
		failed_substage,
		" znovu od Wave 1"
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

	var failed_progress_code: String = (
		wave_director.get_current_progress_code()
	)
	var failed_stage: int = (
		wave_director.get_current_stage_number()
	)
	var failed_substage: int = (
		wave_director.get_current_substage_number()
	)
	var failed_wave: int = (
		wave_director.get_current_wave_in_substage()
	)

	remove_remaining_enemies()

	if (
		is_instance_valid(tree_node)
		and tree_node.has_method("revive")
	):
		tree_node.revive()

	tree_defeated = false

	print(
		"Strom byl oživen | selhání v ",
		failed_progress_code,
		" (Wave ",
		failed_wave,
		") | pokračování od ",
		failed_stage,
		"-",
		failed_substage,
		"-1"
	)

	var restart_prepared: bool = (
		wave_director.prepare_current_substage_restart()
	)

	if restart_prepared:
		_enter_preparation(PREPARATION_REASON_RETRY)
		return

	tree_defeated = true
	push_error(
		"WaveManager could not restart the current Substage."
	)


func _enter_preparation(reason: StringName) -> void:
	if reason == PREPARATION_REASON_NONE:
		return

	if is_instance_valid(wave_director):
		wave_director.cancel_cycle(true)
	remove_remaining_enemies()
	get_tree().call_group("combat_branch", "stop_combat")
	preparation_active = true
	preparation_reason = reason
	preparation_state_changed.emit(true, reason)


func _exit_preparation() -> void:
	preparation_active = false
	preparation_reason = PREPARATION_REASON_NONE
	preparation_state_changed.emit(false, PREPARATION_REASON_NONE)
	get_tree().call_group("combat_branch", "resume_combat")


func _on_runtime_standard_slot_changed(
	slot_id: StringName,
	_branch_id: StringName
) -> void:
	if not preparation_active or not is_instance_valid(branch_loadout_controller):
		return
	var runtime_branch: CombatBranch = (
		branch_loadout_controller.get_runtime_branch(slot_id)
	)
	if is_instance_valid(runtime_branch):
		runtime_branch.stop_combat()


func _on_runtime_apex_slot_changed(
	_branch_id: StringName
) -> void:
	if not preparation_active or not is_instance_valid(branch_loadout_controller):
		return
	var runtime_branch: CombatBranch = (
		branch_loadout_controller.get_runtime_apex_branch()
	)
	if is_instance_valid(runtime_branch):
		runtime_branch.stop_combat()
