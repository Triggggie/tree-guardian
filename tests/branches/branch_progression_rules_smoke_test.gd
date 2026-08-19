extends Node


const STRENGTH_SCENE: PackedScene = preload(
	"res://scenes/branches/strength_branch.tscn"
)

const SAMPLE_LEVELS: Array[int] = [
	1,
	10,
	25,
	50,
	100,
	200,
	375,
	500
]

const EXPECTED_NEXT_XP: Array[int] = [
	4,
	36,
	118,
	297,
	754,
	1919,
	4480,
	6605
]

const EXPECTED_CUMULATIVE_XP: Array[int] = [
	0,
	148,
	1232,
	6249,
	31860,
	162635,
	713193,
	1402714
]

const TALENT_TEST_LEVELS: Array[int] = [
	1,
	2,
	4,
	5,
	10,
	20,
	35,
	55,
	80,
	110,
	150,
	200,
	275,
	375,
	500
]

const EXPECTED_TALENT_POINTS: Array[int] = [
	0,
	1,
	1,
	2,
	3,
	4,
	5,
	6,
	7,
	8,
	9,
	10,
	11,
	12,
	12
]


var failures: Array[String] = []


func _ready() -> void:
	test_xp_curve()
	test_talent_budget()
	await test_runtime_multi_level_and_restore()
	test_production_enemy_rewards()

	if failures.is_empty():
		print("BRANCH PROGRESSION RULES SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print(
		"BRANCH PROGRESSION RULES SMOKE TEST FAIL: %d failure(s)"
		% failures.size()
	)
	get_tree().quit(1)


func test_xp_curve() -> void:
	var previous_requirement: int = 0
	for level in range(1, 1001):
		var requirement: int = (
			BranchProgressionRules.get_xp_required_for_level(level)
		)
		expect(
			requirement > 0,
			"Level %d has a non-positive XP requirement."
			% level
		)
		expect(
			requirement >= previous_requirement,
			"XP requirement decreased at Level %d."
			% level
		)
		previous_requirement = requirement

	for sample_index in range(SAMPLE_LEVELS.size()):
		var level: int = SAMPLE_LEVELS[sample_index]
		expect(
			BranchProgressionRules.get_xp_required_for_level(level)
			== EXPECTED_NEXT_XP[sample_index],
			"Level %d XP requirement changed."
			% level
		)
		expect(
			BranchProgressionRules.get_cumulative_xp_for_level(level)
			== EXPECTED_CUMULATIVE_XP[sample_index],
			"Cumulative XP to Level %d changed."
			% level
		)


func test_talent_budget() -> void:
	for test_index in range(TALENT_TEST_LEVELS.size()):
		var level: int = TALENT_TEST_LEVELS[test_index]
		expect(
			BranchProgressionRules.get_total_talent_points_for_level(level)
			== EXPECTED_TALENT_POINTS[test_index],
			"Level %d has the wrong earned Talent Point budget."
			% level
		)

	expect(
		BranchProgressionRules.get_talent_point_levels()
		== [2, 5, 10, 20, 35, 55, 80, 110, 150, 200, 275, 375],
		"The production Talent Point milestone list changed."
	)


func test_runtime_multi_level_and_restore() -> void:
	var fixture := Node2D.new()
	var progress_service := BranchProgressService.new()
	fixture.add_child(progress_service)
	add_child(fixture)

	var branch := STRENGTH_SCENE.instantiate() as CombatBranch
	branch.process_mode = Node.PROCESS_MODE_DISABLED
	branch.slot_index = 1
	branch.branch_progress_service = progress_service
	fixture.add_child(branch)
	await get_tree().process_frame

	var overflow_xp: int = 7
	branch.add_xp(
		BranchProgressionRules.get_cumulative_xp_for_level(10)
		+ overflow_xp
	)
	expect(
		branch.branch_level == 10
		and branch.current_xp == overflow_xp,
		"A large XP grant did not cross multiple levels with overflow."
	)
	expect(
		branch.total_talent_points_earned == 3,
		"Multi-level XP did not award the Level 2, 5, and 10 milestones."
	)

	for grant_index in range(10):
		branch.add_xp(2)
	expect(
		branch.branch_level == 10
		and branch.current_xp == overflow_xp + 20,
		"Repeated 2-XP grants still produced constant-cost levels."
	)

	var strength_definition: BranchDefinition = (
		GameContent.get_branch(&"strength_branch")
	)
	expect(
		progress_service.restore_persistence_state({
			"records": [{
				"branch_id": "strength_branch",
				"branch_level": 500,
				"current_xp": 17,
				"total_talent_points_earned": 5,
				"upgrade_levels": {}
			}],
			"talent_loadouts": []
		}),
		"A high-level saved Branch record did not restore."
	)
	var restored: BranchProgressRecord = progress_service.get_progress(
		&"strength_branch"
	)
	expect(
		is_instance_valid(strength_definition)
		and restored != null
		and restored.branch_level == 500
		and restored.current_xp == 17
		and restored.total_talent_points_earned == 12,
		"Save compatibility did not preserve level/XP and derive the new TP budget."
	)
	expect(
		branch.branch_level == 500
		and branch.get_safe_xp_required_per_level() == 6605,
		"A registered Branch did not synchronize to restored V2 progression."
	)

	var second_branch := STRENGTH_SCENE.instantiate() as CombatBranch
	second_branch.process_mode = Node.PROCESS_MODE_DISABLED
	second_branch.slot_index = 3
	second_branch.branch_progress_service = progress_service
	fixture.add_child(second_branch)
	await get_tree().process_frame
	expect(
		branch.get_available_talent_points() == 12
		and second_branch.get_available_talent_points() == 12,
		"Two slots did not receive the same shared 12-point budget."
	)
	expect(
		branch.purchase_talent(&"sweeping_strike"),
		"Slot 1 could not spend from the restored 12-point budget."
	)
	expect(
		branch.get_available_talent_points() == 11
		and second_branch.get_available_talent_points() == 12,
		"A slot-specific talent purchase changed another slot's availability."
	)
	expect(
		branch.refund_talent(&"sweeping_strike")
		and branch.get_available_talent_points() == 12,
		"Talent refund did not restore slot-specific availability."
	)

	fixture.queue_free()
	await fixture.tree_exited


func test_production_enemy_rewards() -> void:
	var bark_beetle: EnemyDefinition = GameContent.get_enemy(&"bark_beetle")
	var bark_runner: EnemyDefinition = GameContent.get_enemy(&"bark_runner")
	var bark_warden: EnemyDefinition = GameContent.get_enemy(&"bark_warden")
	var colossus: EnemyDefinition = GameContent.get_enemy(
		&"ancient_bark_colossus"
	)
	expect(
		bark_beetle.experience_reward == 1
		and bark_runner.experience_reward == 1
		and bark_warden.experience_reward == 8
		and colossus.experience_reward == 20,
		"Production enemy XP rewards changed unexpectedly."
	)


func expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures.append(message)
	push_error(message)
