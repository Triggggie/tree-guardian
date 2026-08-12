extends Node


class MockEnemy:
	extends Node2D

	var damage_taken: float = 0.0

	func _ready() -> void:
		add_to_group("enemies")

	func is_targetable() -> bool:
		return true

	func take_damage(amount: float, _source: Node = null) -> void:
		damage_taken += amount


const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")


var failures: Array[String] = []
var storage_path: String
var original_seed_storage_path: String


func _ready() -> void:
	var loadout := get_node("/root/BranchLoadout") as BranchLoadoutService
	var progress := get_node("/root/BranchProgress") as BranchProgressService
	var seeds := get_node("/root/BranchSeeds") as BranchSeedService
	original_seed_storage_path = seeds.storage_path
	storage_path = "user://live_branch_switch_%d_%d.cfg" % [
		OS.get_process_id(), Time.get_ticks_usec()
	]
	remove_storage_file()
	seeds.initialize(storage_path)
	loadout.clear_runtime_loadout_for_testing()
	progress.clear_runtime_progress_for_testing()
	await run_test(loadout, seeds)
	loadout.clear_runtime_loadout_for_testing()
	progress.clear_runtime_progress_for_testing()
	seeds.initialize(original_seed_storage_path)
	remove_storage_file()

	if failures.is_empty():
		print("LIVE BRANCH LOADOUT SWITCH SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print(
		"LIVE BRANCH LOADOUT SWITCH SMOKE TEST FAIL: %d failure(s)"
		% failures.size()
	)
	get_tree().quit(1)


func run_test(
	loadout: BranchLoadoutService,
	seeds: BranchSeedService
) -> void:
	var world: Node = MAIN_WORLD_SCENE.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame

	var manager: Node = world.get_node("WaveManager")
	var director := world.get_node("WaveDirector") as WaveDirector
	var tree_node: Node = world.get_node("Entities/Tree")
	var screen: Control = world.get_node("UI/TreeScreen") as Control
	var controller := world.get_node(
		"Entities/Tree/Systems/TreeBranchLoadoutController"
	) as TreeBranchLoadoutController

	expect_default_loadout(loadout, controller)
	var thorn_crown: BranchDefinition = GameContent.get_branch(&"thorn_crown")
	expect(
		is_instance_valid(thorn_crown)
		and not seeds.is_branch_seed_unlocked(&"thorn_crown"),
		"Fresh temporary Seed save did not start with Thorn Crown locked."
	)
	expect(
		seeds.unlock_branch_seed(thorn_crown),
		"Thorn Crown could not be persisted in the temporary Seed save."
	)
	var reloaded := BranchSeedService.new()
	reloaded.is_initialized = true
	add_child(reloaded)
	expect(
		reloaded.initialize(storage_path)
		and reloaded.is_branch_seed_unlocked(&"thorn_crown"),
		"Reloaded temporary Seed service lost Thorn Crown."
	)
	expect(
		loadout.get_equipped_apex_branch_id() == &""
		and controller.get_runtime_apex_branch() == null,
		"Persistent unlock automatically equipped the Apex slot."
	)
	reloaded.queue_free()

	# A replacement created during Preparation must remain stopped.
	screen.call("select_slot", &"standard_slot_1")
	expect(screen.call("open_branch_picker"), "Preparation picker did not open.")
	screen.call("select_branch_candidate", &"blossom_branch")
	expect(
		screen.call("confirm_selected_branch_candidate"),
		"Preparation Standard replacement failed."
	)
	await get_tree().process_frame
	var preparation_branch: CombatBranch = controller.get_runtime_branch(
		&"standard_slot_1"
	)
	expect(
		is_instance_valid(preparation_branch)
		and preparation_branch.branch_id == &"blossom_branch"
		and not preparation_branch.combat_enabled,
		"Preparation replacement became combat-active before Continue."
	)

	expect(manager.continue_from_preparation(), "Could not start live combat.")
	expect(
		preparation_branch.combat_enabled
		and director.is_cycle_running()
		and manager.is_branch_loadout_edit_allowed(),
		"Continue did not activate the replacement Branch and live editing."
	)
	var live_wave: int = director.current_wave
	var tree_health_before: float = float(tree_node.get("current_health"))
	var essence_before: int = int(tree_node.get("forest_essence"))
	var age_before: int = int(tree_node.get("age"))

	# Prepare real Blossom delayed state on Slot 4, then replace it live.
	var old_blossom: CombatBranch = controller.get_runtime_branch(
		&"standard_slot_4"
	)
	old_blossom.add_xp(2)
	expect(
		old_blossom.purchase_talent(&"abundant_bloom"),
		"Could not prepare the Slot 4 Blossom saved build."
	)
	var projectile_target := MockEnemy.new()
	world.add_child(projectile_target)
	projectile_target.global_position = old_blossom.global_position + Vector2(120.0, 0.0)
	tree_node.set("current_health", max(tree_health_before - 20.0, 1.0))
	old_blossom.call("apply_blossom_healing")
	var healing_effect_id: StringName = old_blossom.call("get_healing_effect_id")
	expect(
		bool(old_blossom.call("spawn_petal_projectile", projectile_target, 3.0))
		and tree_node.call("has_healing_over_time_effect", healing_effect_id),
		"Could not prepare Blossom projectile and HoT ghost-state fixture."
	)
	var old_projectiles: Array = old_blossom.get("active_projectiles") as Array
	expect(old_projectiles.size() == 1, "Blossom projectile was not tracked.")

	var enemy_health_before: float = projectile_target.damage_taken
	var live_tree_health: float = float(tree_node.get("current_health"))
	screen.call("select_slot", &"standard_slot_4")
	expect(screen.call("open_branch_picker"), "Live Standard picker did not open.")
	screen.call("select_branch_candidate", &"strength_branch")
	expect(
		screen.call("confirm_selected_branch_candidate"),
		"Live Standard replacement failed."
	)
	await get_tree().process_frame
	var live_standard: CombatBranch = controller.get_runtime_branch(
		&"standard_slot_4"
	)
	expect(
		not is_instance_valid(old_blossom)
		and is_instance_valid(live_standard)
		and live_standard.branch_id == &"strength_branch"
		and live_standard.get_slot_id() == &"standard_slot_4"
		and live_standard.combat_enabled,
		"Live Standard runtime replacement identity or combat state is wrong."
	)
	expect(
		not tree_node.call("has_healing_over_time_effect", healing_effect_id)
		and projectile_target.damage_taken == enemy_health_before,
		"Removed Blossom retained a HoT or ghost projectile attack."
	)
	expect_runtime_state_unchanged(
		director, tree_node, live_wave, live_tree_health,
		essence_before, age_before, projectile_target
	)
	screen.call("select_slot", &"standard_slot_4")
	expect(screen.call("open_branch_picker"), "Live restore picker did not open.")
	screen.call("select_branch_candidate", &"blossom_branch")
	expect(
		screen.call("confirm_selected_branch_candidate"),
		"Live Blossom restore failed."
	)
	await get_tree().process_frame
	var restored_blossom: CombatBranch = controller.get_runtime_branch(
		&"standard_slot_4"
	)
	expect(
		is_instance_valid(restored_blossom)
		and restored_blossom.combat_enabled
		and restored_blossom.branch_level == 2
		and restored_blossom.has_talent(&"abundant_bloom"),
		"Live replacement lost shared progress or the per-slot talent build."
	)

	# Equip the persisted production Apex during the same active Wave.
	screen.call("select_slot", &"apex_slot")
	expect(screen.call("open_branch_picker"), "Live Apex picker did not open.")
	screen.call("select_branch_candidate", &"thorn_crown")
	expect(
		screen.call("confirm_selected_branch_candidate"),
		"Live Thorn Crown equip failed."
	)
	await get_tree().process_frame
	var apex: CombatBranch = controller.get_runtime_apex_branch()
	var apex_mount: Node = tree_node.get_node("AttachmentPoints/Apex/BranchMount")
	expect(
		is_instance_valid(apex)
		and apex.branch_id == &"thorn_crown"
		and apex.get_slot_id() == &"apex_slot"
		and apex.get_parent() == apex_mount
		and apex.combat_enabled,
		"Live Apex runtime, mount, identity, or combat state is wrong."
	)
	var left_enemy := MockEnemy.new()
	var right_enemy := MockEnemy.new()
	world.add_child(left_enemy)
	world.add_child(right_enemy)
	left_enemy.global_position = apex.global_position + Vector2(-120.0, 0.0)
	right_enemy.global_position = apex.global_position + Vector2(120.0, 0.0)
	expect(
		bool(apex.call("perform_attack_cycle"))
		and left_enemy.damage_taken > 0.0
		and right_enemy.damage_taken > 0.0,
		"Live Thorn Crown did not participate in combat."
	)
	expect(
		loadout.unequip_apex_branch(),
		"Test cleanup could not remove the live Apex."
	)
	await get_tree().process_frame
	expect(
		not is_instance_valid(apex)
		and controller.get_runtime_apex_branch() == null
		and director.current_wave == live_wave
		and not get_tree().paused,
		"Removed Apex survived or changed the active Wave."
	)

	director.cancel_cycle(true)
	manager.remove_remaining_enemies()
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func expect_default_loadout(
	loadout: BranchLoadoutService,
	controller: TreeBranchLoadoutController
) -> void:
	var expected: Dictionary = {
		&"standard_slot_1": &"strength_branch",
		&"standard_slot_2": &"blossom_branch",
		&"standard_slot_3": &"strength_branch",
		&"standard_slot_4": &"blossom_branch"
	}
	for slot_id in expected:
		expect(
			loadout.get_equipped_branch_id(slot_id) == expected[slot_id]
			and controller.get_runtime_branch(slot_id).branch_id == expected[slot_id],
			"Default Standard loadout is wrong for %s." % slot_id
		)
	expect(
		loadout.is_apex_slot_initialized()
		and loadout.get_equipped_apex_branch_id() == &""
		and controller.get_runtime_apex_branch() == null,
		"Default Apex is not initialized EMPTY."
	)


func expect_runtime_state_unchanged(
	director: WaveDirector,
	tree_node: Node,
	live_wave: int,
	tree_health: float,
	forest_essence: int,
	age: int,
	enemy: MockEnemy
) -> void:
	expect(
		director.current_wave == live_wave
		and director.is_cycle_running()
		and float(tree_node.get("current_health")) == tree_health
		and int(tree_node.get("forest_essence")) == forest_essence
		and int(tree_node.get("age")) == age
		and is_instance_valid(enemy)
		and not bool(tree_node.get("is_dead"))
		and not get_tree().paused,
		"Live Branch replacement reset gameplay state or paused SceneTree."
	)


func remove_storage_file() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(storage_path)
	if FileAccess.file_exists(storage_path):
		DirAccess.remove_absolute(absolute_path)


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
