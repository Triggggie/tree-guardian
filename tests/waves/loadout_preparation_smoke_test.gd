extends Node


const MAIN_WORLD_SCENE: PackedScene = preload(
	"res://scenes/main_world.tscn"
)


var failures: Array[String] = []


func _ready() -> void:
	var loadout := get_node("/root/BranchLoadout") as BranchLoadoutService
	var progress := get_node("/root/BranchProgress") as BranchProgressService
	loadout.clear_runtime_loadout_for_testing()
	progress.clear_runtime_progress_for_testing()
	await run_test()
	loadout.clear_runtime_loadout_for_testing()
	progress.clear_runtime_progress_for_testing()

	if failures.is_empty():
		print("LOADOUT PREPARATION SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print(
		"LOADOUT PREPARATION SMOKE TEST FAIL: %d failure(s)"
		% failures.size()
	)
	get_tree().quit(1)


func run_test() -> void:
	var world: Node = MAIN_WORLD_SCENE.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame

	var manager: Node = world.get_node("WaveManager")
	var director := world.get_node("WaveDirector") as WaveDirector
	director.debug_start_global_wave = 0
	var tracker := world.get_node("EnemyTracker") as EnemyTracker
	var tree_node: Node = world.get_node("Entities/Tree")
	var game_over_panel: Panel = world.get_node("UI/GameOverPanel") as Panel
	game_over_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	game_over_panel.set("automatic_retry_delay", 0.1)
	var retry_button := game_over_panel.get_node(
		"VBoxContainer/RestartButton"
	) as Button
	var automatic_retry_count: Array[int] = [0]
	game_over_panel.retry_requested.connect(
		func() -> void: automatic_retry_count[0] += 1
	)
	var controller := world.get_node(
		"Entities/Tree/Systems/TreeBranchLoadoutController"
	) as TreeBranchLoadoutController
	var tree_screen: Control = world.get_node("UI/TreeScreen") as Control

	expect(manager.is_preparation_active(), "Initial Preparation is not active.")
	expect(
		manager.get_preparation_reason() == &"initial",
		"Initial Preparation reason is wrong."
	)
	expect(not director.is_cycle_running(), "Initial wave cycle is running.")
	expect(
		get_tree().get_nodes_in_group("enemies").is_empty(),
		"Initial Preparation contains enemies."
	)
	expect(tree_screen.visible, "TREE did not auto-open for Initial Preparation.")
	expect(
		manager.is_branch_loadout_edit_allowed(),
		"Initial Preparation does not allow loadout editing."
	)
	for slot_index in range(1, 5):
		var branch: CombatBranch = controller.get_runtime_branch(
			BranchSlotRules.get_slot_id(slot_index)
		)
		expect(
			is_instance_valid(branch) and not branch.combat_enabled,
			"Slot %d is not stopped during Initial Preparation." % slot_index
		)

	var started_waves: Array[int] = []
	director.wave_changed.connect(
		func(global_wave: int, _count: int) -> void:
			started_waves.append(global_wave)
	)
	expect(manager.continue_from_preparation(), "START RUN failed.")
	expect(not manager.is_preparation_active(), "START RUN left Preparation active.")
	expect(director.is_cycle_running(), "START RUN did not start the cycle.")
	expect(
		manager.is_branch_loadout_edit_allowed(),
		"Active gameplay does not allow loadout editing."
	)
	expect(
		started_waves == [1] and director.get_current_progress_code() == "1-1-1",
		"START RUN did not begin at 1-1-1."
	)
	director.cancel_cycle(true)
	manager.remove_remaining_enemies()

	for checked_wave in [50, 99, 100, 101, 200]:
		director.current_wave = checked_wave
		var expected_end: bool = checked_wave in [100, 200]
		expect(
			director.is_current_wave_substage_end() == expected_end,
			"Substage boundary helper is wrong for Wave %d." % checked_wave
		)

	var checkpoint_count: Array[int] = [0]
	director.substage_checkpoint_reached.connect(
		func(_wave: int) -> void:
			checkpoint_count[0] += 1
	)
	director.current_wave = 100
	director._cycle_running = true
	expect(
		director._reach_substage_checkpoint_if_needed(100),
		"Wave 100 did not reach the Substage checkpoint."
	)
	expect(
		checkpoint_count[0] == 1
		and not director.is_cycle_running()
		and manager.is_preparation_active()
		and manager.get_preparation_reason() == &"substage_complete",
		"Substage checkpoint did not enter Preparation exactly once."
	)
	expect(
		get_tree().get_nodes_in_group("enemies").is_empty(),
		"Substage Preparation contains enemies."
	)

	started_waves.clear()
	expect(manager.continue_from_preparation(), "Substage CONTINUE failed.")
	expect(
		started_waves == [101]
		and director.get_current_progress_code() == "1-2-1",
		"Substage CONTINUE did not begin at 1-2-1."
	)
	director.cancel_cycle(true)
	manager.remove_remaining_enemies()

	started_waves.clear()
	director.current_wave = 373
	director._cycle_running = true
	tree_node.call("add_forest_essence", 17)
	var essence_before_death: int = int(tree_node.call("get_forest_essence"))
	tree_node.call("die")
	await get_tree().process_frame
	expect(manager.tree_defeated, "Tree death did not set defeated state.")
	expect(game_over_panel.visible, "Tree death presentation did not appear.")
	expect(
		not retry_button.visible and retry_button.disabled,
		"Tree death still exposes a manual retry button."
	)
	expect(
		not manager.is_branch_loadout_edit_allowed(),
		"Defeated Tree still allows loadout editing."
	)
	tree_screen.call("refresh_screen")
	tree_screen.call("select_slot", &"standard_slot_1")
	expect(
		(tree_screen.get_node("MainPanel/DetailPanel/LoadoutStatusLabel") as Label)
		.text.contains("Tree is defeated."),
		"Defeated TREE state does not explain the unavailable loadout."
	)
	expect(not director.is_cycle_running(), "Tree death did not stop the cycle.")
	expect(
		get_tree().get_nodes_in_group("enemies").is_empty(),
		"Tree death did not remove enemies."
	)
	await get_tree().create_timer(0.15).timeout
	expect(not manager.tree_defeated, "Retry did not clear defeated state.")
	expect(manager.is_branch_loadout_edit_allowed(), "Retry did not restore loadout editing.")
	expect(float(tree_node.get("current_health")) > 0.0, "Retry did not revive the Tree.")
	expect(
		int(tree_node.call("get_forest_essence")) == essence_before_death,
		"Automatic retry rolled back earned Forest Essence."
	)
	tree_node.call("add_forest_essence", 3)
	expect(
		int(tree_node.call("get_forest_essence")) == essence_before_death + 3,
		"Automatic restart could not continue earning Forest Essence."
	)
	expect(
		not manager.is_preparation_active()
		and manager.get_preparation_reason() == &""
		and director.is_cycle_running()
		and director.current_wave == 301
		and director.get_current_progress_code() == "1-4-1",
		"Retry did not automatically start Substage 4 Wave 1."
	)
	expect(not game_over_panel.visible, "Automatic retry left the death modal visible.")
	expect(not tree_screen.visible, "Automatic retry opened blocking Preparation UI.")
	expect(
		automatic_retry_count[0] == 1,
		"Tree death emitted duplicate automatic retry requests."
	)

	expect(
		started_waves == [301],
		"Tree death started a duplicate or skipped retry cycle."
	)
	expect(
		not tracker.get_tracked_global_waves().has(373),
		"Automatic retry retained an enemy cohort from the failed run."
	)
	var essence_before_second_death: int = int(tree_node.call("get_forest_essence"))
	director.current_wave = 373
	tree_node.call("die")
	await get_tree().create_timer(0.15).timeout
	expect(
		automatic_retry_count[0] == 2
		and not manager.tree_defeated
		and not manager.is_preparation_active()
		and manager.get_preparation_reason() == &""
		and director.current_wave == 301
		and director.is_cycle_running()
		and started_waves == [301, 301],
		"Repeated death accumulated retry state or failed to restart the same Substage."
	)
	expect(
		int(tree_node.call("get_forest_essence")) == essence_before_second_death
		and not tracker.get_tracked_global_waves().has(373),
		"Repeated retry changed rewards or retained failed-run enemies."
	)
	director.cancel_cycle(true)
	manager.remove_remaining_enemies()

	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
