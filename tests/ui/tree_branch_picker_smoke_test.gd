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
	await run_test(loadout)
	loadout.clear_runtime_loadout_for_testing()
	progress.clear_runtime_progress_for_testing()

	if failures.is_empty():
		print("TREE BRANCH PICKER SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print(
		"TREE BRANCH PICKER SMOKE TEST FAIL: %d failure(s)"
		% failures.size()
	)
	get_tree().quit(1)


func run_test(loadout: BranchLoadoutService) -> void:
	var world: Node = MAIN_WORLD_SCENE.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame

	var manager: Node = world.get_node("WaveManager")
	var director := world.get_node("WaveDirector") as WaveDirector
	var ui: CanvasLayer = world.get_node("UI") as CanvasLayer
	var screen: Control = world.get_node("UI/TreeScreen") as Control
	var controller := world.get_node(
		"Entities/Tree/Systems/TreeBranchLoadoutController"
	) as TreeBranchLoadoutController
	var change_button := screen.get_node(
		"MainPanel/DetailPanel/ChangeBranchButton"
	) as Button
	var continue_button := screen.get_node(
		"MainPanel/ContinueButton"
	) as Button
	var banner := screen.get_node("MainPanel/PreparationBanner") as Label
	var confirm_button := screen.get_node("BranchPicker/ConfirmButton") as Button
	var saved_build_label := screen.get_node(
		"BranchPicker/PreviewPanel/SavedBuildLabel"
	) as Label

	expect(
		manager.is_preparation_active()
		and screen.visible
		and banner.visible
		and continue_button.text == "START RUN",
		"Initial picker Preparation UI is wrong."
	)
	screen.call("select_slot", &"standard_slot_1")
	expect(not change_button.disabled, "CHANGE BRANCH is disabled during Preparation.")
	expect(screen.call("open_branch_picker"), "Standard picker did not open.")

	var actual_candidate_ids: Array[StringName] = []
	for definition in screen.get("candidate_definitions") as Array[BranchDefinition]:
		actual_candidate_ids.append(definition.branch_id)
	var expected_candidate_ids: Array[StringName] = []
	for definition in GameContent.get_branches():
		if screen.call(
			"_is_valid_standard_candidate",
			definition,
			&"standard_slot_1"
		):
			expected_candidate_ids.append(definition.branch_id)
	expect(
		actual_candidate_ids == expected_candidate_ids
		and actual_candidate_ids == [&"strength_branch", &"blossom_branch"],
		"Candidate collection does not match registry order."
	)

	var synthetic_legendary := BranchDefinition.new()
	synthetic_legendary.category_id = BranchDefinition.CATEGORY_LEGENDARY
	synthetic_legendary.legendary_tier = BranchDefinition.LEGENDARY_TIER_1
	expect(
		not screen.call(
			"_is_valid_standard_candidate",
			synthetic_legendary,
			&"standard_slot_1"
		),
		"Legendary definition passed the standard filter."
	)

	var original_slot_1: CombatBranch = controller.get_runtime_branch(
		&"standard_slot_1"
	)
	screen.call("select_branch_candidate", &"strength_branch")
	expect(
		confirm_button.disabled
		and confirm_button.text == "EQUIPPED"
		and not screen.call("confirm_selected_branch_candidate")
		and controller.get_runtime_branch(&"standard_slot_1") == original_slot_1,
		"Current candidate performed or allowed a no-op equip."
	)

	original_slot_1.add_xp(2)
	expect(
		original_slot_1.purchase_talent(&"sweeping_strike"),
		"Could not prepare Slot 1 Strength saved build."
	)
	var slot_3: CombatBranch = controller.get_runtime_branch(&"standard_slot_3")
	expect(slot_3.purchase_talent(&"rebuff"), "Could not prepare Slot 3 saved build.")

	screen.call("select_branch_candidate", &"blossom_branch")
	expect(screen.call("confirm_selected_branch_candidate"), "Strength to Blossom confirm failed.")
	await get_tree().process_frame
	var slot_1_blossom: CombatBranch = controller.get_runtime_branch(&"standard_slot_1")
	expect(
		is_instance_valid(slot_1_blossom)
		and slot_1_blossom.branch_id == &"blossom_branch"
		and not slot_1_blossom.combat_enabled,
		"Swapped Blossom is wrong or combat-enabled during Preparation."
	)
	slot_1_blossom.add_xp(2)
	expect(
		slot_1_blossom.purchase_talent(&"abundant_bloom"),
		"Could not prepare Slot 1 Blossom saved build."
	)

	expect(screen.call("open_branch_picker"), "Picker did not reopen for restore.")
	screen.call("select_branch_candidate", &"strength_branch")
	expect(
		saved_build_label.text.contains("SAVED BUILD FOR SLOT 1")
		and saved_build_label.text.contains("Sweeping Strike")
		and loadout.get_equipped_branch_id(&"standard_slot_1") == &"blossom_branch",
		"Slot 1 saved Strength build preview is wrong or mutated loadout."
	)
	expect(screen.call("confirm_selected_branch_candidate"), "Strength restore confirm failed.")
	await get_tree().process_frame
	var restored_strength: CombatBranch = controller.get_runtime_branch(&"standard_slot_1")
	expect(
		restored_strength.has_talent(&"sweeping_strike")
		and not restored_strength.has_talent(&"abundant_bloom"),
		"Slot 1 Strength saved build was not restored."
	)

	screen.call("select_slot", &"standard_slot_3")
	expect(screen.call("open_branch_picker"), "Slot 3 picker did not open.")
	screen.call("select_branch_candidate", &"strength_branch")
	expect(
		saved_build_label.text.contains("SAVED BUILD FOR SLOT 3")
		and saved_build_label.text.contains("Rebuff")
		and not saved_build_label.text.contains("Sweeping Strike"),
		"Saved build preview is not scoped by slot_id and branch_id."
	)
	screen.call("close_branch_picker")

	screen.call("select_slot", &"standard_slot_2")
	expect(screen.call("open_branch_picker"), "Slot 2 picker did not open.")
	screen.call("select_branch_candidate", &"strength_branch")
	expect(screen.call("confirm_selected_branch_candidate"), "Duplicate Strength equip failed.")
	await get_tree().process_frame
	expect(
		controller.get_runtime_branch(&"standard_slot_1").branch_id == &"strength_branch"
		and controller.get_runtime_branch(&"standard_slot_2").branch_id == &"strength_branch"
		and controller.get_runtime_branch(&"standard_slot_3").branch_id == &"strength_branch",
		"Duplicate standard archetypes were blocked."
	)

	screen.call("select_slot", &"apex_slot")
	expect(
		change_button.disabled and not screen.call("open_branch_picker"),
		"Apex exposed the standard Branch picker."
	)

	expect(manager.continue_from_preparation(), "Could not leave Preparation.")
	director.cancel_cycle(true)
	manager.remove_remaining_enemies()
	ui.call("open_tree_screen")
	screen.call("select_slot", &"standard_slot_4")
	expect(
		change_button.disabled
		and (screen.get_node("MainPanel/DetailPanel/LoadoutStatusLabel") as Label).text.contains("LOADOUT LOCKED"),
		"TREE is not locked outside Preparation."
	)
	screen.set("selected_candidate_branch_id", &"strength_branch")
	var slot_4_before: CombatBranch = controller.get_runtime_branch(&"standard_slot_4")
	expect(
		not screen.call("confirm_selected_branch_candidate")
		and controller.get_runtime_branch(&"standard_slot_4") == slot_4_before
		and loadout.get_equipped_branch_id(&"standard_slot_4") == &"blossom_branch",
		"Direct UI confirm bypassed the outside-Preparation guard."
	)

	var forbidden_text: String = collect_control_text(screen)
	for forbidden_phrase in ["UNEQUIP", "EMPTY SLOT", "REMOVE BRANCH"]:
		expect(
			not forbidden_text.contains(forbidden_phrase),
			"TREE exposes forbidden player-facing action '%s'." % forbidden_phrase
		)

	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func collect_control_text(root: Node) -> String:
	var lines: Array[String] = []
	for node in root.find_children("*", "Control", true, false):
		if node is Label or node is Button:
			lines.append(String(node.get("text")))
	return "\n".join(lines)


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
