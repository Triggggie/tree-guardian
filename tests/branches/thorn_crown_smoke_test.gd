extends Node


class MockTree:
	extends Node2D
	var forest_essence: int = 200
	func spend_forest_essence(amount: int) -> bool:
		if amount <= 0 or forest_essence < amount:
			return false
		forest_essence -= amount
		return true
	func add_forest_essence(amount: int) -> void:
		forest_essence += max(amount, 0)
	func get_forest_essence() -> int:
		return forest_essence
	func get_tree_growth_factor() -> float:
		return 1.0


class MockEnemy:
	extends Node2D
	var targetable: bool = true
	var damage_events: Array[float] = []
	var damage_sources: Array[Node] = []
	func is_targetable() -> bool:
		return targetable
	func take_damage(damage: float, source: Node) -> void:
		damage_events.append(damage)
		damage_sources.append(source)


const THORN_SCENE: PackedScene = preload(
	"res://scenes/branches/thorn_crown_branch.tscn"
)
const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")

var failures: Array[String] = []


func _ready() -> void:
	RunModifiers.clear_all()
	await test_definition_and_runtime()
	await test_bilateral_area_combat()
	await test_single_side_and_guards()
	await test_upgrades()
	await test_talents()
	await test_apex_progress_persistence_and_lifecycle()
	test_guardian_grove_loot_entry()
	RunModifiers.clear_all()

	if failures.is_empty():
		print("THORN CROWN SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("THORN CROWN SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func test_definition_and_runtime() -> void:
	var branches: Array[BranchDefinition] = GameContent.get_branches()
	var definition: BranchDefinition = GameContent.get_branch(&"thorn_crown")
	expect(
		branches.size() == 3
		and branches[0].branch_id == &"strength_branch"
		and branches[1].branch_id == &"blossom_branch"
		and branches[2].branch_id == &"thorn_crown",
		"Production Branch registry order is not Strength, Blossom, Thorn Crown."
	)
	expect(
		is_instance_valid(definition)
		and definition.is_valid_definition()
		and definition.display_name == "Thorn Crown"
		and definition.is_legendary_branch()
		and definition.get_legendary_tier() == BranchDefinition.LEGENDARY_TIER_1
		and definition.get_legendary_tier_display_name() == "Tier I"
		and definition.branch_scene == THORN_SCENE
		and is_instance_valid(definition.targeting_profile)
		and definition.targeting_profile.target_group == &"enemies"
		and definition.targeting_profile.target_priority == TargetingProfile.TargetPriority.NEAREST
		and definition.targeting_profile.lane_mode == TargetingProfile.LaneMode.ANY
		and definition.upgrades.size() == 3
		and is_instance_valid(definition.talent_tree)
		and definition.talent_tree.talents.size() == 3,
		"Thorn Crown production definition is incomplete or invalid."
	)
	for slot_index in range(1, 5):
		expect(
			not BranchSlotRules.can_place_definition(definition, slot_index),
			"Thorn Crown entered standard Slot %d." % slot_index
		)
	expect(
		BranchSlotRules.can_place_definition(definition, BranchSlotRules.APEX_SLOT),
		"Thorn Crown cannot use Apex Slot 5."
	)

	var fixture: Dictionary = create_branch_fixture("DefinitionFixture")
	var branch := fixture.branch as CombatBranch
	expect(
		branch.branch_id == &"thorn_crown"
		and branch.get_branch_display_name() == "Thorn Crown"
		and branch.get_slot_id() == BranchSlotRules.APEX_SLOT_ID
		and branch.is_legendary_branch()
		and branch.is_slot_assignment_valid(),
		"Thorn Crown runtime identity or Apex assignment is invalid."
	)
	expect_value(branch.call("get_current_damage"), 12.0, "Base damage")
	expect_value(branch.call("get_current_attack_cooldown"), 2.40, "Base cooldown")
	expect_value(branch.call("get_current_attack_range"), 350.0, "Base range")
	expect_value(branch.call("get_current_burst_radius"), 90.0, "Base Burst Radius")
	var summary: Array[String] = branch.get_stat_summary_lines()
	expect(
		summary == ["Damage 12.0", "Attack Speed 0.42 /s", "Range 350", "Burst Radius 90"],
		"Thorn Crown stat summary does not use current runtime values."
	)
	await cleanup_fixture(fixture.root)


func test_bilateral_area_combat() -> void:
	var fixture: Dictionary = create_branch_fixture("BilateralFixture")
	var root := fixture.root as Node2D
	var branch := fixture.branch as CombatBranch
	var left_primary := create_enemy(root, "LeftPrimary", Vector2(-100.0, 0.0))
	var left_secondary := create_enemy(root, "LeftSecondary", Vector2(-150.0, 20.0))
	var right_primary := create_enemy(root, "RightPrimary", Vector2(100.0, 0.0))
	var right_secondary := create_enemy(root, "RightSecondary", Vector2(150.0, -20.0))
	var outside_radius := create_enemy(root, "OutsideRadius", Vector2(-210.0, 0.0))
	var outside_range := create_enemy(root, "OutsideRange", Vector2(400.0, 0.0))

	expect(branch.call("perform_attack_cycle"), "Bilateral Thorn Crown cycle did not execute.")
	var visual := branch.get_node("Visual") as ThornCrownVisual
	expect(visual.is_attack_animation_active(), "Real Thorn Crown attack did not trigger presentation feedback.")
	for enemy in [left_primary, left_secondary, right_primary, right_secondary]:
		expect_damage(enemy, [12.0], "%s bilateral damage" % enemy.name)
	expect(outside_radius.damage_events.is_empty(), "Enemy outside Burst Radius was damaged.")
	expect(outside_range.damage_events.is_empty(), "Enemy outside attack Range was damaged.")

	var primary_context: AttackContext = branch.call(
		"create_burst_attack_context", left_primary, 1.0, true
	) as AttackContext
	var splash_context: AttackContext = branch.call(
		"create_burst_attack_context", left_secondary, 1.0, false
	) as AttackContext
	expect(
		primary_context.attack_id == &"thorn_crown_burst"
		and primary_context.has_tag(&"thorn_crown")
		and primary_context.has_tag(&"legendary")
		and primary_context.has_tag(&"apex")
		and primary_context.has_tag(&"area_attack")
		and primary_context.has_tag(&"primary_target")
		and splash_context.has_tag(&"splash_target")
		and splash_context.is_secondary_attack,
		"Thorn Burst AttackContext ID, tags, or secondary flag are wrong."
	)
	await cleanup_fixture(root)


func test_single_side_and_guards() -> void:
	var left_fixture: Dictionary = create_branch_fixture("LeftOnlyFixture")
	var left_enemy := create_enemy(left_fixture.root, "LeftOnly", Vector2(-100.0, 0.0))
	expect(left_fixture.branch.call("perform_attack_cycle"), "Left-only cycle did not execute.")
	expect_damage(left_enemy, [12.0], "Left-only damage")
	await cleanup_fixture(left_fixture.root)

	var right_fixture: Dictionary = create_branch_fixture("RightOnlyFixture")
	var right_enemy := create_enemy(right_fixture.root, "RightOnly", Vector2(100.0, 0.0))
	expect(right_fixture.branch.call("perform_attack_cycle"), "Right-only cycle did not execute.")
	expect_damage(right_enemy, [12.0], "Right-only damage")
	await cleanup_fixture(right_fixture.root)

	var empty_fixture: Dictionary = create_branch_fixture("NoTargetFixture")
	var effect_set := empty_fixture.branch.get("talent_effect_set") as ThornCrownTalentEffectSet
	var empty_visual := empty_fixture.branch.get_node("Visual") as ThornCrownVisual
	expect(
		not empty_fixture.branch.call("perform_attack_cycle")
		and effect_set.attack_cycle_count == 0
		and not empty_visual.is_attack_animation_active(),
		"No-target cycle produced an attack or advanced Overgrowth state."
	)
	await cleanup_fixture(empty_fixture.root)


func test_upgrades() -> void:
	var fixture: Dictionary = create_branch_fixture("UpgradeFixture")
	var branch := fixture.branch as CombatBranch
	var tree_node := fixture.tree_node as MockTree
	var initial_essence: int = tree_node.forest_essence
	expect(branch.get_upgrade_ids() == [&"thorn_damage", &"attack_speed", &"burst_radius"], "Upgrade order is wrong.")
	expect(branch.get_upgrade_cost_by_id(&"thorn_damage") == 25, "Thorn Damage first cost is wrong.")
	expect(branch.purchase_upgrade(&"thorn_damage"), "Thorn Damage purchase failed.")
	expect_value(branch.call("get_current_damage"), 14.0, "Upgraded damage")
	expect(branch.get_upgrade_cost_by_id(&"attack_speed") == 30, "Attack Speed first cost is wrong.")
	expect(branch.purchase_upgrade(&"attack_speed"), "Attack Speed purchase failed.")
	expect_value(branch.call("get_current_attack_cooldown"), 2.32, "Upgraded cooldown")
	expect(branch.get_upgrade_cost_by_id(&"burst_radius") == 30, "Burst Radius first cost is wrong.")
	expect(branch.purchase_upgrade(&"burst_radius"), "Burst Radius purchase failed.")
	expect_value(branch.call("get_current_burst_radius"), 98.0, "Upgraded Burst Radius")
	expect(
		tree_node.forest_essence == initial_essence - 85
		and branch.get_progress_upgrade_levels() == {
			&"thorn_damage": 1, &"attack_speed": 1, &"burst_radius": 1
		},
		"Thorn Crown upgrades did not spend once or persist by branch_id."
	)
	await cleanup_fixture(fixture.root)


func test_talents() -> void:
	var fixture: Dictionary = create_branch_fixture("TalentFixture")
	var root := fixture.root as Node2D
	var branch := fixture.branch as CombatBranch
	var left_primary := create_enemy(root, "LeftPrimary", Vector2(-100.0, 0.0))
	var left_secondary := create_enemy(root, "LeftSecondary", Vector2(-150.0, 0.0))
	var right_primary := create_enemy(root, "RightPrimary", Vector2(100.0, 0.0))
	var right_secondary := create_enemy(root, "RightSecondary", Vector2(150.0, 0.0))

	branch.add_xp(2)
	expect(branch.branch_level == 2 and branch.purchase_talent(&"barbed_core"), "Barbed Core purchase failed at Level 2.")
	right_primary.targetable = false
	right_secondary.targetable = false
	branch.call("perform_attack_cycle")
	expect_damage(left_primary, [16.8], "Barbed Core primary")
	expect_damage(left_secondary, [12.0], "Barbed Core splash")

	branch.add_xp(4)
	expect(branch.branch_level == 4 and branch.purchase_talent(&"twin_torment"), "Twin Torment purchase failed at Level 4.")
	clear_damage([left_primary, left_secondary, right_primary, right_secondary])
	right_primary.targetable = true
	right_secondary.targetable = true
	branch.call("perform_attack_cycle")
	expect_damage(left_primary, [21.0], "Twin Torment primary")
	expect_damage(left_secondary, [15.0], "Twin Torment splash")
	expect_damage(right_primary, [21.0], "Twin Torment opposite primary")
	expect_damage(right_secondary, [15.0], "Twin Torment opposite splash")
	clear_damage([left_primary, left_secondary, right_primary, right_secondary])
	right_primary.targetable = false
	right_secondary.targetable = false
	branch.call("perform_attack_cycle")
	expect_damage(left_primary, [16.8], "Twin Torment single-side primary")
	expect_damage(left_secondary, [12.0], "Twin Torment single-side splash")

	branch.add_xp(6)
	expect(branch.branch_level == 7 and branch.purchase_talent(&"overgrowth"), "Overgrowth purchase failed at Level 7.")
	var expanded_secondary := create_enemy(root, "ExpandedSecondary", Vector2(-220.0, 0.0))
	right_primary.targetable = true
	right_secondary.targetable = true
	clear_damage([left_primary, left_secondary, right_primary, right_secondary, expanded_secondary])
	branch.call("perform_attack_cycle")
	for enemy in [left_primary, left_secondary, right_primary, right_secondary, expanded_secondary]:
		enemy.targetable = false
	expect(not branch.call("perform_attack_cycle"), "No-target gap counted as a real cycle.")
	for enemy in [left_primary, left_secondary, right_primary, right_secondary, expanded_secondary]:
		enemy.targetable = true
	branch.call("perform_attack_cycle")
	branch.call("perform_attack_cycle")
	expect_damage(left_primary, [21.0, 21.0, 27.3], "Stacked third-cycle primary")
	expect_damage(left_secondary, [15.0, 15.0, 19.5], "Stacked third-cycle splash")
	expect_damage(right_primary, [21.0, 21.0, 27.3], "Stacked right primary")
	expect_damage(expanded_secondary, [19.5], "Overgrowth expanded-radius target")
	var effect_set := branch.get("talent_effect_set") as ThornCrownTalentEffectSet
	expect(effect_set.attack_cycle_count == 3, "Overgrowth counter advanced across a no-target cycle.")
	await cleanup_fixture(root)


func test_apex_progress_persistence_and_lifecycle() -> void:
	var loadout := get_node("/root/BranchLoadout") as BranchLoadoutService
	var progress := get_node("/root/BranchProgress") as BranchProgressService
	loadout.clear_runtime_loadout_for_testing()
	progress.clear_runtime_progress_for_testing()
	var world: Node = MAIN_WORLD_SCENE.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await get_tree().process_frame
	var controller := world.get_node(
		"Entities/Tree/Systems/TreeBranchLoadoutController"
	) as TreeBranchLoadoutController
	expect(loadout.equip_apex_branch(&"thorn_crown"), "Production Thorn Crown low-level equip failed.")
	var branch: CombatBranch = controller.get_runtime_apex_branch()
	expect(is_instance_valid(branch) and branch.get_slot_id() == &"apex_slot", "Production Apex runtime is missing.")
	branch.add_xp(2)
	expect(branch.purchase_talent(&"barbed_core"), "Production Apex Barbed Core purchase failed.")
	branch.resume_combat()
	var timer := branch.get_node("CooldownTimer") as Timer
	var effect_set := branch.get("talent_effect_set") as ThornCrownTalentEffectSet
	effect_set.begin_attack_cycle(true, false)
	var burst: ThornBurstVisual = branch.call("spawn_burst_feedback", Vector2.ZERO, 90.0) as ThornBurstVisual
	branch.stop_combat()
	await get_tree().process_frame
	expect(
		not branch.combat_enabled
		and timer.is_stopped()
		and effect_set.attack_cycle_count == 0
		and not is_instance_valid(burst),
		"stop_combat did not reset Thorn Crown runtime state."
	)
	branch.resume_combat()
	expect(branch.combat_enabled and not timer.is_stopped(), "resume_combat did not restart Thorn Crown cleanly.")
	expect(loadout.unequip_apex_branch(), "Production Thorn Crown unequip failed.")
	await get_tree().process_frame
	expect(loadout.equip_apex_branch(&"thorn_crown"), "Production Thorn Crown re-equip failed.")
	await get_tree().process_frame
	var restored: CombatBranch = controller.get_runtime_apex_branch()
	expect(
		is_instance_valid(restored)
		and restored.has_talent(&"barbed_core")
		and progress.get_talent_loadout_copy(&"apex_slot", &"thorn_crown")
		.is_talent_purchased(&"barbed_core"),
		"apex_slot + thorn_crown talent loadout was not restored."
	)
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	loadout.clear_runtime_loadout_for_testing()
	progress.clear_runtime_progress_for_testing()


func test_guardian_grove_loot_entry() -> void:
	var stage: StageDefinition = GameContent.get_stage(&"guardian_grove")
	var pool: BranchSeedLootPoolDefinition = stage.get_branch_seed_loot_pool()
	expect(
		pool.entries.size() == 1
		and pool.entries[0].get_branch_id() == &"thorn_crown"
		and pool.entries[0].get_legendary_tier() == BranchDefinition.LEGENDARY_TIER_1,
		"Guardian Grove does not contain exactly the Thorn Crown Tier I Seed entry."
	)


func create_branch_fixture(fixture_name: String) -> Dictionary:
	var root := Node2D.new()
	root.name = fixture_name
	var progress := BranchProgressService.new()
	progress.name = "BranchProgressService"
	root.add_child(progress)
	var tree_node := MockTree.new()
	tree_node.name = "MockTree"
	root.add_child(tree_node)
	add_child(root)
	var branch := THORN_SCENE.instantiate() as CombatBranch
	branch.name = "ThornCrown"
	branch.process_mode = Node.PROCESS_MODE_DISABLED
	branch.slot_index = BranchSlotRules.APEX_SLOT
	branch.branch_progress_service = progress
	tree_node.add_child(branch)
	return {"root": root, "tree_node": tree_node, "progress": progress, "branch": branch}


func create_enemy(parent: Node, enemy_name: String, enemy_position: Vector2) -> MockEnemy:
	var enemy := MockEnemy.new()
	enemy.name = enemy_name
	enemy.position = enemy_position
	parent.add_child(enemy)
	enemy.add_to_group("enemies")
	return enemy


func clear_damage(enemies: Array) -> void:
	for enemy in enemies:
		enemy.damage_events.clear()
		enemy.damage_sources.clear()


func cleanup_fixture(root: Node) -> void:
	root.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func expect_damage(enemy: MockEnemy, expected: Array, label: String) -> void:
	expect(enemy.damage_events.size() == expected.size(), "%s event count is wrong." % label)
	if enemy.damage_events.size() != expected.size():
		return
	for index in range(expected.size()):
		expect_value(enemy.damage_events[index], float(expected[index]), "%s event %d" % [label, index])


func expect_value(actual: float, expected: float, label: String) -> void:
	expect(is_equal_approx(actual, expected), "%s was %.3f instead of %.3f." % [label, actual, expected])


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
