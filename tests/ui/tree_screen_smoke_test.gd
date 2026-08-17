extends Node

const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")
var failures: Array[String] = []

func _ready() -> void:
	var progress := get_node("/root/BranchProgress") as BranchProgressService
	var loadout := get_node("/root/BranchLoadout") as BranchLoadoutService
	var seeds := get_node("/root/BranchSeeds") as BranchSeedService
	var saved_seed_ids: Array[StringName] = seeds.unlocked_branch_seed_ids.duplicate()
	seeds.unlocked_branch_seed_ids.clear()
	loadout.clear_runtime_loadout_for_testing()
	progress.clear_runtime_progress_for_testing()
	await run_test()
	loadout.clear_runtime_loadout_for_testing()
	progress.clear_runtime_progress_for_testing()
	seeds.unlocked_branch_seed_ids = saved_seed_ids
	if failures.is_empty():
		print("TREE SCREEN SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("TREE SCREEN SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)

func run_test() -> void:
	var world: Node = MAIN_WORLD_SCENE.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await get_tree().process_frame
	var ui: CanvasLayer = world.get_node("UI") as CanvasLayer
	var tree_button: Button = ui.get_node("TreeScreenButton") as Button
	var talents_button: Button = ui.get_node("TalentsButton") as Button
	var screen: Control = ui.get_node("TreeScreen") as Control
	var talents: Control = ui.get_node("TalentScreen") as Control
	var manager: Node = world.get_node("WaveManager")
	var director := world.get_node("WaveDirector") as WaveDirector
	await get_tree().process_frame
	expect(screen.visible, "Initial Preparation did not auto-open TREE.")
	screen.call("close_screen")
	expect(screen.visible, "CLOSE escaped active Preparation.")
	expect(manager.continue_from_preparation(), "TREE fixture could not leave Preparation.")
	director.cancel_cycle(true)
	manager.remove_remaining_enemies()
	expect(tree_button.text == "TREE" and tree_button.is_visible_in_tree() and not tree_button.disabled, "TREE button is not visible and enabled.")
	expect(Rect2(Vector2.ZERO, Vector2(1920, 1080)).encloses(tree_button.get_global_rect()), "TREE button is outside the viewport.")
	expect((ui.get_node("UpgradeTabs/TreeTabButton") as Button).text == "TRUNK", "Small TREE tab was not renamed TRUNK.")
	tree_button.pressed.emit()
	expect(screen.visible and not talents.visible and not get_tree().paused, "TREE navigation or pause state is wrong.")

	var branches: Dictionary = screen.get("branches_by_slot") as Dictionary
	expect(branches.size() == 4, "TREE did not find four equipped Branches.")
	var expected: Dictionary = {&"standard_slot_1": &"strength_branch", &"standard_slot_2": &"blossom_branch", &"standard_slot_3": &"strength_branch", &"standard_slot_4": &"blossom_branch"}
	for slot_id in expected:
		expect(is_instance_valid(branches.get(slot_id)) and (branches[slot_id] as CombatBranch).branch_id == expected[slot_id], "Wrong Branch in %s." % slot_id)
	expect(not branches.has(&"apex_slot"), "Apex is not empty.")
	test_layout(screen)

	var strength_1 := branches[&"standard_slot_1"] as CombatBranch
	var strength_3 := branches[&"standard_slot_3"] as CombatBranch
	var blossom_2 := branches[&"standard_slot_2"] as CombatBranch
	strength_1.add_xp(2)
	expect(strength_1.purchase_talent(&"sweeping_strike"), "Slot 1 talent purchase failed.")
	expect(strength_3.purchase_talent(&"rebuff"), "Slot 3 talent purchase failed.")
	screen.call("select_slot", &"standard_slot_1")
	var text_1: String = detail_text(screen)
	expect(text_1.contains("Strength Branch") and text_1.contains("STANDARD") and text_1.contains("Level 2") and text_1.contains("Talent Points Earned 1"), "Standard shared detail is incomplete.")
	expect(text_1.contains("Available Talent Points: 0") and text_1.contains("Sweeping Strike") and not text_1.contains("Rebuff"), "Slot 1 talent detail is wrong.")
	expect(not text_1.contains("Tier I"), "Standard Branch displays a Tier.")
	for line in strength_1.get_stat_summary_lines(): expect(text_1.contains(line), "Missing Strength runtime stat: %s" % line)
	screen.call("select_slot", &"standard_slot_3")
	var text_3: String = detail_text(screen)
	expect(text_3.contains("Rebuff") and not text_3.contains("Sweeping Strike"), "Slot 3 talent detail is wrong.")
	screen.call("select_slot", &"standard_slot_2")
	var blossom_text: String = detail_text(screen)
	for line in blossom_2.get_stat_summary_lines(): expect(blossom_text.contains(line), "Missing Blossom runtime stat: %s" % line)

	var tree_node: Node = world.get_node("Entities/Tree")
	tree_node.call("add_forest_essence", 100)
	var upgrade_id: StringName = strength_1.get_upgrade_ids()[0]
	expect(strength_1.purchase_upgrade(upgrade_id), "Shared Strength upgrade failed.")
	for slot_id in [&"standard_slot_1", &"standard_slot_3"]:
		screen.call("select_slot", slot_id)
		expect(detail_text(screen).contains("%s - Lv.1" % strength_1.get_upgrade_display_name(upgrade_id)), "Shared upgrade is missing from %s." % slot_id)

	screen.call("select_slot", &"apex_slot")
	expect(detail_text(screen).contains("APEX SLOT\nEMPTY"), "Empty Apex detail is wrong.")
	expect(not (screen.get_node("MainPanel/TreeCanvas/ApexButton") as Button).disabled, "Apex button is disabled.")
	var seed_label := screen.get_node("MainPanel/SeedPanel/SeedListLabel") as Label
	expect(seed_label.text == "No Legendary Branch Seeds unlocked.", "Seed empty state is wrong.")
	var seeds := get_node("/root/BranchSeeds") as BranchSeedService
	var saved_ids: Array[StringName] = seeds.unlocked_branch_seed_ids.duplicate()
	seeds.unlocked_branch_seed_ids = [&"legacy_unknown_branch"]
	screen.call("refresh_screen")
	expect(seed_label.text.contains("Unknown Branch Seed") and seed_label.text.contains("legacy_unknown_branch"), "Unknown Seed fallback is wrong.")
	seeds.unlocked_branch_seed_ids = saved_ids
	var synthetic := BranchDefinition.new()
	synthetic.category_id = BranchDefinition.CATEGORY_LEGENDARY
	synthetic.legendary_tier = BranchDefinition.LEGENDARY_TIER_2
	expect(synthetic.get_legendary_tier_display_name() == "Tier II", "Tier formatter changed.")

	var loadout := get_node("/root/BranchLoadout") as BranchLoadoutService
	screen.call("select_slot", &"standard_slot_1")
	expect(loadout.equip_standard_branch(&"standard_slot_1", &"blossom_branch"), "TREE live swap setup failed.")
	await get_tree().process_frame
	expect(screen.get("selected_slot_id") == &"standard_slot_1", "TREE selection moved after runtime swap.")
	expect((screen.get_node("MainPanel/TreeCanvas/Slot1Button") as Button).text.contains("BLOSSOM") and detail_text(screen).contains("Blossom Branch"), "TREE did not live-refresh Slot 1 to Blossom.")
	expect(loadout.unequip_standard_branch(&"standard_slot_1"), "TREE live unequip setup failed.")
	await get_tree().process_frame
	expect((screen.get_node("MainPanel/TreeCanvas/Slot1Button") as Button).text == "SLOT 1\nEMPTY" and detail_text(screen).contains("SLOT 1\nEMPTY"), "TREE did not live-refresh Slot 1 EMPTY.")

	screen.call("close_screen")
	expect(not screen.visible and not get_tree().paused, "CLOSE changed pause state or left TREE open.")
	tree_button.pressed.emit()
	talents_button.pressed.emit()
	expect(talents.visible and not screen.visible, "TALENTS did not hide TREE.")
	tree_button.pressed.emit()
	expect(screen.visible and not talents.visible, "TREE did not hide TALENTS.")
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func test_layout(screen: Control) -> void:
	expect(
		screen.anchor_left == 0.0
		and screen.anchor_top == 0.0
		and screen.anchor_right == 1.0
		and screen.anchor_bottom == 1.0,
		"TREE is not configured as full rect."
	)
	var canvas := screen.get_node("MainPanel/TreeCanvas") as Control
	var s1 := canvas.get_node("Slot1Button") as Button
	var s2 := canvas.get_node("Slot2Button") as Button
	var s3 := canvas.get_node("Slot3Button") as Button
	var s4 := canvas.get_node("Slot4Button") as Button
	var apex := canvas.get_node("ApexButton") as Button
	expect(s2.get_global_rect().get_center().y < s1.get_global_rect().get_center().y and s2.get_global_rect().get_center().x < s4.get_global_rect().get_center().x, "Slot 2 is not upper-left.")
	expect(s4.get_global_rect().get_center().y < s3.get_global_rect().get_center().y, "Slot 4 is not upper-right.")
	expect(apex.get_global_rect().get_center().y < s2.get_global_rect().get_center().y, "Apex is not top-center.")
	for button in [s1, s2, s3, s4, apex]: expect(canvas.get_global_rect().encloses(button.get_global_rect()), "%s is outside TreeCanvas." % button.name)
	var detail := screen.get_node("MainPanel/DetailPanel") as Control
	var seed_panel := screen.get_node("MainPanel/SeedPanel") as Control
	expect(not detail.get_global_rect().intersects(seed_panel.get_global_rect()), "Detail overlaps Seed panel.")
	var detail_scroll := detail.get_node("DetailScroll") as ScrollContainer
	var detail_content := detail_scroll.get_node("DetailContent") as VBoxContainer
	expect(
		detail_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
		and detail_content.get_child_count() == 6,
		"TREE detail is not a scrollable container-based section flow."
	)
	var previous_bottom: float = -INF
	for child in detail_content.get_children():
		var section := child as Control
		expect(section.position.y >= previous_bottom, "%s overlaps the previous TREE detail section." % section.name)
		previous_bottom = section.position.y + section.size.y

func detail_text(screen: Control) -> String:
	var result: Array[String] = []
	for name in ["DetailTitleLabel", "CategoryLabel", "SharedProgressLabel", "TalentBuildLabel", "UpgradesLabel", "StatsLabel"]:
		result.append((screen.get_node("MainPanel/DetailPanel/DetailScroll/DetailContent/%s" % name) as Label).text)
	return "\n".join(result)

func expect(condition: bool, message: String) -> void:
	if condition: return
	failures.append(message)
	push_error(message)
