extends Node


const STRENGTH_SCENE: PackedScene = preload("res://scenes/branches/strength_branch.tscn")
const STRENGTH_TREE: TalentTreeDefinition = preload("res://resources/talents/strength/strength_talent_tree.tres")

const EXPECTED_IDS: Array[StringName] = [
	&"sweeping_strike", &"cleaver", &"serrated_arc", &"reaping_sweep", &"whirling_bough",
	&"earthbreaker", &"fault_line", &"aftershock", &"worldroot_slam",
	&"rebuff", &"disruptor", &"staggering_blow", &"disruptive_arc", &"uproot",
	&"protector", &"hold_the_line", &"sentinel_reflex", &"last_bastion",
	&"marked_prey", &"executioner", &"cull_the_weak", &"finishing_rhythm", &"final_cut",
	&"relentless", &"pursuit", &"unbroken_combo", &"relentless_flurry"
]

const PATHS: Array[Array] = [
	[&"sweeping_strike", &"cleaver", &"serrated_arc", &"reaping_sweep", &"whirling_bough"],
	[&"sweeping_strike", &"earthbreaker", &"fault_line", &"aftershock", &"worldroot_slam"],
	[&"rebuff", &"disruptor", &"staggering_blow", &"disruptive_arc", &"uproot"],
	[&"rebuff", &"protector", &"hold_the_line", &"sentinel_reflex", &"last_bastion"],
	[&"marked_prey", &"executioner", &"cull_the_weak", &"finishing_rhythm", &"final_cut"],
	[&"marked_prey", &"relentless", &"pursuit", &"unbroken_combo", &"relentless_flurry"]
]

var failures: Array[String] = []


func _ready() -> void:
	test_content_graph()
	test_cycle_validation()
	await test_five_point_and_slot_builds()
	if failures.is_empty():
		print("STRENGTH FULL TALENT TREE SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("STRENGTH FULL TALENT TREE SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func test_content_graph() -> void:
	expect(STRENGTH_TREE.is_valid_definition(), "Full Strength TalentTreeDefinition is invalid.")
	expect(STRENGTH_TREE.talents.size() == 27, "Strength does not contain exactly 27 talents.")
	expect(STRENGTH_TREE.get_talent_ids() == EXPECTED_IDS, "Strength talent IDs or production order differ.")
	var level_counts: Dictionary = {2: 0, 4: 0, 7: 0, 10: 0, 14: 0}
	var edge_count: int = 0
	for talent in STRENGTH_TREE.talents:
		level_counts[talent.required_branch_level] = int(level_counts.get(talent.required_branch_level, 0)) + 1
		edge_count += talent.prerequisite_ids.size()
		expect(talent.talent_point_cost == 1, "Talent '%s' does not cost 1 TP." % talent.talent_id)
		expect(talent.tree_column >= 0 and talent.tree_row >= 0, "Talent '%s' lacks graph metadata." % talent.talent_id)
	expect(level_counts == {2: 3, 4: 6, 7: 6, 10: 6, 14: 6}, "Strength level layers are not 3/6/6/6/6.")
	expect(edge_count == 24, "Strength prerequisite edge count is not 24.")
	for pair in [[&"cleaver", &"earthbreaker"], [&"disruptor", &"protector"], [&"executioner", &"relentless"]]:
		var first: TalentDefinition = STRENGTH_TREE.get_talent_by_id(pair[0])
		var second: TalentDefinition = STRENGTH_TREE.get_talent_by_id(pair[1])
		expect(pair[1] in first.conflicting_ids and pair[0] in second.conflicting_ids, "Conflict pair '%s/%s' is not mutual." % pair)
	for path in PATHS:
		for index in range(1, path.size()):
			var talent: TalentDefinition = STRENGTH_TREE.get_talent_by_id(path[index])
			expect(talent.prerequisite_ids == [path[index - 1]], "Path prerequisite differs for '%s'." % path[index])


func test_cycle_validation() -> void:
	var first := TalentDefinition.new()
	first.talent_id = &"cycle_a"
	first.display_name = "Cycle A"
	first.prerequisite_ids = [&"cycle_b"]
	var second := TalentDefinition.new()
	second.talent_id = &"cycle_b"
	second.display_name = "Cycle B"
	second.prerequisite_ids = [&"cycle_a"]
	var tree := TalentTreeDefinition.new()
	tree.talent_tree_id = &"cycle_test"
	tree.talents = [first, second]
	expect(not tree.is_valid_definition(), "TalentTreeDefinition accepted a prerequisite cycle.")


func test_five_point_and_slot_builds() -> void:
	var fixture := Node2D.new()
	var service := BranchProgressService.new()
	fixture.add_child(service)
	add_child(fixture)
	var slot_one: CombatBranch = _create_strength(fixture, service, 1)
	var slot_two: CombatBranch = _create_strength(fixture, service, 2)
	var slot_three: CombatBranch = _create_strength(fixture, service, 3)
	var progress: BranchProgressRecord = service.get_progress(&"strength_branch")
	progress.branch_level = 14
	progress.total_talent_points_earned = 5
	service.synchronize_branch(slot_one)
	service.synchronize_branch(slot_two)
	service.synchronize_branch(slot_three)
	expect(not slot_two.purchase_talent(&"whirling_bough"), "Capstone purchase bypassed its prerequisite path.")
	for talent_id in PATHS[0]:
		expect(slot_one.purchase_talent(talent_id), "Slot 1 could not buy '%s'." % talent_id)
	expect(slot_one.get_available_talent_points() == 0 and slot_one.has_talent(&"whirling_bough"), "Five-point Cleaver build did not complete at 0 TP.")
	expect(not slot_one.purchase_talent(&"earthbreaker"), "Mutually exclusive Earthbreaker purchase succeeded.")
	for talent_id in PATHS[3]:
		expect(slot_three.purchase_talent(talent_id), "Slot 3 could not buy '%s'." % talent_id)
	expect(slot_three.has_talent(&"last_bastion") and not slot_one.has_talent(&"last_bastion"), "Slot-specific Strength builds leaked.")
	var split_build: Array[StringName] = [&"sweeping_strike", &"rebuff", &"marked_prey", &"protector", &"hold_the_line"]
	for talent_id in split_build:
		expect(slot_two.purchase_talent(talent_id), "Split build could not buy '%s'." % talent_id)
	expect(slot_two.get_available_talent_points() == 0 and slot_two.has_talent(&"hold_the_line"), "Valid five-point split build did not complete.")
	expect(slot_one.talent_effect_set != slot_three.talent_effect_set, "Strength instances share runtime talent state.")
	var stored: Dictionary = service.export_persistence_state()
	var loadouts: Array = stored.get("talent_loadouts", [])
	expect(loadouts.size() == 3, "Persistence export did not preserve three slot loadouts.")
	fixture.queue_free()
	await get_tree().process_frame


func _create_strength(parent: Node2D, service: BranchProgressService, slot_index: int) -> CombatBranch:
	var branch := STRENGTH_SCENE.instantiate() as CombatBranch
	branch.slot_index = slot_index
	branch.facing_side = 1
	branch.branch_progress_service = service
	branch.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(branch)
	(branch.get_node("CooldownTimer") as Timer).stop()
	return branch


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
