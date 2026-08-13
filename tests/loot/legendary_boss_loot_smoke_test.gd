extends Node


const STRENGTH: BranchDefinition = preload(
	"res://resources/branches/strength_branch_definition.tres"
)
const BLOSSOM: BranchDefinition = preload(
	"res://resources/branches/blossom_branch_definition.tres"
)
const BEETLE: EnemyDefinition = preload(
	"res://resources/enemies/bark_beetle_definition.tres"
)
const RUNNER: EnemyDefinition = preload(
	"res://resources/enemies/bark_runner_definition.tres"
)
const WARDEN: EnemyDefinition = preload(
	"res://resources/enemies/bark_warden_definition.tres"
)
const COLOSSUS: EnemyDefinition = preload(
	"res://resources/enemies/ancient_bark_colossus_definition.tres"
)
const STAGE: StageDefinition = preload(
	"res://resources/stages/guardian_grove_stage.tres"
)
const THORN_CROWN: BranchDefinition = preload(
	"res://resources/branches/thorn_crown_branch_definition.tres"
)
const SCHEDULE: SubstageWaveScheduleDefinition = preload(
	"res://resources/wave_schedules/guardian_grove_standard_schedule.tres"
)


var failures: Array[String] = []
var storage_paths: Array[String] = []
var path_prefix: String


func _ready() -> void:
	path_prefix = "user://legendary_boss_loot_%d_%d" % [
		OS.get_process_id(),
		Time.get_ticks_usec()
	]

	test_legendary_tiers()
	test_loot_pool_and_content_validation()
	test_encounter_ranks()
	await test_tier_selection_and_pity()
	await test_save_migration()
	test_schedule_and_stage_context()
	cleanup_storage_files()

	if failures.is_empty():
		print("LEGENDARY BOSS LOOT SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print("LEGENDARY BOSS LOOT SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func test_legendary_tiers() -> void:
	expect(STRENGTH.is_standard_branch(), "Strength is not standard.")
	expect(BLOSSOM.is_standard_branch(), "Blossom is not standard.")
	expect(STRENGTH.get_legendary_tier() == 0, "Strength is not Tier 0.")
	expect(BLOSSOM.get_legendary_tier() == 0, "Blossom is not Tier 0.")
	expect(STRENGTH.get_legendary_tier_display_name() == "", "Standard Tier is visible.")

	var standard_tier_one: BranchDefinition = STRENGTH.duplicate(true)
	standard_tier_one.legendary_tier = 1
	expect(not standard_tier_one.is_valid_definition(), "Standard Tier I was valid.")

	var legendary_tier_zero: BranchDefinition = create_branch(&"tier_zero", 0)
	expect(not legendary_tier_zero.is_valid_definition(), "Legendary Tier 0 was valid.")

	var expected_names: Dictionary = {1: "Tier I", 2: "Tier II", 3: "Tier III"}
	for tier in range(1, 4):
		var branch: BranchDefinition = create_branch(StringName("tier_%d" % tier), tier)
		expect(branch.is_valid_definition(), "Legendary Tier %d is invalid." % tier)
		expect(branch.is_legendary_tier(tier), "Tier helper rejected Tier %d." % tier)
		expect(
			branch.get_legendary_tier_display_name() == expected_names[tier],
			"Tier %d display text differs." % tier
		)
		var entry := create_entry(branch, 1.0)
		expect(
			entry.get_legendary_tier_display_name()
			== branch.get_legendary_tier_display_name(),
			"Loot entry duplicated or changed Tier display text."
		)

	var outside_tier: BranchDefinition = create_branch(&"outside", 4)
	expect(not outside_tier.is_valid_definition(), "Tier outside 1-3 was valid.")
	expect(
		STRENGTH.branch_id == &"strength_branch"
		and STRENGTH.category_id == BranchDefinition.CATEGORY_STANDARD
		and STRENGTH.legendary_tier == 0,
		"Shared Strength Resource was mutated."
	)


func test_loot_pool_and_content_validation() -> void:
	var production_pool: BranchSeedLootPoolDefinition = STAGE.branch_seed_loot_pool
	expect(production_pool.is_valid_definition(), "Guardian Grove pool is invalid.")
	expect(production_pool.entries.size() == 1, "Guardian Grove pool size differs.")
	if production_pool.entries.size() == 1:
		var production_entry: BranchSeedLootEntryDefinition = production_pool.entries[0]
		expect(production_entry.branch_definition == THORN_CROWN, "Production entry is not Thorn Crown.")
		expect(production_entry.get_legendary_tier() == 1, "Production entry is not Tier I.")
		expect(is_equal_approx(production_entry.weight, 1.0), "Production entry weight differs.")
	expect(production_pool.miniboss_maximum_tier == 1, "Miniboss maximum is not I.")
	expect(production_pool.boss_maximum_tier == 1, "Boss maximum is not I.")
	expect(production_pool.get_pity_threshold(1) == 12, "Tier I threshold differs.")
	expect(production_pool.get_pity_threshold(2) == 18, "Tier II threshold differs.")
	expect(production_pool.get_pity_threshold(3) == 24, "Tier III threshold differs.")

	var branches: Array[BranchDefinition] = [
		create_branch(&"pool_tier_1", 1),
		create_branch(&"pool_tier_2", 2),
		create_branch(&"pool_tier_3", 3)
	]
	var pool: BranchSeedLootPoolDefinition = create_pool(branches, 3, 3)
	expect(pool.is_valid_definition(), "Valid Tier I-III pool is invalid.")
	var copied_entries: Array[BranchSeedLootEntryDefinition] = pool.get_entries_for_tier(1)
	copied_entries.clear()
	expect(pool.get_entries_for_tier(1).size() == 1, "Tier entries exposed internal Array.")

	var duplicate_pool: BranchSeedLootPoolDefinition = create_pool(
		[branches[0], branches[0]], 1, 1
	)
	expect(not duplicate_pool.is_valid_definition(), "Duplicate pool Branch ID was valid.")
	var null_pool: BranchSeedLootPoolDefinition = create_pool([], 1, 1)
	null_pool.entries.append(null)
	expect(not null_pool.is_valid_definition(), "Null pool entry was valid.")
	var standard_pool: BranchSeedLootPoolDefinition = create_pool([], 1, 1)
	standard_pool.entries.append(create_entry(STRENGTH, 1.0))
	expect(not standard_pool.is_valid_definition(), "Standard Branch pool entry was valid.")
	var zero_weight := create_entry(branches[0], 1.0)
	zero_weight.weight = 0.0
	expect(not zero_weight.is_valid_definition(), "Zero loot weight was valid.")
	var negative_weight := create_entry(branches[0], 1.0)
	negative_weight.weight = -1.0
	expect(not negative_weight.is_valid_definition(), "Negative loot weight was valid.")
	var high_tier_pool: BranchSeedLootPoolDefinition = create_pool([branches[2]], 1, 2)
	expect(not high_tier_pool.is_valid_definition(), "Entry above boss maximum was valid.")
	var inverted_pool: BranchSeedLootPoolDefinition = create_pool([], 2, 1)
	expect(not inverted_pool.is_valid_definition(), "Boss maximum below miniboss was valid.")

	var stage: StageDefinition = STAGE.duplicate(true)
	stage.branch_seed_loot_pool = create_pool([branches[0]], 1, 1)
	var unregistered_registry: ContentRegistry = create_registry([], [stage])
	var unregistered_errors: Array[String] = ContentValidator.validate_registry(
		unregistered_registry
	)
	expect_error_contains(
		unregistered_errors,
		"unregistered Branch 'pool_tier_1'",
		"ContentValidator accepted an unregistered loot Branch."
	)
	var registered_registry: ContentRegistry = create_registry([branches[0]], [stage])
	var registered_errors: Array[String] = ContentValidator.validate_registry(
		registered_registry
	)
	expect_no_error_contains(
		registered_errors,
		"loot pool",
		"ContentValidator rejected registered legendary loot content."
	)


func test_encounter_ranks() -> void:
	var definitions: Array[EnemyDefinition] = [BEETLE, RUNNER, WARDEN, COLOSSUS]
	var expected: Array[Dictionary] = [
		{"rank": &"normal", "chance": 0.0, "pity": 0},
		{"rank": &"normal", "chance": 0.0, "pity": 0},
		{"rank": &"miniboss", "chance": 0.05, "pity": 1},
		{"rank": &"boss", "chance": 0.15, "pity": 3}
	]
	for index in range(definitions.size()):
		var definition: EnemyDefinition = definitions[index]
		expect(GameContent.get_enemy(definition.enemy_id) == definition, "Enemy is unregistered.")
		expect(definition.encounter_rank_id == expected[index]["rank"], "Rank differs.")
		expect(is_equal_approx(definition.branch_seed_roll_chance, expected[index]["chance"]), "Chance differs.")
		expect(definition.branch_seed_pity_points == expected[index]["pity"], "Pity differs.")
		var enemy: Node = definition.enemy_scene.instantiate()
		expect(enemy.has_node("HealthComponent"), "Enemy scene lacks HealthComponent.")
		expect(enemy.has_node("AttackComponent"), "Enemy scene lacks AttackComponent.")
		expect(enemy.has_node("MovementComponent"), "Enemy scene lacks MovementComponent.")
		enemy.free()

	expect(BEETLE.is_normal_enemy() and RUNNER.is_normal_enemy(), "Normal helpers failed.")
	expect(WARDEN.is_miniboss(), "Miniboss helper failed.")
	expect(COLOSSUS.is_boss(), "Boss helper failed.")
	var invalid_normal: EnemyDefinition = BEETLE.duplicate(true)
	invalid_normal.branch_seed_roll_chance = 0.1
	expect(not invalid_normal.is_valid_definition(), "Normal enemy with chance was valid.")
	var invalid_rank: EnemyDefinition = BEETLE.duplicate(true)
	invalid_rank.encounter_rank_id = &"unknown"
	expect(not invalid_rank.is_valid_definition(), "Unknown encounter rank was valid.")
	var negative_equipment_chance: EnemyDefinition = BEETLE.duplicate(true)
	negative_equipment_chance.equipment_drop_chance = -0.01
	expect(not negative_equipment_chance.is_valid_definition(), "Negative equipment chance was valid.")
	var excessive_equipment_chance: EnemyDefinition = BEETLE.duplicate(true)
	excessive_equipment_chance.equipment_drop_chance = 1.01
	expect(not excessive_equipment_chance.is_valid_definition(), "Equipment chance above one was valid.")
	var invalid_equipment_rarity: EnemyDefinition = BEETLE.duplicate(true)
	invalid_equipment_rarity.equipment_minimum_rarity_id = &"mythic"
	expect(not invalid_equipment_rarity.is_valid_definition(), "Invalid equipment minimum rarity was valid.")
	var negative_item_level_bonus: EnemyDefinition = BEETLE.duplicate(true)
	negative_item_level_bonus.equipment_item_level_bonus = -1
	expect(not negative_item_level_bonus.is_valid_definition(), "Negative equipment Item Level bonus was valid.")


func test_tier_selection_and_pity() -> void:
	var tier_1: BranchDefinition = create_branch(&"selection_tier_1", 1)
	var tier_2: BranchDefinition = create_branch(&"selection_tier_2", 2)
	var tier_3: BranchDefinition = create_branch(&"selection_tier_3", 3)
	var stage: StageDefinition = create_stage([tier_1, tier_2, tier_3], 1, 3)
	var miniboss: EnemyDefinition = WARDEN.duplicate(true)
	miniboss.branch_seed_roll_chance = 1.0
	var boss: EnemyDefinition = COLOSSUS.duplicate(true)
	boss.branch_seed_roll_chance = 1.0

	var miniboss_service: BranchSeedService = create_service(create_path("miniboss"), 11)
	expect(
		miniboss_service.process_enemy_defeat(miniboss, stage, Vector2.ZERO)
		== tier_1.branch_id,
		"Miniboss did not select Tier I."
	)
	miniboss_service.queue_free()

	var tier_2_alternate: BranchDefinition = create_branch(
		&"selection_tier_2_alternate", 2
	)
	var tier_two_stage: StageDefinition = create_stage(
		[tier_1, tier_2, tier_2_alternate], 1, 2
	)
	var boss_service: BranchSeedService = create_service(create_path("boss_tier_2"), 22)
	var first_tier_two_drop: StringName = boss_service.process_enemy_defeat(
		boss, tier_two_stage, Vector2.ZERO
	)
	expect(
		first_tier_two_drop in [tier_2.branch_id, tier_2_alternate.branch_id],
		"Weighted selection escaped the selected Tier II."
	)
	var second_tier_two_drop: StringName = boss_service.process_enemy_defeat(
		boss, tier_two_stage, Vector2.ZERO
	)
	expect(
		second_tier_two_drop in [tier_2.branch_id, tier_2_alternate.branch_id]
		and second_tier_two_drop != first_tier_two_drop,
		"Boss did not choose the remaining locked Tier II entry."
	)
	expect(
		boss_service.process_enemy_defeat(boss, tier_two_stage, Vector2.ZERO)
		== tier_1.branch_id,
		"Boss did not fall back from exhausted Tier II to Tier I."
	)
	var exhausted_pity: Dictionary = boss_service.get_all_pity_points()
	expect(
		boss_service.process_enemy_defeat(boss, tier_two_stage, Vector2.ZERO) == &""
		and boss_service.get_all_pity_points() == exhausted_pity,
		"An exhausted pool rolled or changed pity."
	)
	boss_service.queue_free()

	var tier_three_service: BranchSeedService = create_service(create_path("boss_tier_3"), 33)
	expect(
		tier_three_service.process_enemy_defeat(boss, stage, Vector2.ZERO)
		== tier_3.branch_id,
		"Boss did not prefer Tier III."
	)
	expect(
		tier_three_service.process_enemy_defeat(boss, stage, Vector2.ZERO)
		== tier_2.branch_id,
		"Boss did not fall back to the next available tier."
	)
	tier_three_service.queue_free()

	var pity_branch: BranchDefinition = create_branch(&"pity_tier_1", 1)
	var pity_stage: StageDefinition = create_stage([pity_branch], 1, 1)
	pity_stage.branch_seed_loot_pool.tier_1_pity_threshold = 3
	var failing_miniboss: EnemyDefinition = WARDEN.duplicate(true)
	failing_miniboss.branch_seed_roll_chance = 0.0
	var pity_path: String = create_path("pity")
	var pity_service: BranchSeedService = create_service(pity_path, 44)
	pity_service.pity_points_by_tier[2] = 7
	pity_service.pity_points_by_tier[3] = 9
	var pity_signal_count: Array[int] = [0]
	pity_service.branch_seed_pity_changed.connect(
		func(_tier: int, _points: int, _threshold: int) -> void:
			pity_signal_count[0] += 1
	)
	for _index in range(3):
		expect(
			pity_service.process_enemy_defeat(failing_miniboss, pity_stage, Vector2.ZERO)
			== &"",
			"Failed pity roll unexpectedly dropped a seed."
		)
	expect(pity_service.get_pity_points(1) == 3, "Tier I pity did not clamp.")
	expect(pity_signal_count[0] == 3, "Pity signal did not fire once per change.")
	var boss_pity_branch: BranchDefinition = create_branch(&"boss_pity_tier_2", 2)
	var boss_pity_stage: StageDefinition = create_stage([boss_pity_branch], 1, 2)
	var failing_boss: EnemyDefinition = COLOSSUS.duplicate(true)
	failing_boss.branch_seed_roll_chance = 0.0
	var boss_pity_service: BranchSeedService = create_service(
		create_path("boss_pity"), 45
	)
	boss_pity_service.process_enemy_defeat(
		failing_boss, boss_pity_stage, Vector2.ZERO
	)
	expect(
		boss_pity_service.get_pity_points(2) == 3,
		"Failed boss roll did not add three Tier II pity points."
	)
	var reloaded: BranchSeedService = create_service(pity_path, 55)
	expect(reloaded.get_pity_points(1) == 3, "Persisted pity was not loaded.")
	expect(reloaded.get_pity_points(2) == 7, "Tier II pity was not isolated.")
	expect(reloaded.get_pity_points(3) == 9, "Tier III pity was not isolated.")
	expect(
		reloaded.process_enemy_defeat(failing_miniboss, pity_stage, Vector2.ZERO)
		== pity_branch.branch_id,
		"Threshold encounter was not guaranteed."
	)
	expect(reloaded.get_pity_points(1) == 0, "Tier I pity did not reset.")
	expect(reloaded.get_pity_points(2) == 7, "Tier I drop changed Tier II pity.")
	expect(reloaded.get_pity_points(3) == 9, "Tier I drop changed Tier III pity.")
	var copied_pity: Dictionary = reloaded.get_all_pity_points()
	copied_pity[2] = 999
	expect(reloaded.get_pity_points(2) == 7, "Pity Dictionary exposed internal state.")
	var before_empty: Dictionary = reloaded.get_all_pity_points()
	var empty_stage: StageDefinition = create_stage([], 1, 1)
	reloaded.process_enemy_defeat(COLOSSUS, empty_stage, Vector2.ZERO)
	expect(reloaded.get_all_pity_points() == before_empty, "Empty pool changed pity.")
	reloaded.process_enemy_defeat(BEETLE, pity_stage, Vector2.ZERO)
	expect(reloaded.get_all_pity_points() == before_empty, "Normal enemy changed pity.")
	var rollback_service: BranchSeedService = create_service(
		"user://missing_legendary_boss_loot_directory/save.cfg", 88
	)
	var rollback_signal_count: Array[int] = [0]
	rollback_service.branch_seed_pity_changed.connect(
		func(_tier: int, _points: int, _threshold: int) -> void:
			rollback_signal_count[0] += 1
	)
	rollback_service.process_enemy_defeat(
		failing_miniboss, pity_stage, Vector2.ZERO
	)
	expect(
		rollback_service.get_pity_points(1) == 0,
		"Failed pity save did not rollback the counter."
	)
	expect(
		rollback_signal_count[0] == 0,
		"Failed pity save emitted a success signal."
	)

	pity_service.queue_free()
	reloaded.queue_free()
	boss_pity_service.queue_free()
	rollback_service.queue_free()
	await get_tree().process_frame


func test_save_migration() -> void:
	var path: String = create_path("migration")
	var config := ConfigFile.new()
	config.set_value("branch_seed_unlocks", "version", 1)
	config.set_value(
		"branch_seed_unlocks",
		"branch_ids",
		PackedStringArray(["legacy_a", "legacy_b", "legacy_a", ""])
	)
	expect(config.save(path) == OK, "Could not create v1 migration fixture.")
	var service: BranchSeedService = create_service(path, 66)
	expect(
		service.get_unlocked_branch_seed_ids() == [&"legacy_a", &"legacy_b"],
		"Version 1 unlock IDs were not migrated safely."
	)
	expect(
		service.get_pity_points(1) == 0
		and service.get_pity_points(2) == 0
		and service.get_pity_points(3) == 0,
		"Migrated pity did not start at zero."
	)
	var migrated := ConfigFile.new()
	migrated.load(path)
	expect(
		int(migrated.get_value("branch_seed_unlocks", "version", 0)) == 2,
		"Version 1 save was not rewritten as version 2."
	)
	var reloaded: BranchSeedService = create_service(path, 77)
	expect(
		reloaded.get_unlocked_branch_seed_ids() == service.get_unlocked_branch_seed_ids(),
		"Migrated version 2 reload differs."
	)
	service.queue_free()
	reloaded.queue_free()
	await get_tree().process_frame


func test_schedule_and_stage_context() -> void:
	expect(SCHEDULE.is_valid_definition(), "Production schedule is invalid.")
	expect(SCHEDULE.get_wave_for_number(49).wave_id == &"standard_bark_beetle", "Wave 49 changed.")
	expect(SCHEDULE.get_wave_for_number(50).wave_id == &"guardian_grove_miniboss", "Wave 50 is wrong.")
	expect(SCHEDULE.get_wave_for_number(51).wave_id == &"standard_bark_beetle", "Wave 51 changed.")
	expect(SCHEDULE.get_wave_for_number(99).wave_id == &"standard_bark_beetle", "Wave 99 changed.")
	expect(SCHEDULE.get_wave_for_number(100).wave_id == &"guardian_grove_boss", "Wave 100 is wrong.")
	for substage in STAGE.substages:
		expect(substage.wave_schedule == SCHEDULE, "Substage does not use shared schedule.")
		expect(substage.get_wave_for_index(49).wave_id == &"guardian_grove_miniboss", "Substage Wave 50 differs.")
		expect(substage.get_wave_for_index(99).wave_id == &"guardian_grove_boss", "Substage Wave 100 differs.")

	var miniboss_wave: WaveDefinition = GameContent.get_wave(
		&"guardian_grove", &"guardian_grove_miniboss"
	)
	var boss_wave: WaveDefinition = GameContent.get_wave(
		&"guardian_grove", &"guardian_grove_boss"
	)
	expect(miniboss_wave.get_enemy_ids() == [&"bark_warden"], "Miniboss Wave content differs.")
	expect(boss_wave.get_enemy_ids() == [&"ancient_bark_colossus"], "Boss Wave content differs.")
	expect(miniboss_wave.get_total_enemies_per_side(999) == 1, "Miniboss count scales.")
	expect(boss_wave.get_total_enemies_per_side(999) == 1, "Boss count scales.")

	var request := EnemySpawnRequest.new(WARDEN, 1, 120.0, 1.0, STAGE, 50)
	expect(request.is_valid_request(), "Stage-aware Warden request is invalid.")
	expect(request.stage_definition == STAGE, "Request lost exact Stage instance.")
	var enemy: Node = WARDEN.enemy_scene.instantiate()
	enemy.call("configure_from_definition", WARDEN)
	enemy.call("configure_stage_context", request.stage_definition, request.global_wave)
	expect(enemy.get("stage_definition") == STAGE, "Enemy lost exact Stage instance.")
	expect(int(enemy.get("reward_global_wave")) == 50, "Enemy lost global Wave reward context.")
	enemy.free()


func create_branch(branch_id: StringName, tier: int) -> BranchDefinition:
	var branch: BranchDefinition = STRENGTH.duplicate(true)
	branch.branch_id = branch_id
	branch.display_name = "Synthetic Legendary %s" % branch_id
	branch.category_id = BranchDefinition.CATEGORY_LEGENDARY
	branch.legendary_tier = tier
	return branch


func create_entry(
	branch: BranchDefinition,
	weight: float
) -> BranchSeedLootEntryDefinition:
	var entry := BranchSeedLootEntryDefinition.new()
	entry.branch_definition = branch
	entry.weight = weight
	return entry


func create_pool(
	branches: Array,
	miniboss_maximum: int,
	boss_maximum: int
) -> BranchSeedLootPoolDefinition:
	var pool := BranchSeedLootPoolDefinition.new()
	pool.loot_pool_id = &"synthetic_pool"
	pool.display_name = "Synthetic Pool"
	pool.miniboss_maximum_tier = miniboss_maximum
	pool.boss_maximum_tier = boss_maximum
	for branch_value in branches:
		pool.entries.append(create_entry(branch_value as BranchDefinition, 1.0))
	return pool


func create_stage(
	branches: Array,
	miniboss_maximum: int,
	boss_maximum: int
) -> StageDefinition:
	var stage: StageDefinition = STAGE.duplicate(true)
	stage.branch_seed_loot_pool = create_pool(
		branches, miniboss_maximum, boss_maximum
	)
	return stage


func create_registry(
	branches: Array,
	stages: Array
) -> ContentRegistry:
	var registry := ContentRegistry.new()
	for branch_value in branches:
		registry.branches.append(branch_value as BranchDefinition)
	for enemy_definition in [BEETLE, RUNNER, WARDEN, COLOSSUS]:
		registry.enemies.append(enemy_definition as EnemyDefinition)
	for stage_value in stages:
		registry.stages.append(stage_value as StageDefinition)
	return registry


func create_service(path: String, seed_value: int) -> BranchSeedService:
	var service := BranchSeedService.new()
	service.random_number_generator.seed = seed_value
	service.initialize(path)
	service.random_number_generator.seed = seed_value
	add_child(service)
	return service


func create_path(suffix: String) -> String:
	var path: String = "%s_%s.cfg" % [path_prefix, suffix]
	storage_paths.append(path)
	remove_file(path)
	return path


func cleanup_storage_files() -> void:
	for path in storage_paths:
		remove_file(path)


func remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func expect_error_contains(
	errors: Array[String],
	fragment: String,
	message: String
) -> void:
	for error in errors:
		if fragment in error:
			return
	expect(false, message)


func expect_no_error_contains(
	errors: Array[String],
	fragment: String,
	message: String
) -> void:
	for error in errors:
		if fragment in error:
			expect(false, "%s Error: %s" % [message, error])


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
