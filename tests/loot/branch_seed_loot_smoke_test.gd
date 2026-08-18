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
const BARK_WARDEN_DEFINITION: EnemyDefinition = preload(
	"res://resources/enemies/bark_warden_definition.tres"
)
const BARK_WARDEN_SCENE: PackedScene = preload(
	"res://scenes/enemies/bark_warden.tscn"
)
const GUARDIAN_GROVE_STAGE: StageDefinition = preload(
	"res://resources/stages/guardian_grove_stage.tres"
)
const THORN_CROWN_DEFINITION: BranchDefinition = preload(
	"res://resources/branches/thorn_crown_branch_definition.tres"
)


var failures: Array[String] = []
var storage_paths: Array[String] = []
var storage_path_prefix: String


func _ready() -> void:
	storage_path_prefix = "user://branch_seed_loot_smoke_%d_%d" % [
		OS.get_process_id(),
		Time.get_ticks_usec()
	]

	test_production_defaults()
	await test_unlock_persistence_and_duplicate()
	await test_acquired_tier_progression_and_prestige_reset()
	await test_legacy_and_corrupt_tier_loading()
	await test_stage_pool_drop_and_signal_order()
	await test_save_rollback()
	await test_enemy_death_hook()
	cleanup_storage_files()

	if failures.is_empty():
		print("BRANCH SEED LOOT SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print("BRANCH SEED LOOT SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func test_production_defaults() -> void:
	expect(STRENGTH_DEFINITION.is_standard_branch(), "Strength is not standard.")
	expect(BLOSSOM_DEFINITION.is_standard_branch(), "Blossom is not standard.")
	expect(BARK_BEETLE_DEFINITION.is_normal_enemy(), "Bark Beetle is not normal.")
	expect(
		BARK_BEETLE_DEFINITION.branch_seed_roll_chance == 0.0
		and BARK_BEETLE_DEFINITION.branch_seed_pity_points == 0,
		"Normal Bark Beetle has Branch Seed loot values."
	)
	expect(
		GUARDIAN_GROVE_STAGE.branch_seed_loot_pool.entries.size() == 1
		and GUARDIAN_GROVE_STAGE.branch_seed_loot_pool.entries[0].branch_definition
		== THORN_CROWN_DEFINITION
		and GUARDIAN_GROVE_STAGE.branch_seed_loot_pool.entries[0].get_legendary_tier()
		== BranchDefinition.LEGENDARY_TIER_1,
		"Production Guardian Grove pool does not contain exactly Thorn Crown Tier I."
	)


func test_unlock_persistence_and_duplicate() -> void:
	var path: String = create_storage_path("persistence")
	var service: BranchSeedService = create_service(path)
	var branch: BranchDefinition = create_legendary_branch(&"persistent_seed")
	var unlock_events: Array[StringName] = []
	service.branch_seed_unlocked.connect(
		func(branch_id: StringName) -> void: unlock_events.append(branch_id)
	)

	expect(not service.unlock_branch_seed(STRENGTH_DEFINITION), "Standard seed unlocked.")
	expect(service.unlock_branch_seed(branch), "Legendary seed did not unlock.")
	expect(not service.unlock_branch_seed(branch), "Duplicate seed unlock succeeded.")
	expect(unlock_events == [branch.branch_id], "Unlock signal count/order is wrong.")

	var reloaded: BranchSeedService = create_service(path)
	expect(
		reloaded.is_branch_seed_unlocked(branch.branch_id),
		"Persistent seed was not reloaded."
	)

	service.queue_free()
	reloaded.queue_free()
	await get_tree().process_frame


func test_acquired_tier_progression_and_prestige_reset() -> void:
	var path: String = create_storage_path("tiers")
	var service: BranchSeedService = create_service(path)
	expect(service.acquire_branch_seed(THORN_CROWN_DEFINITION, 1), "Tier I acquisition failed.")
	expect(service.acquire_branch_seed(THORN_CROWN_DEFINITION, 2), "Tier II did not replace Tier I.")
	expect(
		not service.acquire_branch_seed(THORN_CROWN_DEFINITION, 1),
		"Tier I downgraded Tier II."
	)
	expect(service.acquire_branch_seed(THORN_CROWN_DEFINITION, 3), "Tier III did not replace Tier II.")
	expect(
		not service.acquire_branch_seed(THORN_CROWN_DEFINITION, 2),
		"Tier II downgraded Tier III."
	)
	expect(service.get_acquired_tier(&"thorn_crown") == 3, "Tier III ownership was not retained.")

	var runtime := CombatBranch.new()
	runtime.branch_id = &"thorn_crown"
	runtime.branch_definition = THORN_CROWN_DEFINITION
	runtime.branch_seed_service = service
	expect(runtime.get_acquired_legendary_tier() == 3, "Runtime could not resolve Tier III.")
	runtime.free()

	var reloaded: BranchSeedService = create_service(path)
	expect(reloaded.get_acquired_tier(&"thorn_crown") == 3, "Save/load lost acquired Tier.")
	reloaded.pity_points_by_tier[1] = 7
	expect(reloaded.save_unlocks(), "Pity fixture save failed.")
	expect(reloaded.clear_for_prestige(), "Prestige Branch Seed reset failed.")
	expect(
		reloaded.get_acquired_tier(&"thorn_crown") == 0
		and reloaded.get_pity_points(1) == 0,
		"Prestige did not clear ownership and pity."
	)
	service.queue_free()
	reloaded.queue_free()
	await get_tree().process_frame


func test_legacy_and_corrupt_tier_loading() -> void:
	var legacy_path: String = create_storage_path("legacy")
	var legacy := ConfigFile.new()
	legacy.set_value("branch_seed_unlocks", "version", 2)
	legacy.set_value(
		"branch_seed_unlocks",
		"branch_ids",
		PackedStringArray(["thorn_crown", "unknown_legacy"])
	)
	legacy.set_value("branch_seed_pity", "tier_1_points", 4)
	expect(legacy.save(legacy_path) == OK, "Legacy fixture save failed.")
	var migrated: BranchSeedService = create_service(legacy_path)
	expect(migrated.get_acquired_tier(&"thorn_crown") == 1, "Legacy Thorn Crown did not migrate to Tier I.")
	expect(migrated.get_acquired_tier(&"unknown_legacy") == 1, "Unknown legacy ID was not retained safely.")
	expect(migrated.get_pity_points(1) == 4, "Version 2 pity was not migrated.")

	var corrupt_path: String = create_storage_path("corrupt")
	var corrupt := ConfigFile.new()
	corrupt.set_value("branch_seed_unlocks", "version", 3)
	corrupt.set_value("branch_seed_unlocks", "acquired_tiers", {
		"thorn_crown": 99,
		"bad_type": "III",
		"valid_unknown": 2
	})
	expect(corrupt.save(corrupt_path) == OK, "Corrupt fixture save failed.")
	var sanitized: BranchSeedService = create_service(corrupt_path)
	expect(sanitized.get_acquired_tier(&"thorn_crown") == 0, "Corrupt Tier did not fail safely.")
	expect(sanitized.get_acquired_tier(&"valid_unknown") == 2, "Valid unknown ID did not load safely.")
	migrated.queue_free()
	sanitized.queue_free()
	await get_tree().process_frame


func test_stage_pool_drop_and_signal_order() -> void:
	var service: BranchSeedService = create_service(create_storage_path("drop"))
	var branch: BranchDefinition = create_legendary_branch(&"stage_pool_seed")
	var stage: StageDefinition = create_stage_with_branches([branch])
	var enemy: EnemyDefinition = BARK_WARDEN_DEFINITION.duplicate(true)
	enemy.branch_seed_roll_chance = 1.0
	var events: Array[StringName] = []
	service.branch_seed_unlocked.connect(
		func(_branch_id: StringName) -> void: events.append(&"unlock")
	)
	service.branch_seed_pity_changed.connect(
		func(_tier: int, _points: int, _threshold: int) -> void:
			events.append(&"pity")
	)
	service.branch_seed_dropped.connect(
		func(_branch_id: StringName, _tier: int, _enemy_id: StringName, _position: Vector2) -> void:
			events.append(&"drop")
	)

	var dropped_id: StringName = service.process_enemy_defeat(
		enemy,
		stage,
		Vector2(11.0, 22.0)
	)
	expect(dropped_id == branch.branch_id, "Stage pool returned wrong seed.")
	expect(events == [&"unlock", &"drop"], "Drop signal order is wrong.")
	expect(
		service.process_enemy_defeat(enemy, stage, Vector2.ZERO) == &"",
		"Unavailable duplicate seed dropped again."
	)

	service.queue_free()
	await get_tree().process_frame


func test_save_rollback() -> void:
	var service: BranchSeedService = create_service(
		"user://missing_branch_seed_directory/save.cfg"
	)
	var branch: BranchDefinition = create_legendary_branch(&"rollback_seed")
	var unlock_count: Array[int] = [0]
	service.branch_seed_unlocked.connect(
		func(_branch_id: StringName) -> void: unlock_count[0] += 1
	)
	expect(not service.unlock_branch_seed(branch), "Failed save reported an unlock.")
	expect(
		not service.is_branch_seed_unlocked(branch.branch_id),
		"Failed save did not rollback unlock state."
	)
	expect(unlock_count[0] == 0, "Failed save emitted a success signal.")
	service.queue_free()
	await get_tree().process_frame


func test_enemy_death_hook() -> void:
	var service: BranchSeedService = create_service(create_storage_path("death"))
	var branch: BranchDefinition = create_legendary_branch(&"death_seed")
	var stage: StageDefinition = create_stage_with_branches([branch])
	var enemy_definition: EnemyDefinition = BARK_WARDEN_DEFINITION.duplicate(true)
	enemy_definition.branch_seed_roll_chance = 1.0
	var drop_count: Array[int] = [0]
	service.branch_seed_dropped.connect(
		func(_branch_id: StringName, _tier: int, _enemy_id: StringName, _position: Vector2) -> void:
			drop_count[0] += 1
	)

	var fixture := Node2D.new()
	fixture.name = "BranchSeedDeathFixture"
	add_child(fixture)
	var tracker := EnemyTracker.new()
	fixture.add_child(tracker)
	var lanes := LaneRegistry.new()
	fixture.add_child(lanes)
	var target := Node2D.new()
	target.add_to_group("tree")
	fixture.add_child(target)

	var enemy: Node = BARK_WARDEN_SCENE.instantiate()
	expect(
		bool(enemy.call("configure_from_definition", enemy_definition)),
		"Warden rejected EnemyDefinition."
	)
	expect(
		bool(enemy.call("configure_stage_context", stage)),
		"Warden rejected StageDefinition."
	)
	enemy.set("branch_seed_service", service)
	fixture.add_child(enemy)
	enemy.call("die")
	enemy.call("die")
	expect(drop_count[0] == 1, "Repeated die() processed loot more than once.")

	var normal_enemy: Node = BARK_WARDEN_SCENE.instantiate()
	normal_enemy.call("configure_from_definition", BARK_BEETLE_DEFINITION)
	normal_enemy.call("configure_stage_context", stage)
	normal_enemy.set("branch_seed_service", service)
	fixture.add_child(normal_enemy)
	normal_enemy.call("die")
	expect(drop_count[0] == 1, "Normal enemy death processed Branch Seed loot.")

	var cleanup_branch: BranchDefinition = create_legendary_branch(&"cleanup_seed")
	var cleanup_stage: StageDefinition = create_stage_with_branches([cleanup_branch])
	var queued_enemy: Node = BARK_WARDEN_SCENE.instantiate()
	queued_enemy.call("configure_from_definition", enemy_definition)
	queued_enemy.call("configure_stage_context", cleanup_stage)
	queued_enemy.set("branch_seed_service", service)
	fixture.add_child(queued_enemy)
	queued_enemy.queue_free()
	await get_tree().process_frame
	expect(drop_count[0] == 1, "queue_free() without death processed loot.")

	var retry_enemy: Node = BARK_WARDEN_SCENE.instantiate()
	retry_enemy.call("configure_from_definition", enemy_definition)
	retry_enemy.call("configure_stage_context", cleanup_stage)
	retry_enemy.set("branch_seed_service", service)
	fixture.add_child(retry_enemy)
	retry_enemy.call("stop_combat")
	retry_enemy.queue_free()
	await get_tree().process_frame
	expect(drop_count[0] == 1, "Retry-style cleanup processed loot.")

	fixture.queue_free()
	service.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func create_legendary_branch(branch_id: StringName) -> BranchDefinition:
	var branch: BranchDefinition = STRENGTH_DEFINITION.duplicate(true)
	branch.branch_id = branch_id
	branch.display_name = "Test Legendary Branch"
	branch.category_id = BranchDefinition.CATEGORY_LEGENDARY
	branch.legendary_tier = BranchDefinition.LEGENDARY_TIER_1
	return branch


func create_stage_with_branches(branches: Array) -> StageDefinition:
	var pool := BranchSeedLootPoolDefinition.new()
	pool.loot_pool_id = &"test_pool"
	pool.display_name = "Test Pool"
	pool.miniboss_maximum_tier = 1
	pool.boss_maximum_tier = 1
	for branch_value in branches:
		var entry := BranchSeedLootEntryDefinition.new()
		entry.branch_definition = branch_value as BranchDefinition
		entry.weight = 1.0
		pool.entries.append(entry)

	var stage: StageDefinition = GUARDIAN_GROVE_STAGE.duplicate(true)
	stage.branch_seed_loot_pool = pool
	return stage


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
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
