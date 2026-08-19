extends Node


const TEST_PATH: String = "user://talent_respec_smoke_test.cfg"
const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")

var failures: Array[String] = []


func _ready() -> void:
	cleanup_file()
	BranchLoadout.clear_runtime_loadout_for_testing()
	BranchProgress.clear_runtime_progress_for_testing()
	expect(SaveGame.initialize(TEST_PATH), "Talent respec save initialize failed.")
	await run_test()
	cleanup_file()
	if failures.is_empty():
		print("TALENT RESPEC SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("TALENT RESPEC SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func run_test() -> void:
	var world: Node = MAIN_WORLD_SCENE.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var slot_one: CombatBranch = find_branch(world, &"standard_slot_1")
	var slot_three: CombatBranch = find_branch(world, &"standard_slot_3")
	if not is_instance_valid(slot_one) or not is_instance_valid(slot_three):
		expect(false, "Strength respec fixtures were not created.")
		return
	level_to(slot_one, 35)
	var cleaver_path: Array[StringName] = [
		&"sweeping_strike", &"cleaver", &"serrated_arc",
		&"reaping_sweep", &"whirling_bough"
	]
	for talent_id in cleaver_path:
		expect(slot_one.purchase_talent(talent_id), "Could not buy %s." % talent_id)
	expect(slot_three.purchase_talent(&"rebuff"), "Other-slot fixture purchase failed.")
	expect(slot_one.get_available_talent_points() == 0, "Five-talent build did not spend its earned budget.")

	var reason: String = slot_one.get_talent_refund_reason(&"sweeping_strike")
	expect(
		not slot_one.can_refund_talent(&"sweeping_strike")
		and reason == BranchProgressService.REFUND_REASON_PURCHASED_DESCENDANTS,
		"Root refund was not blocked by a stable descendant reason."
	)
	var talent_screen := world.get_node("UI/TalentScreen") as Control
	talent_screen.call("open_screen")
	talent_screen.call("select_branch", slot_one)
	talent_screen.call("select_talent", &"sweeping_strike")
	var action_button := talent_screen.get_node(
		"MarginContainer/MainPanel/MainVBox/ContentHBox/TalentDetailPanel/TalentDetailVBox/PurchaseTalentButton"
	) as Button
	var requirements_label := talent_screen.get_node(
		"MarginContainer/MainPanel/MainVBox/ContentHBox/TalentDetailPanel/TalentDetailVBox/TalentRequirementsLabel"
	) as Label
	expect(
		action_button.disabled and action_button.text == "REFUND LOCKED"
		and requirements_label.text.contains("Locked by purchased descendants"),
		"Talent Screen did not explain the blocked refund."
	)
	talent_screen.call("select_talent", &"whirling_bough")
	expect(
		not action_button.disabled and action_button.text == "REFUND TALENT",
		"Purchased leaf did not expose REFUND TALENT."
	)

	expect(slot_one.refund_talent(&"whirling_bough"), "Leaf refund failed.")
	expect(
		not slot_one.has_talent(&"whirling_bough")
		and slot_one.get_available_talent_points() == 1,
		"Leaf refund did not remove the talent and return its point."
	)
	expect(slot_one.refund_talent(&"reaping_sweep"), "New leaf refund failed.")
	expect(
		not slot_one.can_purchase_talent(&"whirling_bough")
		and slot_one.get_talent_status_text(&"whirling_bough") == "REQUIRES PREVIOUS TALENT",
		"Prerequisite state did not recompute after refund."
	)
	expect(
		not slot_one.can_purchase_talent(&"earthbreaker"),
		"Conflict state changed while Cleaver remained purchased."
	)

	expect(SaveGame.save_now(), "Refunded build save failed.")
	expect(slot_one.purchase_talent(&"reaping_sweep"), "Refund mutation setup failed.")
	expect(SaveGame.load_now(), "Refunded build reload failed.")
	expect(
		not slot_one.has_talent(&"reaping_sweep")
		and slot_one.has_talent(&"serrated_arc"),
		"Refunded state did not persist."
	)

	expect(slot_one.reset_talent_build(), "Current-slot full reset failed.")
	expect(
		slot_one.get_available_talent_points() == 5
		and not has_any_purchased_talent(slot_one),
		"Full reset did not return all points or clear the current build."
	)
	expect(
		slot_three.has_talent(&"rebuff")
		and slot_three.get_available_talent_points() == 4,
		"Full reset changed another slot using the same archetype."
	)
	expect(
		slot_one.branch_level == 35 and slot_three.branch_level == 35,
		"Full reset changed shared archetype progress."
	)
	expect(SaveGame.save_now(), "Reset build save failed.")
	expect(slot_one.purchase_talent(&"marked_prey"), "Reset mutation setup failed.")
	expect(SaveGame.load_now(), "Reset build reload failed.")
	expect(
		not has_any_purchased_talent(slot_one)
		and slot_three.has_talent(&"rebuff"),
		"Reset build or other-slot state did not persist."
	)

	expect(slot_one.purchase_talent(&"sweeping_strike"), "Reset confirmation fixture failed.")
	talent_screen.call("select_branch", slot_one)
	var reset_button := talent_screen.get_node(
		"MarginContainer/MainPanel/MainVBox/ContentHBox/TalentDetailPanel/TalentDetailVBox/ResetTalentsButton"
	) as Button
	var confirmation := talent_screen.get_node("ResetTalentsConfirmation") as ConfirmationDialog
	expect(
		not reset_button.disabled and reset_button.text.contains("SLOT 1 BUILD"),
		"Reset control did not identify the current slot build."
	)
	talent_screen.call("request_reset_talents")
	expect(confirmation.visible, "Full reset confirmation did not open.")
	confirmation.hide()
	talent_screen.call("confirm_reset_talents")
	expect(not has_any_purchased_talent(slot_one), "Confirmed UI reset did not clear the build.")

	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func level_to(branch: CombatBranch, target_level: int) -> void:
	while branch.branch_level < target_level:
		branch.add_xp(branch.get_safe_xp_required_per_level())


func find_branch(world: Node, slot_id: StringName) -> CombatBranch:
	for node in get_tree().get_nodes_in_group("combat_branch"):
		if world.is_ancestor_of(node) and (node as CombatBranch).get_slot_id() == slot_id:
			return node as CombatBranch
	return null


func has_any_purchased_talent(branch: CombatBranch) -> bool:
	for talent_id in branch.get_talent_ids():
		if branch.has_talent(talent_id):
			return true
	return false


func cleanup_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
