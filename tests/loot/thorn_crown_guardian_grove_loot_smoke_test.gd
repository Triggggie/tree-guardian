extends Node


const THORN_CROWN: BranchDefinition = preload(
	"res://resources/branches/thorn_crown_branch_definition.tres"
)
const GUARDIAN_GROVE_STAGE: StageDefinition = preload(
	"res://resources/stages/guardian_grove_stage.tres"
)
const GUARDIAN_GROVE_POOL: BranchSeedLootPoolDefinition = preload(
	"res://resources/loot/guardian_grove_branch_seed_loot_pool.tres"
)
const BARK_WARDEN: EnemyDefinition = preload(
	"res://resources/enemies/bark_warden_definition.tres"
)
const ANCIENT_BARK_COLOSSUS: EnemyDefinition = preload(
	"res://resources/enemies/ancient_bark_colossus_definition.tres"
)
const BARK_BEETLE: EnemyDefinition = preload(
	"res://resources/enemies/bark_beetle_definition.tres"
)
const BARK_RUNNER: EnemyDefinition = preload(
	"res://resources/enemies/bark_runner_definition.tres"
)


var failures: Array[String] = []
var storage_paths: Array[String] = []
var storage_path_prefix: String


func _ready() -> void:
	storage_path_prefix = "user://thorn_crown_guardian_grove_loot_%d_%d" % [
		OS.get_process_id(),
		Time.get_ticks_usec()
	]

	test_production_content()
	await test_production_pity_timeline_and_persistence()
	await test_actual_encounter_guarantees()
	await test_normal_enemy_guard()
	cleanup_storage_files()

	if failures.is_empty():
		print("THORN CROWN GUARDIAN GROVE LOOT SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print(
		"THORN CROWN GUARDIAN GROVE LOOT SMOKE TEST FAIL: %d failure(s)"
		% failures.size()
	)
	get_tree().quit(1)


func test_production_content() -> void:
	expect(
		GameContent.get_branch(&"thorn_crown") == THORN_CROWN,
		"Thorn Crown is not registered production content."
	)
	expect(THORN_CROWN.is_valid_definition(), "Thorn Crown is invalid.")
	expect(THORN_CROWN.is_legendary_branch(), "Thorn Crown is not Legendary.")
	expect(THORN_CROWN.get_legendary_tier() == 0, "Thorn Crown definition owns Tier state.")
	expect(
		GUARDIAN_GROVE_STAGE.get_branch_seed_loot_pool() == GUARDIAN_GROVE_POOL,
		"Guardian Grove does not reference its production Branch Seed pool."
	)
	expect(GUARDIAN_GROVE_POOL.is_valid_definition(), "Production pool is invalid.")
	expect(GUARDIAN_GROVE_POOL.entries.size() == 1, "Production pool size differs.")

	if GUARDIAN_GROVE_POOL.entries.size() == 1:
		var entry: BranchSeedLootEntryDefinition = GUARDIAN_GROVE_POOL.entries[0]
		expect(entry.is_valid_definition(), "Thorn Crown loot entry is invalid.")
		expect(entry.branch_definition == THORN_CROWN, "Loot entry has the wrong Branch.")
		expect(entry.get_branch_id() == &"thorn_crown", "Loot entry has the wrong ID.")
		expect(
			entry.get_legendary_tier() == BranchDefinition.LEGENDARY_TIER_1,
			"Loot entry has the wrong Legendary Tier."
		)
		expect(entry.get_legendary_tier_display_name() == "Tier I", "Loot Tier text differs.")
		expect(is_equal_approx(entry.weight, 1.0), "Thorn Crown loot weight differs.")

	expect(
		GUARDIAN_GROVE_POOL.get_entries_for_tier(1).size() == 1,
		"Tier I production entry count differs."
	)
	expect(
		GUARDIAN_GROVE_POOL.get_entries_for_tier(2).is_empty(),
		"Guardian Grove unexpectedly has a Tier II entry."
	)
	expect(
		GUARDIAN_GROVE_POOL.get_entries_for_tier(3).is_empty(),
		"Guardian Grove unexpectedly has a Tier III entry."
	)
	expect(
		GUARDIAN_GROVE_POOL.get_maximum_tier_for_encounter(
			BARK_WARDEN.encounter_rank_id
		) == BranchDefinition.LEGENDARY_TIER_1,
		"Bark Warden maximum eligible Tier differs."
	)
	expect(
		GUARDIAN_GROVE_POOL.get_maximum_tier_for_encounter(
			ANCIENT_BARK_COLOSSUS.encounter_rank_id
		) == BranchDefinition.LEGENDARY_TIER_1,
		"Ancient Bark Colossus maximum eligible Tier differs."
	)
	expect(
		GUARDIAN_GROVE_POOL.get_maximum_tier_for_encounter(
			BARK_BEETLE.encounter_rank_id
		) == BranchDefinition.LEGENDARY_TIER_NONE,
		"Normal enemy has a Legendary Tier limit."
	)

	assert_enemy_loot_values(BARK_WARDEN, &"miniboss", 0.05, 1)
	assert_enemy_loot_values(ANCIENT_BARK_COLOSSUS, &"boss", 0.15, 3)
	assert_enemy_loot_values(BARK_BEETLE, &"normal", 0.0, 0)
	assert_enemy_loot_values(BARK_RUNNER, &"normal", 0.0, 0)
	expect(GUARDIAN_GROVE_POOL.get_pity_threshold(1) == 12, "Tier I threshold differs.")
	expect(GUARDIAN_GROVE_POOL.get_pity_threshold(2) == 18, "Tier II threshold differs.")
	expect(GUARDIAN_GROVE_POOL.get_pity_threshold(3) == 24, "Tier III threshold differs.")

	var validation_errors: Array[String] = ContentValidator.validate_registry(
		GameContent.registry
	)
	expect(
		validation_errors.is_empty(),
		"Production content validation failed: %s" % "; ".join(validation_errors)
	)


func test_production_pity_timeline_and_persistence() -> void:
	var path: String = create_storage_path("timeline")
	var service: BranchSeedService = create_service(path)
	expect(
		not service.is_branch_seed_unlocked(&"thorn_crown"),
		"Registration alone unlocked Thorn Crown."
	)
	var failing_warden: EnemyDefinition = BARK_WARDEN.duplicate(true)
	var failing_colossus: EnemyDefinition = ANCIENT_BARK_COLOSSUS.duplicate(true)
	failing_warden.branch_seed_roll_chance = 0.0
	failing_colossus.branch_seed_roll_chance = 0.0
	var encounters: Array[EnemyDefinition] = [
		failing_warden,
		failing_colossus,
		failing_warden,
		failing_colossus,
		failing_warden,
		failing_colossus
	]
	var expected_pity: Array[int] = [1, 4, 5, 8, 9, 12]

	for index in range(encounters.size()):
		var dropped_id: StringName = service.process_enemy_defeat(
			encounters[index],
			GUARDIAN_GROVE_STAGE,
			Vector2.ZERO
		)
		expect(dropped_id == &"", "A pre-threshold encounter dropped Thorn Crown.")
		expect(
			service.get_pity_points(1) == expected_pity[index],
			"Production pity timeline differs at encounter %d." % (index + 1)
		)
		expect(
			not service.is_branch_seed_unlocked(&"thorn_crown"),
			"Thorn Crown unlocked before the guaranteed encounter."
		)

	var signal_order: Array[StringName] = []
	var dropped_signal_data: Array[Variant] = []
	service.branch_seed_unlocked.connect(
		func(_branch_id: StringName) -> void: signal_order.append(&"unlocked")
	)
	service.branch_seed_pity_changed.connect(
		func(_tier: int, _points: int, _threshold: int) -> void:
			signal_order.append(&"pity")
	)
	service.branch_seed_dropped.connect(
		func(branch_id: StringName, tier: int, enemy_id: StringName, position: Vector2) -> void:
			signal_order.append(&"dropped")
			dropped_signal_data.assign([branch_id, tier, enemy_id, position])
	)
	var drop_position := Vector2(321.0, 654.0)
	var guaranteed_id: StringName = service.process_enemy_defeat(
		failing_warden,
		GUARDIAN_GROVE_STAGE,
		drop_position
	)
	expect(guaranteed_id == &"thorn_crown", "Next eligible encounter was not guaranteed.")
	expect(service.is_branch_seed_unlocked(&"thorn_crown"), "Thorn Crown was not unlocked.")
	expect(service.get_pity_points(1) == 0, "Tier I pity did not reset after drop.")
	expect(
		signal_order == [&"unlocked", &"pity", &"dropped"],
		"Guaranteed drop signal order differs."
	)
	expect(
		dropped_signal_data == [&"thorn_crown", 1, &"bark_warden", drop_position],
		"Drop signal data differs."
	)

	signal_order.clear()
	expect(
		service.process_enemy_defeat(BARK_WARDEN, GUARDIAN_GROVE_STAGE, Vector2.ZERO)
		== &"",
		"Exhausted pool dropped a duplicate from Bark Warden."
	)
	expect(
		service.process_enemy_defeat(
			ANCIENT_BARK_COLOSSUS, GUARDIAN_GROVE_STAGE, Vector2.ZERO
		) == &"",
		"Exhausted pool dropped a duplicate from Ancient Bark Colossus."
	)
	expect(service.get_pity_points(1) == 0, "Exhausted pool changed Tier I pity.")
	expect(signal_order.is_empty(), "Exhausted pool emitted a Branch Seed signal.")

	var reloaded: BranchSeedService = create_service(path)
	expect(
		reloaded.is_branch_seed_unlocked(&"thorn_crown"),
		"Reload lost the Thorn Crown unlock."
	)
	expect(reloaded.get_pity_points(1) == 0, "Reload lost the Tier I pity reset.")
	var reload_signals: Array[StringName] = []
	reloaded.branch_seed_unlocked.connect(
		func(_branch_id: StringName) -> void: reload_signals.append(&"unlocked")
	)
	reloaded.branch_seed_pity_changed.connect(
		func(_tier: int, _points: int, _threshold: int) -> void:
			reload_signals.append(&"pity")
	)
	reloaded.branch_seed_dropped.connect(
		func(_branch_id: StringName, _tier: int, _enemy_id: StringName, _position: Vector2) -> void:
			reload_signals.append(&"dropped")
	)
	expect(
		reloaded.process_enemy_defeat(
			ANCIENT_BARK_COLOSSUS, GUARDIAN_GROVE_STAGE, Vector2.ZERO
		) == &"",
		"Reloaded exhausted pool dropped a duplicate."
	)
	expect(reloaded.get_pity_points(1) == 0, "Reloaded exhausted pool changed pity.")
	expect(reload_signals.is_empty(), "Reloaded exhausted pool emitted a signal.")

	service.queue_free()
	reloaded.queue_free()
	await get_tree().process_frame


func test_actual_encounter_guarantees() -> void:
	await assert_actual_guarantee(BARK_WARDEN, "warden_guarantee")
	await assert_actual_guarantee(ANCIENT_BARK_COLOSSUS, "colossus_guarantee")


func assert_actual_guarantee(
	enemy_definition: EnemyDefinition,
	path_suffix: String
) -> void:
	var service: BranchSeedService = create_service(create_storage_path(path_suffix))
	service.pity_points_by_tier[BranchDefinition.LEGENDARY_TIER_1] = (
		GUARDIAN_GROVE_POOL.get_pity_threshold(BranchDefinition.LEGENDARY_TIER_1)
	)
	expect(service.save_unlocks(), "Could not persist the guarantee fixture.")
	var dropped_id: StringName = service.process_enemy_defeat(
		enemy_definition,
		GUARDIAN_GROVE_STAGE,
		Vector2(12.0, 34.0)
	)
	expect(
		dropped_id == &"thorn_crown",
		"%s did not guarantee Thorn Crown at threshold." % enemy_definition.display_name
	)
	expect(
		service.is_branch_seed_unlocked(&"thorn_crown"),
		"%s did not unlock Thorn Crown." % enemy_definition.display_name
	)
	expect(
		service.get_pity_points(1) == 0,
		"%s did not reset Tier I pity." % enemy_definition.display_name
	)
	service.queue_free()
	await get_tree().process_frame


func test_normal_enemy_guard() -> void:
	var service: BranchSeedService = create_service(create_storage_path("normal_guard"))
	var signals: Array[StringName] = []
	service.branch_seed_unlocked.connect(
		func(_branch_id: StringName) -> void: signals.append(&"unlocked")
	)
	service.branch_seed_pity_changed.connect(
		func(_tier: int, _points: int, _threshold: int) -> void:
			signals.append(&"pity")
	)
	service.branch_seed_dropped.connect(
		func(_branch_id: StringName, _tier: int, _enemy_id: StringName, _position: Vector2) -> void:
			signals.append(&"dropped")
	)
	for normal_enemy in [BARK_BEETLE, BARK_RUNNER]:
		expect(
			service.process_enemy_defeat(
				normal_enemy as EnemyDefinition,
				GUARDIAN_GROVE_STAGE,
				Vector2.ZERO
			) == &"",
			"Normal enemy dropped Thorn Crown."
		)
	expect(service.get_pity_points(1) == 0, "Normal enemies changed Tier I pity.")
	expect(
		not service.is_branch_seed_unlocked(&"thorn_crown"),
		"Normal enemy unlocked Thorn Crown."
	)
	expect(signals.is_empty(), "Normal enemy emitted a Branch Seed signal.")
	service.queue_free()
	await get_tree().process_frame


func assert_enemy_loot_values(
	enemy_definition: EnemyDefinition,
	expected_rank: StringName,
	expected_chance: float,
	expected_pity: int
) -> void:
	expect(enemy_definition.encounter_rank_id == expected_rank, "Enemy rank differs.")
	expect(
		is_equal_approx(enemy_definition.branch_seed_roll_chance, expected_chance),
		"Enemy Branch Seed chance differs."
	)
	expect(
		enemy_definition.branch_seed_pity_points == expected_pity,
		"Enemy Branch Seed pity gain differs."
	)


func create_service(path: String) -> BranchSeedService:
	var service := BranchSeedService.new()
	service.initialize(path)
	add_child(service)
	return service


func create_storage_path(suffix: String) -> String:
	var path: String = "%s_%s.cfg" % [storage_path_prefix, suffix]
	storage_paths.append(path)
	remove_storage_file(path)
	return path


func cleanup_storage_files() -> void:
	for path in storage_paths:
		remove_storage_file(path)


func remove_storage_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
