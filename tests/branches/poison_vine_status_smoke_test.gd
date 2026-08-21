extends Node


const POISON_VINE_SCENE: PackedScene = preload(
	"res://scenes/branches/poison_vine_branch.tscn"
)
const BLOSSOM_SCENE: PackedScene = preload(
	"res://scenes/branches/blossom_branch.tscn"
)


class MockTree:
	extends Node2D

	var forest_essence: int = 10000


	func get_tree_growth_factor() -> float:
		return 1.0


	func spend_forest_essence(amount: int) -> bool:
		if amount <= 0 or forest_essence < amount:
			return false
		forest_essence -= amount
		return true


class MockEnemy:
	extends Node2D

	var health: float = 500.0
	var targetable: bool = true
	var lane_index: int = 0
	var damage_events: Array[Dictionary] = []
	var status_effect_component: EnemyStatusEffectComponent


	func _ready() -> void:
		add_to_group("enemies")
		status_effect_component = EnemyStatusEffectComponent.new()
		status_effect_component.name = "StatusEffectComponent"
		add_child(status_effect_component)
		status_effect_component.initialize(self)
		status_effect_component.process_mode = Node.PROCESS_MODE_DISABLED


	func is_targetable() -> bool:
		return targetable and health > 0.0 and not is_queued_for_deletion()


	func take_damage(amount: float, source: Node = null) -> void:
		health = max(health - amount, 0.0)
		damage_events.append({&"amount": amount, &"source": source})
		if health <= 0.0:
			targetable = false
			status_effect_component.clear_all_effects()


	func get_current_health() -> float:
		return health


	func get_lane_index() -> int:
		return lane_index


	func apply_status_effect(
		status_effect_id: StringName,
		source: Node,
		stack_amount: int = 1,
		periodic_value_override: float = -1.0,
		duration_override: float = -1.0
	) -> bool:
		return status_effect_component.apply_effect(
			GameContent.get_status_effect(status_effect_id),
			source,
			stack_amount,
			periodic_value_override,
			duration_override
		)


	func get_status_effect_stack_count(status_effect_id: StringName) -> int:
		return status_effect_component.get_stack_count(status_effect_id)


var failures: Array[String] = []


func _ready() -> void:
	test_content_and_slot_compatibility()
	await test_mounts_progress_and_runtime_isolation()
	await test_ranged_acquisition_matches_blossom()
	await test_direct_hit_stacking_ticks_and_cleanup()
	await test_targeting_priority()

	if failures.is_empty():
		print("POISON VINE STATUS SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print("POISON VINE STATUS SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func test_content_and_slot_compatibility() -> void:
	var definition: BranchDefinition = GameContent.get_branch(&"poison_vine")
	var poison: StatusEffectDefinition = GameContent.get_status_effect(&"poison")
	expect(is_instance_valid(definition) and definition.is_valid_definition(), "Poison Vine definition is missing or invalid.")
	expect(is_instance_valid(poison) and poison.is_valid_definition(), "Poison status definition is missing or invalid.")
	if is_instance_valid(definition):
		expect(definition.branch_id == &"poison_vine", "Poison Vine stable ID changed.")
		expect(definition.standard_position_id == BranchDefinition.STANDARD_POSITION_ANY, "Poison Vine is not any-Standard compatible.")
		for slot_index in range(1, 5):
			expect(BranchSlotRules.can_place_definition(definition, slot_index), "Poison Vine was rejected from Standard slot %d." % slot_index)
		expect(not BranchSlotRules.can_place_definition(definition, BranchSlotRules.APEX_SLOT), "Poison Vine was accepted in Apex.")
		expect(
			definition.get_upgrade_ids()
			== [&"venom_potency", &"toxic_persistence", &"application_speed"],
			"Poison Vine upgrade order or stable IDs changed."
		)
		expect(
			is_equal_approx(definition.get_upgrade_by_id(&"venom_potency").value_per_level, 0.5)
			and is_equal_approx(definition.get_upgrade_by_id(&"toxic_persistence").value_per_level, 0.25)
			and is_equal_approx(definition.get_upgrade_by_id(&"application_speed").value_per_level, 0.08),
			"Poison Vine upgrade values changed."
		)
	if is_instance_valid(poison):
		expect(
			poison.status_effect_id == &"poison"
			and poison.stack_mode == StatusEffectDefinition.StackMode.STACK_INTENSITY
			and poison.maximum_stacks == 3
			and is_equal_approx(poison.base_duration, 4.0)
			and is_equal_approx(poison.tick_interval, 1.0)
			and is_equal_approx(poison.base_periodic_value, 2.0),
			"Poison V1 authored semantics changed."
		)
	var validation_errors: Array[String] = ContentValidator.validate_registry(GameContent.registry)
	expect(validation_errors.is_empty(), "ContentValidator rejected production Poison content: %s" % str(validation_errors))
	var malformed_poison := poison.duplicate(true) as StatusEffectDefinition
	malformed_poison.maximum_stacks = 0
	expect(not malformed_poison.is_valid_definition(), "Malformed Poison stack cap was accepted.")
	malformed_poison = poison.duplicate(true) as StatusEffectDefinition
	malformed_poison.base_duration = 0.0
	expect(not malformed_poison.is_valid_definition(), "Malformed Poison duration was accepted.")
	malformed_poison = poison.duplicate(true) as StatusEffectDefinition
	malformed_poison.tick_interval = 0.0
	expect(not malformed_poison.is_valid_definition(), "Malformed Poison tick interval was accepted.")
	malformed_poison = poison.duplicate(true) as StatusEffectDefinition
	malformed_poison.maximum_stacks = 4
	var poison_registry := ContentRegistry.new()
	poison_registry.status_effects = [malformed_poison]
	expect(
		ContentValidator.validate_registry(poison_registry).has(
			"Poison has invalid duration, tick, damage, or stacking data."
		),
		"ContentValidator accepted a contradictory Poison production definition."
	)


func test_mounts_progress_and_runtime_isolation() -> void:
	var fixture := Node2D.new()
	var progress := BranchProgressService.new()
	progress.name = "Progress"
	fixture.add_child(progress)
	add_child(fixture)
	var tree_node := MockTree.new()
	fixture.add_child(tree_node)
	var branches: Array[CombatBranch] = []
	for slot_index in range(1, 5):
		var branch := POISON_VINE_SCENE.instantiate() as CombatBranch
		branch.slot_index = slot_index
		branch.facing_side = 0 if slot_index in [1, 2] else 1
		branch.branch_progress_service = progress
		branch.process_mode = Node.PROCESS_MODE_DISABLED
		tree_node.add_child(branch)
		branches.append(branch)
		expect(branch.is_slot_assignment_valid(), "Poison Vine runtime rejected slot %d." % slot_index)
		var endpoint: Vector2 = branch.get_node("Visual").call("get_endpoint_local_position")
		expect(signf(endpoint.x) == branch.get_facing_direction(), "Poison Vine endpoint did not mirror in slot %d." % slot_index)

	branches[0].add_xp(branches[0].get_safe_xp_required_per_level())
	for branch in branches:
		expect(branch.branch_level == 2, "Poison Vine shared XP missed a physical copy.")
	var shared_progress: BranchProgressRecord = progress.get_progress(&"poison_vine")
	shared_progress.set_upgrade_level(&"venom_potency", 1)
	shared_progress.set_upgrade_level(&"toxic_persistence", 1)
	shared_progress.set_upgrade_level(&"application_speed", 1)
	for branch in branches:
		progress.synchronize_branch(branch)
		expect(branch.get_upgrade_level(&"venom_potency") == 1, "Poison Vine shared upgrade missed a physical copy.")
		expect(
			is_equal_approx(float(branch.call("get_current_poison_duration")), 4.25)
			and is_equal_approx(float(branch.call("get_current_attack_interval")), 1.72),
			"Poison Vine shared duration or speed upgrade did not propagate."
		)
	expect(
		progress.get_talent_loadout(&"standard_slot_1", &"poison_vine")
		!= progress.get_talent_loadout(&"standard_slot_3", &"poison_vine"),
		"Poison Vine slot talent-loadout records are not independent."
	)
	branches[0].set("attack_time_remaining", 0.9)
	expect(float(branches[1].get("attack_time_remaining")) != 0.9, "Poison Vine attack cooldown state leaked between instances.")
	expect(
		not is_same(
			branches[0].get("active_projectiles"),
			branches[1].get("active_projectiles")
		),
		"Poison Vine projectile collections are shared."
	)
	fixture.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func test_ranged_acquisition_matches_blossom() -> void:
	var poison_probe := POISON_VINE_SCENE.instantiate() as CombatBranch
	var blossom_probe := BLOSSOM_SCENE.instantiate() as CombatBranch
	expect(
		is_equal_approx(
			float(poison_probe.get("base_attack_range")),
			float(blossom_probe.get("ranged_attack_range"))
		),
		"Poison Vine nominal range does not match Blossom's practical ranged baseline."
	)
	expect(
		is_equal_approx(float(poison_probe.get("base_attack_range")), 650.0),
		"Poison Vine ranged baseline changed from 650."
	)
	poison_probe.free()
	blossom_probe.free()

	var representative_mount_positions: Dictionary = {
		1: Vector2(-48.0, -113.0),
		2: Vector2(-44.0, -197.0),
		3: Vector2(48.0, -113.0),
		4: Vector2(44.0, -197.0)
	}
	for slot_index in range(1, 5):
		var fixture := await create_combat_fixture(slot_index)
		var branch := fixture.get_node("Tree/PoisonVine") as CombatBranch
		branch.position = representative_mount_positions[slot_index]
		var facing_direction: float = branch.get_facing_direction()
		var approaching_enemy := create_enemy(
			fixture,
			"ApproachingSlot%d" % slot_index,
			branch.global_position + Vector2(facing_direction * 600.0, 0.0),
			500.0
		)
		approaching_enemy.lane_index = 3
		var acquired_target: Node2D = branch.call("find_poison_target") as Node2D
		expect(
			acquired_target == approaching_enemy,
			"Poison Vine in Standard slot %d did not acquire an approaching enemy at Blossom-like range."
			% slot_index
		)
		expect(
			abs(approaching_enemy.global_position.x - branch.global_position.x) > 500.0,
			"Poison Vine slot %d range fixture collapsed into melee distance."
			% slot_index
		)
		await cleanup_fixture(fixture)


func test_direct_hit_stacking_ticks_and_cleanup() -> void:
	var fixture := await create_combat_fixture()
	var branch := fixture.get_node("Tree/PoisonVine") as CombatBranch
	var enemy := create_enemy(fixture, "StackTarget", Vector2(120.0, 0.0), 500.0)
	var projectile := create_projectile(branch, enemy)
	projectile.call("_hit_target")
	expect_damage(enemy, 0, 4.0, branch, "direct hit")
	expect(enemy.get_status_effect_stack_count(&"poison") == 1, "First Poison stack was not applied.")
	var status := enemy.status_effect_component
	var xp_before: int = branch.current_xp
	status.add_xp(1)
	expect(branch.current_xp == xp_before + 1, "Status damage source did not preserve Branch XP attribution.")
	status.call("_process", 0.99)
	expect(enemy.damage_events.size() == 1, "Poison ticked before one second.")
	status.call("_process", 0.01)
	expect_damage(enemy, 1, 2.0, status, "one-stack tick")

	enemy.apply_status_effect(&"poison", branch, 1, 2.0, 4.0)
	expect(enemy.get_status_effect_stack_count(&"poison") == 2, "Second Poison stack was not applied.")
	expect(is_equal_approx(status.get_remaining_duration(&"poison"), 4.0), "Below-cap application did not refresh duration.")
	status.call("_process", 1.0)
	expect_damage(enemy, 2, 4.0, status, "two-stack tick")
	enemy.apply_status_effect(&"poison", branch, 1, 2.0, 4.0)
	status.call("_process", 1.0)
	expect_damage(enemy, 3, 6.0, status, "three-stack tick")
	enemy.apply_status_effect(&"poison", branch, 1, 2.0, 4.0)
	expect(enemy.get_status_effect_stack_count(&"poison") == 3, "A fourth Poison stack exceeded the cap.")
	expect(is_equal_approx(status.get_remaining_duration(&"poison"), 4.0), "Max-stack application did not deterministically refresh duration.")
	for tick_index in range(4):
		status.call("_process", 1.0)
	expect(not status.has_effect(&"poison"), "Poison did not expire after its refreshed duration.")

	enemy.apply_status_effect(&"poison", branch, 1, 2.0, 4.0)
	enemy.targetable = false
	status.call("_process", 0.1)
	expect(not status.has_effect(&"poison"), "Unavailable enemy retained Poison state.")
	enemy.targetable = true
	enemy.apply_status_effect(&"poison", branch, 1, 2.0, 4.0)
	status.clear_all_effects()
	var event_count: int = enemy.damage_events.size()
	status.call("_process", 10.0)
	expect(enemy.damage_events.size() == event_count, "Cleared Poison produced a stale callback.")
	await cleanup_fixture(fixture)


func test_targeting_priority() -> void:
	var fixture := await create_combat_fixture()
	var branch := fixture.get_node("Tree/PoisonVine") as CombatBranch
	var fully_poisoned := create_enemy(fixture, "FullyPoisoned", Vector2(90.0, 0.0), 400.0)
	var eligible := create_enemy(fixture, "Eligible", Vector2(130.0, 0.0), 250.0)
	for stack_index in range(3):
		fully_poisoned.apply_status_effect(&"poison", branch, 1, 2.0, 4.0)
	expect(branch.call("find_poison_target") == eligible, "Poison targeting wasted an attack on a max-stack enemy.")
	for stack_index in range(3):
		eligible.apply_status_effect(&"poison", branch, 1, 2.0, 4.0)
	expect(branch.call("find_poison_target") == fully_poisoned, "Poison targeting did not use established fallback when all targets were full.")
	eligible.status_effect_component.clear_all_effects()
	eligible.health = 450.0
	expect(branch.call("find_poison_target") == eligible, "Poison targeting did not prefer the healthier eligible target.")
	await cleanup_fixture(fixture)


func create_combat_fixture(slot_index: int = 3) -> Node2D:
	var fixture := Node2D.new()
	fixture.name = "CombatFixture"
	var progress := BranchProgressService.new()
	progress.name = "Progress"
	fixture.add_child(progress)
	add_child(fixture)
	var tree_node := MockTree.new()
	tree_node.name = "Tree"
	fixture.add_child(tree_node)
	var branch := POISON_VINE_SCENE.instantiate() as CombatBranch
	branch.name = "PoisonVine"
	branch.slot_index = slot_index
	branch.facing_side = 0 if slot_index in [1, 2] else 1
	branch.branch_progress_service = progress
	branch.process_mode = Node.PROCESS_MODE_DISABLED
	tree_node.add_child(branch)
	await get_tree().process_frame
	return fixture


func create_enemy(
	fixture: Node2D,
	enemy_name: String,
	enemy_position: Vector2,
	enemy_health: float
) -> MockEnemy:
	var enemy := MockEnemy.new()
	enemy.name = enemy_name
	enemy.position = enemy_position
	enemy.health = enemy_health
	fixture.add_child(enemy)
	return enemy


func create_projectile(
	branch: CombatBranch,
	enemy: MockEnemy
) -> PoisonVineProjectile:
	var projectile := PoisonVineProjectile.new()
	add_child(projectile)
	projectile.process_mode = Node.PROCESS_MODE_DISABLED
	projectile.setup(
		enemy,
		branch,
		float(branch.call("get_current_direct_damage")),
		float(branch.call("get_current_poison_damage_per_stack")),
		float(branch.call("get_current_poison_duration"))
	)
	return projectile


func expect_damage(
	enemy: MockEnemy,
	event_index: int,
	expected_amount: float,
	expected_source: Node,
	label: String
) -> void:
	expect(enemy.damage_events.size() > event_index, "%s produced no damage event." % label)
	if enemy.damage_events.size() <= event_index:
		return
	var event: Dictionary = enemy.damage_events[event_index]
	expect(is_equal_approx(float(event[&"amount"]), expected_amount), "%s damage was wrong." % label)
	expect(event[&"source"] == expected_source, "%s source/tagging path was wrong." % label)


func cleanup_fixture(fixture: Node2D) -> void:
	fixture.queue_free()
	for child in get_children():
		if child is PoisonVineProjectile:
			child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
