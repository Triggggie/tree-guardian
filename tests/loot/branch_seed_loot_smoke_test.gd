extends Node


const STRENGTH_DEFINITION: BranchDefinition = preload(
	"res://resources/branches/strength_branch_definition.tres"
)
const BLOSSOM_DEFINITION: BranchDefinition = preload(
	"res://resources/branches/blossom_branch_definition.tres"
)
const BARK_BEETLE_DEFINITION: EnemyDefinition = preload(
	"res://resources/enemies/bark_beetle_definition.tres"
)
const BARK_RUNNER_DEFINITION: EnemyDefinition = preload(
	"res://resources/enemies/bark_runner_definition.tres"
)
const BARK_BEETLE_SCENE: PackedScene = preload(
	"res://scenes/enemies/bark_beetle.tscn"
)


var failures: Array[String] = []
var storage_paths: Array[String] = []
var storage_path_prefix: String = ""
var unlock_events: Array[StringName] = []
var drop_events: Array[Dictionary] = []
var observed_drop_service: BranchSeedService


func _ready() -> void:
	storage_path_prefix = (
		"user://branch_seed_loot_smoke_test_%d_%d"
		% [OS.get_process_id(), Time.get_ticks_usec()]
	)

	test_production_definition_defaults()
	test_definition_validation()
	test_unlock_and_persistence()
	test_drop_processing()
	test_content_validation()
	await test_enemy_death_integration()
	await cleanup_test_state()

	if failures.is_empty():
		print("BRANCH SEED LOOT SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print(
		"BRANCH SEED LOOT SMOKE TEST FAIL: %d failure(s)"
		% failures.size()
	)
	get_tree().quit(1)


func test_production_definition_defaults() -> void:
	expect(
		STRENGTH_DEFINITION.is_standard_branch(),
		"Production Strength is not standard."
	)
	expect(
		BLOSSOM_DEFINITION.is_standard_branch(),
		"Production Blossom is not standard."
	)
	expect(
		BARK_BEETLE_DEFINITION.branch_seed_drops.is_empty(),
		"Production Bark Beetle unexpectedly has a Branch Seed drop."
	)
	expect(
		BARK_RUNNER_DEFINITION.branch_seed_drops.is_empty(),
		"Production Bark Runner unexpectedly has a Branch Seed drop."
	)


func test_definition_validation() -> void:
	var legendary_branch := create_legendary_branch(
		&"test_definition_legendary"
	)
	var valid_drop := create_drop(legendary_branch, 0.0)

	expect(
		legendary_branch.is_valid_definition(),
		"Synthetic legendary Branch is invalid."
	)
	expect(
		valid_drop.is_valid_definition(),
		"A disabled 0.0 legendary Branch Seed drop is invalid."
	)

	valid_drop.drop_chance = 1.0
	expect(
		valid_drop.is_valid_definition(),
		"A guaranteed 1.0 legendary Branch Seed drop is invalid."
	)

	var standard_drop := create_drop(
		STRENGTH_DEFINITION,
		1.0
	)
	expect(
		not standard_drop.is_valid_definition(),
		"A standard Branch Seed drop was accepted."
	)

	var missing_branch_drop := BranchSeedDropDefinition.new()
	missing_branch_drop.drop_chance = 1.0
	expect(
		not missing_branch_drop.is_valid_definition(),
		"A Branch Seed drop without a Branch was accepted."
	)

	var invalid_chance_drop := create_drop(
		legendary_branch,
		1.0
	)
	invalid_chance_drop.drop_chance = 1.1
	expect(
		not invalid_chance_drop.is_valid_definition(),
		"A Branch Seed drop chance above 1.0 was accepted."
	)

	var null_drop_enemy := create_enemy_with_drops([null])
	expect(
		not null_drop_enemy.is_valid_definition(),
		"EnemyDefinition accepted a null Branch Seed drop."
	)

	var standard_drop_enemy := create_enemy_with_drops([
		standard_drop
	])
	expect(
		not standard_drop_enemy.is_valid_definition(),
		"EnemyDefinition accepted a standard Branch Seed drop."
	)

	var duplicate_drop_enemy := create_enemy_with_drops([
		create_drop(legendary_branch, 0.25),
		create_drop(legendary_branch, 0.75),
	])
	expect(
		not duplicate_drop_enemy.is_valid_definition(),
		"EnemyDefinition accepted duplicate Branch Seed drop IDs."
	)


func test_unlock_and_persistence() -> void:
	var storage_path := create_storage_path("persistence")
	var service := create_service(storage_path)
	var legendary_branch := create_legendary_branch(
		&"test_persistent_legendary"
	)

	reset_signal_observation(service)
	expect(
		not service.unlock_branch_seed(STRENGTH_DEFINITION),
		"BranchSeeds unlocked standard Strength."
	)
	expect(
		not service.unlock_branch_seed(BLOSSOM_DEFINITION),
		"BranchSeeds unlocked standard Blossom."
	)
	expect(
		service.unlock_branch_seed(legendary_branch),
		"BranchSeeds did not unlock a valid legendary Branch."
	)
	expect(
		unlock_events == [&"test_persistent_legendary"],
		"A new unlock did not emit exactly one correct signal."
	)
	expect(
		service.is_branch_seed_unlocked(
			legendary_branch.branch_id
		),
		"A successful unlock is not available in memory."
	)
	expect(
		not service.unlock_branch_seed(legendary_branch),
		"A duplicate Branch Seed unlock succeeded."
	)
	expect(
		unlock_events.size() == 1,
		"A duplicate unlock emitted another signal."
	)

	var config := ConfigFile.new()
	expect(
		config.load(storage_path) == OK,
		"The Branch Seed test ConfigFile was not saved."
	)
	expect(
		int(config.get_value(
			BranchSeedService.SAVE_SECTION,
			BranchSeedService.SAVE_VERSION_KEY,
			0
		)) == BranchSeedService.SAVE_VERSION,
		"The Branch Seed save version is incorrect."
	)
	var saved_ids = config.get_value(
		BranchSeedService.SAVE_SECTION,
		BranchSeedService.SAVE_IDS_KEY,
		PackedStringArray()
	)
	expect(
		saved_ids.size() == 1
		and String(saved_ids[0]) == "test_persistent_legendary",
		"The ConfigFile did not store exactly the stable Branch ID."
	)

	var returned_ids: Array[StringName] = (
		service.get_unlocked_branch_seed_ids()
	)
	returned_ids.append(&"mutated_copy")
	expect(
		not service.is_branch_seed_unlocked(&"mutated_copy"),
		"The returned Branch Seed ID array exposed mutable state."
	)

	var reloaded_service := BranchSeedService.new()
	expect(
		reloaded_service.initialize(storage_path),
		"A second BranchSeeds instance could not reload the save."
	)
	add_child(reloaded_service)
	expect(
		reloaded_service.get_unlocked_branch_seed_ids()
		== [&"test_persistent_legendary"],
		"A second BranchSeeds instance loaded different IDs."
	)

	service.queue_free()
	reloaded_service.queue_free()


func test_drop_processing() -> void:
	var zero_service := create_service(
		create_storage_path("zero_drop")
	)
	var zero_branch := create_legendary_branch(
		&"test_zero_drop"
	)
	var zero_enemy := create_enemy_with_drops([
		create_drop(zero_branch, 0.0)
	])

	reset_signal_observation(zero_service)
	expect(
		zero_service.process_enemy_defeat(
			zero_enemy,
			Vector2(1.0, 2.0)
		) == &"",
		"A 0.0 Branch Seed drop succeeded."
	)
	expect(
		unlock_events.is_empty() and drop_events.is_empty(),
		"A 0.0 drop emitted a Branch Seed signal."
	)

	var drop_service := create_service(
		create_storage_path("authored_order")
	)
	var first_branch := create_legendary_branch(
		&"test_first_drop"
	)
	var second_branch := create_legendary_branch(
		&"test_second_drop"
	)
	var drop_enemy := create_enemy_with_drops([
		create_drop(first_branch, 1.0),
		create_drop(second_branch, 1.0),
	])
	var drop_position := Vector2(123.0, -45.0)

	reset_signal_observation(drop_service)
	expect(
		drop_service.process_enemy_defeat(
			drop_enemy,
			drop_position
		) == first_branch.branch_id,
		"Guaranteed drops did not resolve in authored order."
	)
	expect(
		drop_service.is_branch_seed_unlocked(first_branch.branch_id),
		"The first guaranteed Branch Seed was not unlocked."
	)
	expect(
		not drop_service.is_branch_seed_unlocked(
			second_branch.branch_id
		),
		"One enemy unlocked more than one new Branch Seed."
	)
	expect(
		unlock_events == [first_branch.branch_id],
		"A guaranteed drop emitted incorrect unlock signals."
	)
	expect(
		drop_events.size() == 1,
		"A guaranteed drop did not emit exactly one drop signal."
	)

	if drop_events.size() == 1:
		var drop_event: Dictionary = drop_events[0]
		expect(
			drop_event.get(&"branch_id") == first_branch.branch_id,
			"Drop event contains the wrong Branch ID."
		)
		expect(
			drop_event.get(&"enemy_id") == drop_enemy.enemy_id,
			"Drop event contains the wrong Enemy ID."
		)
		expect(
			drop_event.get(&"world_position") == drop_position,
			"Drop event contains the wrong world position."
		)
		expect(
			bool(drop_event.get(&"was_unlocked", false)),
			"Seed was not unlocked when the drop event fired."
		)

	var repeat_service := create_service(
		create_storage_path("repeat_drop")
	)
	var repeat_branch := create_legendary_branch(
		&"test_repeat_drop"
	)
	var repeat_enemy := create_enemy_with_drops([
		create_drop(repeat_branch, 1.0)
	])

	reset_signal_observation(repeat_service)
	expect(
		repeat_service.process_enemy_defeat(
			repeat_enemy,
			Vector2.ZERO
		) == repeat_branch.branch_id,
		"Initial repeat-check drop did not succeed."
	)
	expect(
		repeat_service.process_enemy_defeat(
			repeat_enemy,
			Vector2.ZERO
		) == &"",
		"An already unlocked seed dropped again."
	)
	expect(
		unlock_events.size() == 1 and drop_events.size() == 1,
		"An already unlocked seed emitted another signal."
	)

	zero_service.queue_free()
	drop_service.queue_free()
	repeat_service.queue_free()


func test_content_validation() -> void:
	var legendary_branch := create_legendary_branch(
		&"test_registered_legendary"
	)
	var valid_enemy := create_enemy_with_drops([
		create_drop(legendary_branch, 1.0)
	])
	var valid_registry := create_registry(
		[legendary_branch],
		[valid_enemy]
	)
	var valid_errors: Array[String] = (
		ContentValidator.validate_registry(valid_registry)
	)
	expect(
		valid_errors.is_empty(),
		"ContentValidator rejected a registered legendary drop: %s"
		% [valid_errors]
	)

	var unregistered_branch := create_legendary_branch(
		&"test_unregistered_legendary"
	)
	var unregistered_enemy := create_enemy_with_drops([
		create_drop(unregistered_branch, 1.0)
	])
	var unregistered_errors := ContentValidator.validate_registry(
		create_registry([], [unregistered_enemy])
	)
	expect_error_contains(
		unregistered_errors,
		"unregistered Branch 'test_unregistered_legendary'",
		"ContentValidator did not report an unregistered drop Branch."
	)

	var standard_enemy := create_enemy_with_drops([
		create_drop(STRENGTH_DEFINITION, 1.0)
	])
	var standard_errors := ContentValidator.validate_registry(
		create_registry([STRENGTH_DEFINITION], [standard_enemy])
	)
	expect_error_contains(
		standard_errors,
		"references standard Branch 'strength_branch'",
		"ContentValidator did not report a standard drop Branch."
	)

	var missing_enemy := create_enemy_with_drops([
		BranchSeedDropDefinition.new()
	])
	var missing_errors := ContentValidator.validate_registry(
		create_registry([], [missing_enemy])
	)
	expect_error_contains(
		missing_errors,
		"has no Branch definition",
		"ContentValidator did not report a missing drop Branch."
	)

	var duplicate_enemy := create_enemy_with_drops([
		create_drop(legendary_branch, 0.5),
		create_drop(legendary_branch, 0.5),
	])
	var duplicate_errors := ContentValidator.validate_registry(
		create_registry([legendary_branch], [duplicate_enemy])
	)
	expect_error_contains(
		duplicate_errors,
		"Duplicate Branch Seed drop",
		"ContentValidator did not report duplicate drop IDs."
	)


func test_enemy_death_integration() -> void:
	var service := create_service(
		create_storage_path("enemy_death")
	)
	var legendary_branch := create_legendary_branch(
		&"test_enemy_death_drop"
	)
	var enemy_definition := create_enemy_with_drops([
		create_drop(legendary_branch, 1.0)
	])
	var fixture := Node2D.new()
	fixture.name = "BranchSeedEnemyDeathFixture"
	add_child(fixture)

	var tracker := EnemyTracker.new()
	tracker.name = "EnemyTracker"
	fixture.add_child(tracker)
	var lane_registry := LaneRegistry.new()
	lane_registry.name = "LaneRegistry"
	fixture.add_child(lane_registry)
	var target_tree := Node2D.new()
	target_tree.name = "TreeTarget"
	target_tree.add_to_group("tree")
	fixture.add_child(target_tree)

	var enemy: Node = BARK_BEETLE_SCENE.instantiate()
	expect(
		bool(enemy.call(
			"configure_from_definition",
			enemy_definition
		)),
		"Real Bark Beetle rejected the test EnemyDefinition."
	)
	enemy.set("branch_seed_service", service)
	fixture.add_child(enemy)
	(enemy as Node2D).global_position = Vector2(321.0, 87.0)

	reset_signal_observation(service)
	enemy.call("die")
	enemy.call("die")

	expect(
		unlock_events == [legendary_branch.branch_id],
		"Real Bark Beetle death did not unlock exactly one seed."
	)
	expect(
		drop_events.size() == 1,
		"Repeated Bark Beetle die() emitted more than one drop."
	)

	if drop_events.size() == 1:
		var event: Dictionary = drop_events[0]
		expect(
			event.get(&"branch_id") == legendary_branch.branch_id,
			"Bark Beetle death emitted the wrong Branch ID."
		)
		expect(
			event.get(&"enemy_id") == enemy_definition.enemy_id,
			"Bark Beetle death emitted the wrong Enemy ID."
		)
		expect(
			event.get(&"world_position") == Vector2(321.0, 87.0),
			"Bark Beetle death emitted the wrong position."
		)

	fixture.queue_free()
	service.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func create_legendary_branch(
	branch_id: StringName
) -> BranchDefinition:
	var branch := (
		STRENGTH_DEFINITION.duplicate(true)
		as BranchDefinition
	)
	branch.branch_id = branch_id
	branch.display_name = "Test Legendary Branch"
	branch.category_id = BranchDefinition.CATEGORY_LEGENDARY
	return branch


func create_drop(
	branch: BranchDefinition,
	drop_chance: float
) -> BranchSeedDropDefinition:
	var branch_seed_drop := BranchSeedDropDefinition.new()
	branch_seed_drop.branch_definition = branch
	branch_seed_drop.drop_chance = drop_chance
	return branch_seed_drop


func create_enemy_with_drops(
	drops: Array
) -> EnemyDefinition:
	var enemy := (
		BARK_BEETLE_DEFINITION.duplicate(true)
		as EnemyDefinition
	)
	var typed_drops: Array[BranchSeedDropDefinition] = []

	for drop in drops:
		typed_drops.append(drop as BranchSeedDropDefinition)

	enemy.branch_seed_drops = typed_drops
	return enemy


func create_registry(
	branches: Array,
	enemies: Array
) -> ContentRegistry:
	var registry := ContentRegistry.new()

	for branch in branches:
		registry.branches.append(branch as BranchDefinition)

	for enemy in enemies:
		registry.enemies.append(enemy as EnemyDefinition)

	return registry


func create_storage_path(
	suffix: String
) -> String:
	var storage_path := "%s_%s.cfg" % [
		storage_path_prefix,
		suffix
	]
	storage_paths.append(storage_path)
	remove_storage_file(storage_path, false)
	return storage_path


func create_service(
	storage_path: String
) -> BranchSeedService:
	var service := BranchSeedService.new()
	expect(
		service.initialize(storage_path),
		"BranchSeeds could not initialize '%s'." % storage_path
	)
	add_child(service)
	return service


func reset_signal_observation(
	service: BranchSeedService
) -> void:
	unlock_events.clear()
	drop_events.clear()
	observed_drop_service = service

	if not service.branch_seed_unlocked.is_connected(
		_on_branch_seed_unlocked
	):
		service.branch_seed_unlocked.connect(
			_on_branch_seed_unlocked
		)

	if not service.branch_seed_dropped.is_connected(
		_on_branch_seed_dropped
	):
		service.branch_seed_dropped.connect(
			_on_branch_seed_dropped
		)


func _on_branch_seed_unlocked(
	branch_id: StringName
) -> void:
	unlock_events.append(branch_id)


func _on_branch_seed_dropped(
	branch_id: StringName,
	enemy_id: StringName,
	world_position: Vector2
) -> void:
	drop_events.append({
		&"branch_id": branch_id,
		&"enemy_id": enemy_id,
		&"world_position": world_position,
		&"was_unlocked": (
			is_instance_valid(observed_drop_service)
			and observed_drop_service.is_branch_seed_unlocked(
				branch_id
			)
		),
	})


func expect_error_contains(
	errors: Array[String],
	expected_fragment: String,
	failure_message: String
) -> void:
	for validation_error in errors:
		if validation_error.contains(expected_fragment):
			return

	expect(false, "%s Errors: %s" % [failure_message, errors])


func cleanup_test_state() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	for storage_path in storage_paths:
		remove_storage_file(storage_path, true)

	for storage_path in storage_paths:
		expect(
			not FileAccess.file_exists(storage_path),
			"Test save file remains at '%s'." % storage_path
		)

	expect(
		get_tree().get_nodes_in_group("enemies").is_empty(),
		"Branch Seed loot test left an enemy group member."
	)


func remove_storage_file(
	storage_path: String,
	report_failure: bool
) -> void:
	if not FileAccess.file_exists(storage_path):
		return

	var remove_error: Error = DirAccess.remove_absolute(
		ProjectSettings.globalize_path(storage_path)
	)

	if report_failure:
		expect(
			remove_error == OK,
			"Could not remove test save '%s' (error %d)."
			% [storage_path, remove_error]
		)


func expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	failures.append(message)
	push_error(message)
