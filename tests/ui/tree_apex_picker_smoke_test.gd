extends Node


const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")
const TEST_A_SCENE: PackedScene = preload(
	"res://tests/fixtures/branches/test_legendary_branch_a.tscn"
)
const TEST_B_SCENE: PackedScene = preload(
	"res://tests/fixtures/branches/test_legendary_branch_b.tscn"
)


var failures: Array[String] = []
var definition_a: BranchDefinition
var definition_b: BranchDefinition
var storage_path: String
var original_seed_storage_path: String


func _ready() -> void:
	definition_a = create_definition(
		&"test_legendary_a", "Test Legendary A",
		BranchDefinition.LEGENDARY_TIER_1, TEST_A_SCENE,
		&"test_talent_a", "Test Talent A"
	)
	definition_b = create_definition(
		&"test_legendary_b", "Test Legendary B",
		BranchDefinition.LEGENDARY_TIER_2, TEST_B_SCENE,
		&"test_talent_b", "Test Talent B"
	)
	install_definitions()
	var loadout := get_node("/root/BranchLoadout") as BranchLoadoutService
	var progress := get_node("/root/BranchProgress") as BranchProgressService
	var seeds := get_node("/root/BranchSeeds") as BranchSeedService
	original_seed_storage_path = seeds.storage_path
	storage_path = "user://tree_apex_picker_%d_%d.cfg" % [
		OS.get_process_id(), Time.get_ticks_usec()
	]
	remove_storage_file()
	seeds.initialize(storage_path)
	loadout.clear_runtime_loadout_for_testing()
	progress.clear_runtime_progress_for_testing()
	await run_test(loadout, progress, seeds)
	loadout.clear_runtime_loadout_for_testing()
	progress.clear_runtime_progress_for_testing()
	seeds.initialize(original_seed_storage_path)
	remove_storage_file()
	uninstall_definitions()

	if failures.is_empty():
		print("TREE APEX PICKER SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("TREE APEX PICKER SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func run_test(
	loadout: BranchLoadoutService,
	progress: BranchProgressService,
	seeds: BranchSeedService
) -> void:
	var world: Node = MAIN_WORLD_SCENE.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var manager: Node = world.get_node("WaveManager")
	var director := world.get_node("WaveDirector") as WaveDirector
	var ui: CanvasLayer = world.get_node("UI") as CanvasLayer
	var screen: Control = world.get_node("UI/TreeScreen") as Control
	var talents: Control = world.get_node("UI/TalentScreen") as Control
	var panel: Panel = world.get_node("UI/BranchUpgradePanel") as Panel
	var controller := world.get_node(
		"Entities/Tree/Systems/TreeBranchLoadoutController"
	) as TreeBranchLoadoutController
	var change_button := screen.get_node(
		"MainPanel/DetailPanel/ChangeBranchButton"
	) as Button
	var confirm_button := screen.get_node("BranchPicker/ConfirmButton") as Button
	var category_preview := screen.get_node(
		"BranchPicker/PreviewPanel/CategoryLabel"
	) as Label
	var progress_preview := screen.get_node(
		"BranchPicker/PreviewPanel/ProgressLabel"
	) as Label
	var saved_preview := screen.get_node(
		"BranchPicker/PreviewPanel/SavedBuildLabel"
	) as Label
	var seed_label := screen.get_node("MainPanel/SeedPanel/SeedListLabel") as Label

	screen.call("select_slot", &"apex_slot")
	expect(
		(screen.get_node("MainPanel/TreeCanvas/ApexButton") as Button).text
		== "APEX\nEMPTY",
		"Initial Apex slot label is wrong."
	)
	expect(
		change_button.disabled
		and change_button.text == "NO LEGENDARY BRANCH SEEDS"
		and not screen.call("open_branch_picker"),
		"No-Seeds Apex state exposed the picker."
	)

	expect(seeds.unlock_branch_seed(definition_a), "Synthetic Seed A did not unlock.")
	expect(
		seed_label.text.contains("Test Legendary A")
		and seed_label.text.contains("Tier I"),
		"Seed panel did not live-refresh unlocked A with Tier text."
	)
	expect(not change_button.disabled, "Apex control did not enable after Seed A unlock.")
	expect(screen.call("open_branch_picker"), "Apex picker did not open.")
	expect(
		candidate_ids(screen) == [&"test_legendary_a"],
		"Apex candidates are not exactly unlocked Seed A."
	)
	expect(
		not screen.call(
			"_is_valid_standard_candidate", definition_a, &"standard_slot_1"
		)
		and not screen.call(
			"_is_valid_apex_definition", GameContent.get_branch(&"strength_branch")
		),
		"Standard and Legendary picker filters leaked across categories."
	)
	expect(
		category_preview.text == "LEGENDARY - Tier I"
		and progress_preview.text.contains("No progression recorded yet.")
		and saved_preview.text.contains("SAVED APEX BUILD")
		and saved_preview.text.contains("No saved Apex talents."),
		"Apex candidate definition/progress/build preview is incomplete."
	)
	expect(
		loadout.get_equipped_apex_branch_id() == &""
		and controller.get_runtime_apex_branch() == null
		and progress.get_progress(definition_a.branch_id) == null,
		"Apex preview mutated loadout, runtime, or progress."
	)

	expect(screen.call("confirm_selected_branch_candidate"), "Player-facing Apex A confirm failed.")
	await get_tree().process_frame
	var apex_a: CombatBranch = controller.get_runtime_apex_branch()
	expect(
		is_instance_valid(apex_a)
		and apex_a.branch_id == definition_a.branch_id
		and not apex_a.combat_enabled
		and screen.get("selected_slot_id") == &"apex_slot"
		and not (screen.get_node("BranchPicker") as Panel).visible,
		"Confirmed Apex A runtime, selection, picker, or stopped state is wrong."
	)
	expect(
		detail_text(screen).contains("Test Legendary A")
		and detail_text(screen).contains("LEGENDARY - Tier I"),
		"Equipped Apex detail or Tier is wrong."
	)
	apex_a.add_xp(
		apex_a.get_safe_xp_required_per_level()
	)
	expect(apex_a.purchase_talent(&"test_talent_a"), "Apex A talent purchase failed.")

	expect(manager.continue_from_preparation(), "START RUN with Apex failed.")
	expect(apex_a.combat_enabled, "Apex did not resume after Preparation.")
	for slot_index in range(1, 5):
		expect(
			controller.get_runtime_branch(BranchSlotRules.get_slot_id(slot_index)).combat_enabled,
			"Standard Slot %d did not resume with Apex." % slot_index
		)
	ui.call("open_tree_screen")
	screen.call("select_slot", &"apex_slot")
	expect(
		not change_button.disabled
		and (screen.get_node("MainPanel/DetailPanel/LoadoutStatusLabel") as Label)
		.text.contains("APEX LOADOUT EDITING ENABLED")
		and screen.call("open_branch_picker"),
		"Apex controls are not enabled during active gameplay."
	)
	screen.call("select_branch_candidate", definition_a.branch_id)
	expect(
		not screen.call("confirm_selected_branch_candidate")
		and controller.get_runtime_apex_branch() == apex_a,
		"Equipped Apex no-op behavior changed during active gameplay."
	)
	screen.call("close_branch_picker")
	director.cancel_cycle(true)
	manager.remove_remaining_enemies()

	ui.call("open_talent_screen")
	var talent_branches: Array = talents.get("available_branches") as Array
	expect(talent_branches.size() == 5, "TALENTS did not discover five runtime Branches.")
	var apex_button_text_found: bool = false
	var talent_buttons: Dictionary = talents.get("branch_buttons_by_instance_id") as Dictionary
	for button_value in talent_buttons.values():
		var button := button_value as Button
		if button.text == "APEX - TEST LEGENDARY A":
			apex_button_text_found = true
	expect(apex_button_text_found, "TALENTS did not label Slot 5 as APEX.")
	var panel_branches: Array = panel.get("branches_by_slot") as Array
	expect(
		panel_branches[BranchSlotRules.APEX_SLOT - 1] == apex_a
		and (panel.get_node("VBoxContainer/BranchSlotButtons/Slot5Button") as Button)
		.text == "TEST LEGENDARY A",
		"BRANCHES panel did not expose Apex A."
	)
	panel.call("select_branch", BranchSlotRules.APEX_SLOT - 1)

	manager.call("_enter_preparation", &"substage_complete")
	await get_tree().process_frame
	screen.call("select_slot", &"apex_slot")
	screen.set("selected_candidate_branch_id", definition_b.branch_id)
	expect(
		not screen.call("confirm_selected_branch_candidate")
		and loadout.get_equipped_apex_branch_id() == definition_a.branch_id,
		"Locked Seed B bypassed the player-facing unlock gate."
	)
	expect(screen.call("open_branch_picker"), "Apex picker did not reopen for live unlock.")
	expect(seeds.acquire_branch_seed(definition_b, 2), "Synthetic Seed B Tier II did not unlock.")
	expect(
		candidate_ids(screen) == [&"test_legendary_a", &"test_legendary_b"]
		and seed_label.text.find("Test Legendary A")
		< seed_label.text.find("Test Legendary B"),
		"Live Seed unlock did not preserve unlock candidate order."
	)

	screen.call("select_branch_candidate", definition_b.branch_id)
	var old_apex_a: CombatBranch = controller.get_runtime_apex_branch()
	expect(screen.call("confirm_selected_branch_candidate"), "Apex A to B UI swap failed.")
	await get_tree().process_frame
	var apex_b: CombatBranch = controller.get_runtime_apex_branch()
	expect(
		not is_instance_valid(old_apex_a)
		and is_instance_valid(apex_b)
		and apex_b.branch_id == definition_b.branch_id
		and screen.get("selected_slot_id") == &"apex_slot"
		and detail_text(screen).contains("LEGENDARY - Tier II"),
		"Apex B runtime, selection, or Tier refresh is wrong."
	)
	expect(
		panel.get("selected_branch") == apex_b,
		"BRANCHES panel retained freed Apex A after swap."
	)

	expect(screen.call("open_branch_picker"), "Apex picker did not open for saved build.")
	screen.call("select_branch_candidate", definition_a.branch_id)
	expect(
		saved_preview.text.contains("SAVED APEX BUILD")
		and saved_preview.text.contains("Test Talent A")
		and loadout.get_equipped_apex_branch_id() == definition_b.branch_id,
		"Saved Apex A build preview is wrong or mutated loadout."
	)
	expect(screen.call("confirm_selected_branch_candidate"), "Apex A restore failed.")
	await get_tree().process_frame
	var restored_a: CombatBranch = controller.get_runtime_apex_branch()
	expect(restored_a.has_talent(&"test_talent_a"), "Apex A talent was not restored.")
	expect(screen.call("open_branch_picker"), "Apex picker did not reopen for EQUIPPED state.")
	expect(
		confirm_button.disabled
		and confirm_button.text == "EQUIPPED"
		and not screen.call("confirm_selected_branch_candidate")
		and controller.get_runtime_apex_branch() == restored_a,
		"Current Apex candidate no-op behavior is wrong."
	)
	screen.call("close_branch_picker")

	write_unknown_seed_fixture([definition_a.branch_id, definition_b.branch_id, &"legacy_unknown"])
	expect(seeds.reload_from_disk(), "Unknown Seed fixture did not reload.")
	screen.call("refresh_screen")
	screen.call("select_slot", &"apex_slot")
	expect(
		seed_label.text.contains("Unknown Branch Seed")
		and seed_label.text.contains("legacy_unknown"),
		"Unknown Seed fallback is missing."
	)
	expect(screen.call("open_branch_picker"), "Apex picker failed with unknown Seed.")
	expect(
		candidate_ids(screen) == [&"test_legendary_a", &"test_legendary_b"],
		"Unknown Seed became an Apex candidate."
	)
	screen.call("close_branch_picker")

	screen.call("select_slot", &"standard_slot_1")
	expect(screen.call("open_branch_picker"), "Standard picker broke after Apex integration.")
	expect(
		candidate_ids(screen) == [&"strength_branch", &"blossom_branch", &"poison_vine"],
		"Standard picker contains Legendary candidates."
	)
	screen.call("close_branch_picker")

	var thorn_crown: BranchDefinition = GameContent.get_branch(&"thorn_crown")
	expect(
		is_instance_valid(thorn_crown)
		and not seeds.is_branch_seed_unlocked(&"thorn_crown"),
		"Registered Thorn Crown was default-unlocked."
	)
	expect(seeds.unlock_branch_seed(thorn_crown), "Production Thorn Crown Seed did not unlock.")
	screen.call("select_slot", &"apex_slot")
	expect(screen.call("open_branch_picker"), "Apex picker did not open for Thorn Crown.")
	expect(
		candidate_ids(screen) == [
			&"test_legendary_a", &"test_legendary_b", &"thorn_crown"
		],
		"Production Thorn Crown did not appear in unlock order."
	)
	screen.call("select_branch_candidate", &"thorn_crown")
	var description_preview := screen.get_node(
		"BranchPicker/PreviewPanel/DescriptionLabel"
	) as Label
	expect(
		category_preview.text == "LEGENDARY - Tier I"
		and description_preview.text.contains("living thorns")
		and progress_preview.text.contains("No progression recorded yet.")
		and saved_preview.text.contains("No saved Apex talents."),
		"Production Thorn Crown picker preview is incomplete."
	)
	expect(screen.call("confirm_selected_branch_candidate"), "Player-facing Thorn Crown equip failed.")
	await get_tree().process_frame
	var thorn_runtime: CombatBranch = controller.get_runtime_apex_branch()
	expect(
		loadout.get_equipped_apex_branch_id() == &"thorn_crown"
		and is_instance_valid(thorn_runtime)
		and thorn_runtime.branch_id == &"thorn_crown"
		and thorn_runtime.get_slot_id() == &"apex_slot"
		and not thorn_runtime.combat_enabled
		and screen.get("selected_slot_id") == &"apex_slot"
		and detail_text(screen).contains("LEGENDARY - Tier I"),
		"Thorn Crown TREE equip, Tier, slot, or Preparation stop state is wrong."
	)
	expect(
		(panel.get("branches_by_slot") as Array)[BranchSlotRules.APEX_SLOT - 1]
		== thorn_runtime
		and thorn_runtime.get_upgrade_ids() == [
			&"thorn_damage", &"attack_speed", &"burst_radius"
		],
		"BRANCHES did not discover Thorn Crown and its three upgrades."
	)
	expect(manager.continue_from_preparation(), "START RUN with Thorn Crown failed.")
	expect(thorn_runtime.combat_enabled, "Thorn Crown did not resume after START RUN.")
	director.cancel_cycle(true)
	manager.remove_remaining_enemies()
	ui.call("open_talent_screen")
	var thorn_button_found: bool = false
	for button_value in (talents.get("branch_buttons_by_instance_id") as Dictionary).values():
		var button := button_value as Button
		if button.text == "APEX - THORN CROWN":
			thorn_button_found = true
	talents.call("select_branch", thorn_runtime)
	expect(
		thorn_button_found
		and thorn_runtime.get_talent_ids() == [
			&"barbed_core", &"twin_torment", &"overgrowth"
		],
		"TALENTS did not discover Thorn Crown and its three talents."
	)

	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func create_definition(
	branch_id: StringName,
	display_name: String,
	tier: int,
	branch_scene: PackedScene,
	talent_id: StringName,
	talent_name: String
) -> BranchDefinition:
	var talent := TalentDefinition.new()
	talent.talent_id = talent_id
	talent.display_name = talent_name
	talent.path_name = "Fixture"
	talent.required_branch_level = 2
	var talent_tree := TalentTreeDefinition.new()
	talent_tree.talent_tree_id = StringName("%s_tree" % branch_id)
	talent_tree.display_name = "%s Tree" % display_name
	talent_tree.talents = [talent]
	var definition := BranchDefinition.new()
	definition.branch_id = branch_id
	definition.display_name = display_name
	definition.description = "%s synthetic fixture description." % display_name
	definition.category_id = BranchDefinition.CATEGORY_LEGENDARY
	definition.legendary_tier = tier
	definition.branch_scene = branch_scene
	definition.targeting_profile = TargetingProfile.new()
	definition.talent_tree = talent_tree
	return definition


func install_definitions() -> void:
	GameContent.registry.branches.append(definition_a)
	GameContent.registry.branches.append(definition_b)
	GameContent.registry.rebuild_indexes()


func uninstall_definitions() -> void:
	GameContent.registry.branches.erase(definition_a)
	GameContent.registry.branches.erase(definition_b)
	GameContent.registry.rebuild_indexes()


func candidate_ids(screen: Control) -> Array[StringName]:
	var ids: Array[StringName] = []
	for definition in screen.get("candidate_definitions") as Array[BranchDefinition]:
		ids.append(definition.branch_id)
	return ids


func detail_text(screen: Control) -> String:
	var lines: Array[String] = []
	for label_name in [
		"DetailTitleLabel", "CategoryLabel", "SharedProgressLabel",
		"TalentBuildLabel", "UpgradesLabel", "StatsLabel"
	]:
		lines.append(String(
			(screen.get_node("MainPanel/DetailPanel/DetailScroll/DetailContent/%s" % label_name) as Label).text
		))
	return "\n".join(lines)


func write_unknown_seed_fixture(ids: Array[StringName]) -> void:
	var config := ConfigFile.new()
	var packed_ids := PackedStringArray()
	for branch_id in ids:
		packed_ids.append(String(branch_id))
	config.set_value("branch_seed_unlocks", "version", 2)
	config.set_value("branch_seed_unlocks", "branch_ids", packed_ids)
	expect(config.save(storage_path) == OK, "Could not save unknown Seed fixture.")


func remove_storage_file() -> void:
	if FileAccess.file_exists(storage_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(storage_path))


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
