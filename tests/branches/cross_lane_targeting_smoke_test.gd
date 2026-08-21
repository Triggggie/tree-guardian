extends Node


const STRENGTH_SCENE: PackedScene = preload(
	"res://scenes/branches/strength_branch.tscn"
)
const BLOSSOM_SCENE: PackedScene = preload(
	"res://scenes/branches/blossom_branch.tscn"
)
const POISON_VINE_SCENE: PackedScene = preload(
	"res://scenes/branches/poison_vine_branch.tscn"
)

const MOUNT_POSITIONS: Dictionary = {
	1: Vector2(-48.0, -113.0),
	2: Vector2(-44.0, -197.0),
	3: Vector2(48.0, -113.0),
	4: Vector2(44.0, -197.0)
}


class MockTree:
	extends Node2D

	var age: int = 1
	var forest_essence: int = 1000


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
	var lane_index: int = 3
	var poison_stacks: int = 0
	var damage_events: Array[float] = []


	func _ready() -> void:
		add_to_group("enemies")


	func is_targetable() -> bool:
		return targetable and health > 0.0 and not is_queued_for_deletion()


	func take_damage(amount: float, _source: Node = null) -> void:
		health = max(health - amount, 0.0)
		damage_events.append(amount)


	func get_current_health() -> float:
		return health


	func get_lane_index() -> int:
		return lane_index


	func get_status_effect_stack_count(status_effect_id: StringName) -> int:
		return poison_stacks if status_effect_id == &"poison" else 0


var failures: Array[String] = []


func _ready() -> void:
	test_targeting_mode_content()
	await test_strength_own_side_only()
	await test_blossom_cross_lane_assistance()
	await test_poison_vine_cross_lane_assistance()

	if failures.is_empty():
		print("CROSS-LANE TARGETING SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print("CROSS-LANE TARGETING SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func test_targeting_mode_content() -> void:
	var strength: BranchDefinition = GameContent.get_branch(&"strength_branch")
	var blossom: BranchDefinition = GameContent.get_branch(&"blossom_branch")
	var poison_vine: BranchDefinition = GameContent.get_branch(&"poison_vine")
	var thorn_crown: BranchDefinition = GameContent.get_branch(&"thorn_crown")
	expect(
		strength.targeting_profile.side_mode
		== TargetingProfile.SideMode.OWN_SIDE_ONLY,
		"Strength is not authored own-side-only."
	)
	expect(
		blossom.targeting_profile.side_mode
		== TargetingProfile.SideMode.OWN_SIDE_PREFERRED
		and poison_vine.targeting_profile.side_mode
		== TargetingProfile.SideMode.OWN_SIDE_PREFERRED,
		"A ranged Standard Branch is missing own-side preference."
	)
	expect(
		thorn_crown.targeting_profile.side_mode
		== TargetingProfile.SideMode.ANY_SIDE,
		"The bilateral Apex targeting profile is not authored any-side."
	)
	expect(
		CombatTargeting.get_side_search_order(
			strength.targeting_profile,
			-1.0
		) == [-1.0],
		"OWN_SIDE_ONLY returned the wrong search order."
	)
	expect(
		CombatTargeting.get_side_search_order(
			blossom.targeting_profile,
			-1.0
		) == [-1.0, 1.0],
		"OWN_SIDE_PREFERRED returned the wrong search order."
	)
	expect(
		CombatTargeting.get_side_search_order(
			thorn_crown.targeting_profile,
			-1.0
		) == [0.0],
		"ANY_SIDE returned the wrong search order."
	)
	var side_probe := Node2D.new()
	side_probe.position = Vector2(100.0, 0.0)
	expect(
		CombatTargeting.is_target_on_side(side_probe, 0.0, 0.0),
		"ANY_SIDE rejected a valid side probe."
	)
	side_probe.free()
	var malformed_profile := blossom.targeting_profile.duplicate(true) as TargetingProfile
	malformed_profile.set("side_mode", 99)
	expect(
		not malformed_profile.is_valid_definition(),
		"TargetingProfile accepted an unknown side mode."
	)
	expect(
		ContentValidator.validate_registry(GameContent.registry).is_empty(),
		"ContentValidator rejected production side-targeting content."
	)


func test_strength_own_side_only() -> void:
	for slot_index in [1, 3]:
		var fixture: Node2D = await create_branch_fixture(STRENGTH_SCENE, slot_index)
		var branch := fixture.get_node("Tree/Branch") as CombatBranch
		var own_direction: float = branch.get_facing_direction()
		var own_enemy := create_enemy(
			fixture,
			Vector2(own_direction * 140.0, branch.global_position.y)
		)
		var opposite_enemy := create_enemy(
			fixture,
			Vector2(-own_direction * 140.0, branch.global_position.y)
		)
		expect(
			branch.call("find_nearest_enemy") == own_enemy,
			"Strength in slot %d did not acquire its own-side enemy." % slot_index
		)
		own_enemy.targetable = false
		expect(
			branch.call("find_nearest_enemy") == null
			and not bool(branch.call("is_valid_attack_target", opposite_enemy)),
			"Strength in slot %d acquired an opposite-side enemy." % slot_index
		)
		expect(
			is_equal_approx(float(branch.get("base_damage")), 10.0)
			and is_equal_approx(float(branch.get("base_attack_cooldown")), 1.5)
			and is_equal_approx(float(branch.get("base_range_padding")), 100.0),
			"Strength combat balance changed."
		)
		await cleanup_fixture(fixture)


func test_blossom_cross_lane_assistance() -> void:
	for slot_index in range(1, 5):
		var fixture: Node2D = await create_branch_fixture(BLOSSOM_SCENE, slot_index)
		var branch := fixture.get_node("Tree/Branch") as CombatBranch
		var own_direction: float = branch.get_facing_direction()
		var own_enemy := create_enemy(
			fixture,
			Vector2(own_direction * 250.0, branch.global_position.y)
		)
		var opposite_enemy := create_enemy(
			fixture,
			Vector2(-own_direction * 250.0, branch.global_position.y)
		)
		expect(
			branch.call("find_best_ranged_target") == own_enemy,
			"Blossom in slot %d did not prefer its own side." % slot_index
		)
		own_enemy.targetable = false
		expect(
			branch.call("find_best_ranged_target") == opposite_enemy,
			"Blossom in slot %d did not assist the opposite side." % slot_index
		)

		if slot_index in [1, 4]:
			var spawn_position: Vector2 = branch.call("get_projectile_spawn_position")
			expect(
				bool(branch.call("spawn_petal_projectile", opposite_enemy, 3.0)),
				"Blossom in slot %d could not fire a cross-Tree projectile."
				% slot_index
			)
			var projectiles: Array = branch.get("active_projectiles") as Array
			var projectile := projectiles[0] as BlossomProjectile
			expect(
				projectile.target == opposite_enemy
				and projectile.global_position.is_equal_approx(spawn_position),
				"Blossom cross-Tree projectile target or origin is invalid."
			)
			projectile.queue_free()

		own_enemy.targetable = true
		expect(
			branch.call("find_best_ranged_target") == own_enemy,
			"Blossom in slot %d did not return to own-side priority."
			% slot_index
		)
		own_enemy.targetable = false
		opposite_enemy.targetable = false
		var opposite_direction: float = -own_direction
		create_enemy(
			fixture,
			Vector2(
				branch.global_position.x + opposite_direction * 651.0,
				branch.global_position.y
			)
		)
		expect(
			branch.call("find_best_ranged_target") == null,
			"Blossom in slot %d ignored its real range while assisting."
			% slot_index
		)
		expect(
			is_equal_approx(float(branch.get("base_healing_per_tick")), 3.0)
			and is_equal_approx(float(branch.get("ranged_attack_range")), 650.0),
			"Blossom healing or ranged balance changed."
		)
		await cleanup_fixture(fixture)


func test_poison_vine_cross_lane_assistance() -> void:
	var fixture: Node2D = await create_branch_fixture(POISON_VINE_SCENE, 2)
	var branch := fixture.get_node("Tree/Branch") as CombatBranch
	var own_enemy := create_enemy(
		fixture,
		Vector2(-180.0, branch.global_position.y),
		350.0,
		3
	)
	var opposite_full := create_enemy(
		fixture,
		Vector2(160.0, branch.global_position.y),
		500.0,
		3
	)
	var opposite_eligible := create_enemy(
		fixture,
		Vector2(240.0, branch.global_position.y),
		300.0,
		0
	)
	var opposite_healthier := create_enemy(
		fixture,
		Vector2(320.0, branch.global_position.y),
		450.0,
		1
	)
	expect(
		branch.call("find_poison_target") == own_enemy,
		"Poison Vine abandoned an eligible own-side target for the opposite side."
	)
	own_enemy.targetable = false
	expect(
		branch.call("find_poison_target") == opposite_healthier,
		"Poison Vine did not apply stack/health priority while assisting."
	)
	opposite_eligible.targetable = false
	opposite_healthier.targetable = false
	expect(
		branch.call("find_poison_target") == opposite_full,
		"Poison Vine did not use normal fallback on the assisted side."
	)
	opposite_full.targetable = false
	create_enemy(
		fixture,
		Vector2(branch.global_position.x + 651.0, branch.global_position.y),
		500.0,
		0
	)
	expect(
		branch.call("find_poison_target") == null,
		"Poison Vine ignored its real range while assisting."
	)
	await cleanup_fixture(fixture)

	fixture = await create_branch_fixture(POISON_VINE_SCENE, 4)
	branch = fixture.get_node("Tree/Branch") as CombatBranch
	var left_enemy := create_enemy(
		fixture,
		Vector2(-240.0, branch.global_position.y),
		500.0,
		0
	)
	expect(
		branch.call("find_poison_target") == left_enemy,
		"Right-mounted Poison Vine did not assist the left side."
	)
	await cleanup_fixture(fixture)


func create_branch_fixture(
	branch_scene: PackedScene,
	slot_index: int
) -> Node2D:
	var fixture := Node2D.new()
	fixture.name = "CrossLaneFixture"
	var progress := BranchProgressService.new()
	progress.name = "Progress"
	fixture.add_child(progress)
	var enemy_tracker := EnemyTracker.new()
	enemy_tracker.name = "EnemyTracker"
	fixture.add_child(enemy_tracker)
	add_child(fixture)
	var tree_node := MockTree.new()
	tree_node.name = "Tree"
	fixture.add_child(tree_node)
	var branch := branch_scene.instantiate() as CombatBranch
	branch.name = "Branch"
	branch.slot_index = slot_index
	branch.facing_side = 0 if slot_index in [1, 2] else 1
	branch.position = MOUNT_POSITIONS[slot_index]
	branch.branch_progress_service = progress
	branch.process_mode = Node.PROCESS_MODE_DISABLED
	tree_node.add_child(branch)
	await get_tree().process_frame
	return fixture


func create_enemy(
	fixture: Node2D,
	enemy_position: Vector2,
	enemy_health: float = 500.0,
	poison_stacks: int = 0
) -> MockEnemy:
	var enemy := MockEnemy.new()
	enemy.position = enemy_position
	enemy.health = enemy_health
	enemy.poison_stacks = poison_stacks
	fixture.add_child(enemy)
	var enemy_tracker := fixture.get_node("EnemyTracker") as EnemyTracker
	enemy_tracker.register_enemy(enemy)
	return enemy


func cleanup_fixture(fixture: Node2D) -> void:
	var branch := fixture.get_node_or_null("Tree/Branch") as CombatBranch
	if is_instance_valid(branch):
		branch.stop_combat()
	fixture.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
