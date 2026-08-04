extends Node


const BLOSSOM_SCENE: PackedScene = preload(
	"res://scenes/branches/blossom_branch.tscn"
)

const BLOSSOM_BRANCH_DEFINITION_PATH: String = (
	"res://resources/branches/blossom_branch_definition.tres"
)

const TALENT_RESOURCE_PATHS: Array[String] = [
	"res://resources/talents/blossom/abundant_bloom.tres",
	"res://resources/talents/blossom/quickening_pollen.tres",
	"res://resources/talents/blossom/twin_petals.tres"
]

const EXPECTED_TALENT_IDS: Array[StringName] = [
	&"abundant_bloom",
	&"quickening_pollen",
	&"twin_petals"
]


class MockTree:
	extends Node2D

	var forest_essence: int = 100000
	var healing_effects: Dictionary = {}


	func get_tree_growth_factor() -> float:
		return 1.0


	func spend_forest_essence(
		amount: int
	) -> bool:
		if amount <= 0 or forest_essence < amount:
			return false

		forest_essence -= amount
		return true


	func apply_healing_over_time(
		effect_id: StringName,
		healing_per_tick: float,
		tick_interval: float,
		duration: float,
		source: Node,
		refresh_existing: bool
	) -> void:
		healing_effects[effect_id] = {
			"healing_per_tick": healing_per_tick,
			"tick_interval": tick_interval,
			"duration": duration,
			"source": source,
			"refresh_existing": refresh_existing
		}


class MockEnemy:
	extends Node2D

	var targetable: bool = true
	var damage_events: Array[float] = []


	func is_targetable() -> bool:
		return targetable


	func take_damage(
		amount: float,
		_source: Node = null
	) -> void:
		damage_events.append(amount)


var failures: Array[String] = []
var resource_snapshots: Dictionary = {}


func _ready() -> void:
	await test_resources_and_dispatch()
	await test_base_runtime()
	await test_abundant_bloom()
	await test_quickening_pollen()
	await test_twin_petals()
	await test_combined_effects_and_instances()

	verify_resource_snapshots()

	expect(
		get_tree().get_nodes_in_group(
			"enemies"
		).is_empty(),
		"Blossom talent test left an enemy group member."
	)
	expect(
		get_tree().get_nodes_in_group(
			"blossom_branch"
		).is_empty(),
		"Blossom talent test left a Blossom group member."
	)
	expect(
		get_tree().get_nodes_in_group(
			"combat_branch"
		).is_empty(),
		"Blossom talent test left a combat branch group member."
	)
	expect(
		get_projectiles().is_empty(),
		"Blossom talent test left a projectile node."
	)

	if failures.is_empty():
		print("BLOSSOM TALENT EFFECTS SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print(
		"BLOSSOM TALENT EFFECTS SMOKE TEST FAIL: %d failure(s)"
		% failures.size()
	)
	get_tree().quit(1)


func test_resources_and_dispatch() -> void:
	var branch_definition: BranchDefinition = (
		load(BLOSSOM_BRANCH_DEFINITION_PATH)
		as BranchDefinition
	)

	expect(
		is_instance_valid(branch_definition),
		"Blossom BranchDefinition is missing."
	)

	if not is_instance_valid(branch_definition):
		return

	expect(
		branch_definition.is_valid_definition(),
		"Blossom BranchDefinition is invalid."
	)
	expect(
		is_instance_valid(branch_definition.talent_tree),
		"Blossom BranchDefinition has no TalentTree."
	)

	var talent_tree: TalentTreeDefinition = (
		branch_definition.talent_tree
	)

	if not is_instance_valid(talent_tree):
		return

	expect(
		talent_tree.is_valid_definition(),
		"Blossom TalentTree is invalid."
	)
	expect(
		talent_tree.talent_tree_id
		== &"blossom_talent_tree",
		"Blossom TalentTree has the wrong stable ID."
	)
	expect(
		talent_tree.display_name == "Blossom Talents",
		"Blossom TalentTree has the wrong display name."
	)
	expect(
		talent_tree.get_talent_ids()
		== EXPECTED_TALENT_IDS,
		"Blossom talents are not in the required order."
	)

	var fixture := create_fixture("ResourceFixture")
	var tree_node := create_mock_tree(fixture)
	var blossom_branch := create_blossom_branch(
		tree_node,
		"ResourceBlossom"
	)
	var effect_set: BlossomTalentEffectSet = (
		blossom_branch.get("talent_effect_set")
		as BlossomTalentEffectSet
	)

	expect(
		is_instance_valid(effect_set),
		"Blossom did not create its own talent effect set."
	)

	if not is_instance_valid(effect_set):
		await cleanup_fixture(fixture)
		return

	var supported_effect_ids: Array[StringName] = (
		effect_set.get_supported_effect_ids()
	)
	var unique_effect_ids: Dictionary = {}

	for talent_index in range(TALENT_RESOURCE_PATHS.size()):
		var resource_path: String = (
			TALENT_RESOURCE_PATHS[talent_index]
		)
		var talent_definition: TalentDefinition = (
			load(resource_path) as TalentDefinition
		)

		expect(
			is_instance_valid(talent_definition),
			"Blossom TalentDefinition is missing: %s"
			% resource_path
		)

		if not is_instance_valid(talent_definition):
			continue

		resource_snapshots[resource_path] = {
			"talent_id": talent_definition.talent_id,
			"display_name": talent_definition.display_name,
			"path_name": talent_definition.path_name,
			"required_branch_level": (
				talent_definition.required_branch_level
			),
			"talent_point_cost": (
				talent_definition.talent_point_cost
			),
			"prerequisite_ids": (
				talent_definition.prerequisite_ids.duplicate()
			),
			"conflicting_ids": (
				talent_definition.conflicting_ids.duplicate()
			),
			"effect_ids": talent_definition.effect_ids.duplicate()
		}

		expect(
			talent_definition.talent_id
			== EXPECTED_TALENT_IDS[talent_index],
			"Blossom TalentDefinition has an unexpected ID."
		)
		expect(
			talent_definition.required_branch_level == 2,
			"Blossom talent does not require Branch Level 2."
		)
		expect(
			talent_definition.talent_point_cost == 1,
			"Blossom talent does not cost one Talent Point."
		)
		expect(
			talent_definition.prerequisite_ids.is_empty(),
			"Blossom talent has an unexpected prerequisite."
		)
		expect(
			talent_definition.conflicting_ids.is_empty(),
			"Blossom talent has an unexpected conflict."
		)
		expect(
			talent_definition.effect_ids.size() == 1,
			"Blossom talent does not have exactly one effect ID."
		)

		if talent_definition.effect_ids.size() != 1:
			continue

		var effect_id: StringName = (
			talent_definition.effect_ids[0]
		)

		expect(
			effect_id != &"",
			"Blossom talent has an empty effect ID."
		)
		expect(
			not unique_effect_ids.has(effect_id),
			"Blossom effect ID '%s' is duplicated."
			% effect_id
		)
		expect(
			effect_id in supported_effect_ids,
			"Blossom effect ID '%s' is unsupported."
			% effect_id
		)
		expect(
			not effect_set.has_active_effect(effect_id),
			"An unpurchased Blossom effect is active."
		)

		unique_effect_ids[effect_id] = true

	expect(
		blossom_branch.call(
			"get_active_talent_effect_ids"
		).is_empty(),
		"Blossom has active effect IDs without purchases."
	)

	await cleanup_fixture(fixture)


func test_base_runtime() -> void:
	var fixture := create_fixture("BaseRuntimeFixture")
	var tree_node := create_mock_tree(fixture)
	var blossom_branch := create_blossom_branch(
		tree_node,
		"BaseBlossom"
	)
	var primary := create_enemy(
		fixture,
		"Primary",
		Vector2(200.0, 0.0)
	)
	var another_enemy := create_enemy(
		fixture,
		"AnotherEnemy",
		Vector2(120.0, 0.0)
	)

	expect_value(
		float(blossom_branch.call("get_current_healing_per_tick")),
		3.0,
		"Base healing per tick"
	)
	expect_value(
		float(blossom_branch.call("get_current_healing_tick_interval")),
		2.0,
		"Base healing interval"
	)
	expect_value(
		float(blossom_branch.call("get_current_petal_damage")),
		3.0,
		"Base petal damage"
	)

	blossom_branch.call("perform_ranged_attack", primary)
	var projectiles: Array[BlossomProjectile] = get_projectiles()

	expect(
		projectiles.size() == 1,
		"Base Blossom attack did not create exactly one projectile."
	)

	if projectiles.size() == 1:
		var projectile: BlossomProjectile = projectiles[0]
		expect(
			projectile.target == primary,
			"Base projectile changed its primary target."
		)
		expect_value(
			projectile.damage,
			3.0,
			"Base primary projectile damage"
		)
		expect(
			projectile.damage_source == blossom_branch,
			"Base projectile has the wrong source Blossom."
		)
		projectile.call("hit_target")

	expect_damage(primary, 0, 3.0, "Base primary")
	expect(
		another_enemy.damage_events.is_empty(),
		"Base Blossom attack created secondary damage."
	)

	await cleanup_fixture(fixture)


func test_abundant_bloom() -> void:
	var fixture := create_fixture("AbundantBloomFixture")
	var tree_node := create_mock_tree(fixture)
	var blossom_branch := create_blossom_branch(
		tree_node,
		"AbundantBlossom"
	)

	blossom_branch.set("healing_refresh_time_remaining", 5.0)
	purchase_talents(
		blossom_branch,
		[&"abundant_bloom"]
	)

	expect_value(
		float(blossom_branch.call("get_current_healing_per_tick")),
		4.5,
		"Abundant Bloom base healing"
	)
	expect_value(
		float(blossom_branch.call("get_current_healing_tick_interval")),
		2.0,
		"Abundant Bloom healing interval isolation"
	)
	expect_value(
		float(blossom_branch.call("get_current_petal_damage")),
		3.0,
		"Abundant Bloom petal damage isolation"
	)
	expect_value(
		float(blossom_branch.get("healing_refresh_time_remaining")),
		0.0,
		"Talent purchase healing refresh"
	)

	expect(
		bool(
			blossom_branch.call(
				"purchase_upgrade",
				&"healing_per_tick"
			)
		),
		"Could not purchase one Blossom healing upgrade."
	)
	expect_value(
		float(blossom_branch.call("get_current_healing_per_tick")),
		6.0,
		"Abundant Bloom upgraded healing"
	)

	await cleanup_fixture(fixture)


func test_quickening_pollen() -> void:
	var fixture := create_fixture("QuickeningPollenFixture")
	var tree_node := create_mock_tree(fixture)
	var blossom_branch := create_blossom_branch(
		tree_node,
		"QuickeningBlossom"
	)

	purchase_talents(
		blossom_branch,
		[&"quickening_pollen"]
	)

	expect_value(
		float(blossom_branch.call("get_current_healing_tick_interval")),
		1.6,
		"Quickening Pollen base interval"
	)
	expect_value(
		float(blossom_branch.call("get_current_healing_per_tick")),
		3.0,
		"Quickening Pollen healing isolation"
	)
	expect_value(
		float(blossom_branch.call("get_current_petal_damage")),
		3.0,
		"Quickening Pollen petal isolation"
	)

	set_shared_progress(blossom_branch, 2, 0, &"healing_speed", 10)
	expect_value(
		float(blossom_branch.call("get_current_healing_tick_interval")),
		0.8,
		"Quickening Pollen post-upgrade interval"
	)

	set_shared_progress(blossom_branch, 2, 0, &"healing_speed", 12)
	expect_value(
		float(blossom_branch.call("get_current_healing_tick_interval")),
		0.75,
		"Quickening Pollen minimum interval"
	)

	set_shared_progress(blossom_branch, 10, 0, &"healing_speed", 11)
	expect(
		bool(
			blossom_branch.call(
				"purchase_upgrade",
				&"healing_speed"
			)
		),
		"Quickening Pollen blocked Healing Speed level 12."
	)
	expect(
		bool(
			blossom_branch.call(
				"purchase_upgrade",
				&"healing_speed"
			)
		),
		"Quickening Pollen blocked Healing Speed level 13."
	)
	expect(
		int(blossom_branch.get("healing_speed_upgrade_level")) == 13,
		"Healing Speed did not retain its level-13 cap."
	)
	expect_value(
		float(blossom_branch.call("get_current_healing_tick_interval")),
		0.75,
		"Quickening Pollen final minimum interval"
	)

	await cleanup_fixture(fixture)


func test_twin_petals() -> void:
	await test_twin_petals_damage_and_feedback()
	await test_twin_petals_target_selection()
	await test_twin_petals_single_target()


func test_twin_petals_damage_and_feedback() -> void:
	var fixture := create_fixture("TwinPetalsDamageFixture")
	var tree_node := create_mock_tree(fixture)
	var blossom_branch := create_blossom_branch(
		tree_node,
		"TwinPetalsBlossom"
	)
	var primary := create_enemy(
		fixture,
		"Primary",
		Vector2(240.0, 0.0)
	)
	var secondary := create_enemy(
		fixture,
		"Secondary",
		Vector2(120.0, 0.0)
	)

	purchase_talents(
		blossom_branch,
		[&"twin_petals"]
	)

	var expected_spawn_position: Vector2 = (
		blossom_branch.call(
			"get_projectile_spawn_position"
		)
	)
	var tween_count_before: int = (
		get_tree().get_processed_tweens().size()
	)

	blossom_branch.call("perform_ranged_attack", primary)
	var projectiles: Array[BlossomProjectile] = get_projectiles()
	var tween_count_after: int = (
		get_tree().get_processed_tweens().size()
	)

	expect(
		projectiles.size() == 2,
		"Twin Petals did not create exactly two projectiles."
	)
	expect(
		tween_count_after == tween_count_before + 1,
		"Twin Petals did not create exactly one feedback tween."
	)

	var primary_projectile: BlossomProjectile = null
	var secondary_projectile: BlossomProjectile = null

	for projectile in projectiles:
		projectile.process_mode = Node.PROCESS_MODE_DISABLED

		if projectile.target == primary:
			primary_projectile = projectile
		elif projectile.target == secondary:
			secondary_projectile = projectile

	expect(
		is_instance_valid(primary_projectile),
		"Twin Petals lost the primary projectile."
	)
	expect(
		is_instance_valid(secondary_projectile),
		"Twin Petals did not use the second target."
	)
	expect(
		primary != secondary,
		"Twin Petals reused the primary target."
	)

	if is_instance_valid(primary_projectile):
		expect_value(
			primary_projectile.damage,
			3.0,
			"Twin Petals primary damage"
		)
		expect(
			primary_projectile.damage_source == blossom_branch,
			"Twin Petals primary source changed."
		)
		expect_vector(
			primary_projectile.global_position,
			expected_spawn_position,
			"Twin Petals primary spawn"
		)
		primary_projectile.call("hit_target")

	if is_instance_valid(secondary_projectile):
		expect_value(
			secondary_projectile.damage,
			1.8,
			"Twin Petals secondary damage"
		)
		expect(
			secondary_projectile.damage_source == blossom_branch,
			"Twin Petals secondary source changed."
		)
		expect_vector(
			secondary_projectile.global_position,
			expected_spawn_position,
			"Twin Petals secondary spawn"
		)
		secondary_projectile.call("hit_target")

	expect_damage(primary, 0, 3.0, "Twin Petals primary")
	expect_damage(secondary, 0, 1.8, "Twin Petals secondary")

	await cleanup_fixture(fixture)


func test_twin_petals_target_selection() -> void:
	var fixture := create_fixture("TwinPetalsTargetFixture")
	var tree_node := create_mock_tree(fixture)
	var blossom_branch := create_blossom_branch(
		tree_node,
		"TargetingBlossom"
	)
	var primary := create_enemy(
		fixture,
		"Primary",
		Vector2(300.0, 0.0)
	)
	var closest_preferred := create_enemy(
		fixture,
		"ClosestPreferred",
		Vector2(100.0, 0.0)
	)
	var farther_preferred := create_enemy(
		fixture,
		"FartherPreferred",
		Vector2(180.0, 0.0)
	)
	var fallback := create_enemy(
		fixture,
		"Fallback",
		Vector2(-80.0, 0.0)
	)
	var outside_range := create_enemy(
		fixture,
		"OutsideRange",
		Vector2(700.0, 0.0)
	)

	purchase_talents(
		blossom_branch,
		[&"twin_petals"]
	)

	var effect_set: BlossomTalentEffectSet = (
		blossom_branch.get("talent_effect_set")
		as BlossomTalentEffectSet
	)

	expect(
		effect_set.find_secondary_petal_target(primary)
		== closest_preferred,
		"Twin Petals did not choose the closest enemy to the tree "
		+ "on the preferred side."
	)
	expect(
		effect_set.find_secondary_petal_target(primary)
		!= farther_preferred,
		"Twin Petals chose a farther preferred-side enemy."
	)
	expect(
		effect_set.find_secondary_petal_target(primary)
		!= outside_range,
		"Twin Petals selected an enemy outside range 650."
	)

	closest_preferred.targetable = false
	farther_preferred.targetable = false

	expect(
		effect_set.find_secondary_petal_target(primary)
		== fallback,
		"Twin Petals did not fall back to the opposite side."
	)

	fallback.targetable = false
	expect(
		effect_set.find_secondary_petal_target(primary) == null,
		"Twin Petals used an invalid or out-of-range fallback target."
	)

	await cleanup_fixture(fixture)


func test_twin_petals_single_target() -> void:
	var fixture := create_fixture("TwinPetalsSingleFixture")
	var tree_node := create_mock_tree(fixture)
	var blossom_branch := create_blossom_branch(
		tree_node,
		"SingleTargetBlossom"
	)
	var primary := create_enemy(
		fixture,
		"OnlyEnemy",
		Vector2(200.0, 0.0)
	)

	purchase_talents(
		blossom_branch,
		[&"twin_petals"]
	)
	blossom_branch.call("perform_ranged_attack", primary)

	expect(
		get_projectiles().size() == 1,
		"Twin Petals created a secondary projectile without a target."
	)

	await cleanup_fixture(fixture)


func test_combined_effects_and_instances() -> void:
	var fixture := create_fixture("CombinedEffectsFixture")
	var tree_node := create_mock_tree(fixture)
	var first_blossom := create_blossom_branch(
		tree_node,
		"FirstBlossom"
	)
	var second_blossom := create_blossom_branch(
		tree_node,
		"SecondBlossom"
	)
	var primary := create_enemy(
		fixture,
		"CombinedPrimary",
		Vector2(220.0, 0.0)
	)
	create_enemy(
		fixture,
		"CombinedSecondary",
		Vector2(100.0, 0.0)
	)

	purchase_talents(
		first_blossom,
		EXPECTED_TALENT_IDS
	)

	expect_value(
		float(first_blossom.call("get_current_healing_per_tick")),
		4.5,
		"Combined Blossom healing"
	)
	expect_value(
		float(first_blossom.call("get_current_healing_tick_interval")),
		1.6,
		"Combined Blossom interval"
	)
	expect_value(
		float(first_blossom.call("get_current_petal_damage")),
		3.0,
		"Combined Blossom petal damage"
	)

	first_blossom.call("perform_ranged_attack", primary)
	expect(
		get_projectiles().size() == 2,
		"Twin Petals did not work with both healing talents active."
	)

	expect_value(
		float(second_blossom.call("get_current_healing_per_tick")),
		4.5,
		"Second Blossom shared talent healing"
	)
	expect_value(
		float(second_blossom.call("get_current_healing_tick_interval")),
		1.6,
		"Second Blossom shared talent interval"
	)
	expect_value(
		float(second_blossom.call("get_current_petal_damage")),
		3.0,
		"Second Blossom petal isolation"
	)
	expect(
		second_blossom.call(
			"get_active_talent_effect_ids"
		) == EXPECTED_TALENT_IDS,
		"Second Blossom did not receive shared talent purchases."
	)

	var first_effect_set: BlossomTalentEffectSet = (
		first_blossom.get("talent_effect_set")
		as BlossomTalentEffectSet
	)
	var second_effect_set: BlossomTalentEffectSet = (
		second_blossom.get("talent_effect_set")
		as BlossomTalentEffectSet
	)

	expect(
		first_effect_set != second_effect_set,
		"Two Blossom instances share one talent effect set."
	)

	first_blossom.call("stop_combat")
	first_blossom.call("resume_combat")

	expect(
		first_blossom.call(
			"get_active_talent_effect_ids"
		) == EXPECTED_TALENT_IDS,
		"Combat lifecycle cleared purchased Blossom talents."
	)

	for effect_id in EXPECTED_TALENT_IDS:
		expect(
			first_effect_set.has_active_effect(effect_id),
			"Combat lifecycle deactivated Blossom effect '%s'."
			% effect_id
		)

	await cleanup_fixture(fixture)


func verify_resource_snapshots() -> void:
	for resource_path in TALENT_RESOURCE_PATHS:
		var talent_definition: TalentDefinition = (
			load(resource_path) as TalentDefinition
		)
		var snapshot: Dictionary = resource_snapshots.get(
			resource_path,
			{}
		)

		expect(
			is_instance_valid(talent_definition),
			"Shared Blossom TalentDefinition disappeared."
		)
		expect(
			not snapshot.is_empty(),
			"Blossom TalentDefinition snapshot is missing."
		)

		if (
			not is_instance_valid(talent_definition)
			or snapshot.is_empty()
		):
			continue

		expect(
			talent_definition.talent_id == snapshot["talent_id"]
			and talent_definition.display_name
			== snapshot["display_name"]
			and talent_definition.path_name
			== snapshot["path_name"]
			and talent_definition.required_branch_level
			== snapshot["required_branch_level"]
			and talent_definition.talent_point_cost
			== snapshot["talent_point_cost"]
			and talent_definition.prerequisite_ids
			== snapshot["prerequisite_ids"]
			and talent_definition.conflicting_ids
			== snapshot["conflicting_ids"]
			and talent_definition.effect_ids
			== snapshot["effect_ids"],
			"Shared Blossom TalentDefinition was mutated at runtime: %s"
			% resource_path
		)


func create_fixture(
	fixture_name: String
) -> Node2D:
	var fixture := Node2D.new()
	fixture.name = fixture_name
	var progress_service := BranchProgressService.new()
	progress_service.name = "BranchProgressService"
	fixture.add_child(progress_service)
	add_child(fixture)
	return fixture


func create_mock_tree(
	fixture: Node2D
) -> MockTree:
	var tree_node := MockTree.new()
	tree_node.name = "MockTree"
	fixture.add_child(tree_node)
	return tree_node


func create_blossom_branch(
	tree_node: MockTree,
	branch_name: String
) -> Node2D:
	var blossom_branch: Node2D = (
		BLOSSOM_SCENE.instantiate()
	)
	blossom_branch.name = branch_name
	blossom_branch.process_mode = Node.PROCESS_MODE_DISABLED
	blossom_branch.set("facing_side", 1)
	blossom_branch.set(
		"branch_progress_service",
		tree_node.get_parent().get_node("BranchProgressService")
	)
	tree_node.add_child(blossom_branch)
	return blossom_branch


func create_enemy(
	fixture: Node2D,
	enemy_name: String,
	enemy_position: Vector2
) -> MockEnemy:
	var enemy := MockEnemy.new()
	enemy.name = enemy_name
	enemy.position = enemy_position
	fixture.add_child(enemy)
	enemy.add_to_group("enemies")
	return enemy


func purchase_talents(
	blossom_branch: Node2D,
	talent_ids: Array[StringName]
) -> void:
	set_shared_progress(
		blossom_branch,
		2,
		talent_ids.size()
	)

	for talent_id in talent_ids:
		expect(
			bool(
				blossom_branch.call(
					"purchase_talent",
					talent_id
				)
			),
			"Could not purchase Blossom talent '%s'."
			% talent_id
		)


func set_shared_progress(
	blossom_branch: Node2D,
	branch_level: int,
	available_points: int,
	upgrade_id: StringName = &"",
	upgrade_level: int = 0
) -> void:
	var progress_service: BranchProgressService = blossom_branch.get(
		"branch_progress_service"
	) as BranchProgressService
	var progress: BranchProgressRecord = progress_service.get_progress(
		&"blossom_branch"
	)
	progress.branch_level = branch_level
	progress.available_talent_points = available_points
	progress.total_talent_points_earned = max(
		progress.total_talent_points_earned,
		available_points
	)

	if upgrade_id != &"":
		progress.set_upgrade_level(upgrade_id, upgrade_level)

	progress_service.synchronize_branch(blossom_branch as CombatBranch)


func get_projectiles() -> Array[BlossomProjectile]:
	var projectiles: Array[BlossomProjectile] = []

	for child in get_children():
		if child is BlossomProjectile:
			projectiles.append(
				child as BlossomProjectile
			)

	return projectiles


func cleanup_fixture(
	fixture: Node2D
) -> void:
	for projectile in get_projectiles():
		projectile.queue_free()

	fixture.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func expect_damage(
	enemy: MockEnemy,
	event_index: int,
	expected_damage: float,
	label: String
) -> void:
	expect(
		enemy.damage_events.size() > event_index,
		"%s did not resolve damage event %d."
		% [label, event_index]
	)

	if enemy.damage_events.size() <= event_index:
		return

	expect_value(
		enemy.damage_events[event_index],
		expected_damage,
		label
	)


func expect_value(
	actual_value: float,
	expected_value: float,
	label: String
) -> void:
	expect(
		is_equal_approx(
			actual_value,
			expected_value
		),
		"%s was %.3f instead of %.3f."
		% [label, actual_value, expected_value]
	)


func expect_vector(
	actual_value: Vector2,
	expected_value: Vector2,
	label: String
) -> void:
	expect(
		actual_value.is_equal_approx(expected_value),
		"%s was %s instead of %s."
		% [label, actual_value, expected_value]
	)


func expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	failures.append(message)
	push_error(message)
