extends Node


const STRENGTH_SCENE: PackedScene = preload(
	"res://scenes/branches/strength_branch.tscn"
)

const TALENT_RESOURCE_PATHS: Array[String] = [
	"res://resources/talents/strength/sweeping_strike.tres",
	"res://resources/talents/strength/rebuff.tres",
	"res://resources/talents/strength/marked_prey.tres"
]


class MockEnemy:
	extends Node2D

	var lane_index: int = 0
	var targetable: bool = true
	var damage_events: Array[float] = []
	var knockback_events: Array[float] = []


	func is_targetable() -> bool:
		return targetable


	func get_lane_index() -> int:
		return lane_index


	func take_damage(
		amount: float,
		_source: Node = null
	) -> void:
		damage_events.append(amount)


	func apply_knockback(
		distance: float
	) -> void:
		knockback_events.append(distance)


class MockEnemyWithoutKnockback:
	extends Node2D

	var lane_index: int = 0
	var targetable: bool = true
	var damage_events: Array[float] = []


	func is_targetable() -> bool:
		return targetable


	func get_lane_index() -> int:
		return lane_index


	func take_damage(
		amount: float,
		_source: Node = null
	) -> void:
		damage_events.append(amount)


var failures: Array[String] = []


func _ready() -> void:
	await test_resources_and_dispatch()
	await test_base_attack()
	await test_marked_prey()
	await test_sweeping_strike()
	await test_rebuff()
	await test_combined_effects()

	expect(
		get_tree().get_nodes_in_group(
			"enemies"
		).is_empty(),
		"Strength talent test left an enemy group member."
	)

	expect(
		get_tree().get_nodes_in_group(
			"strength_branch"
		).is_empty(),
		"Strength talent test left a Strength group member."
	)

	expect(
		get_tree().get_nodes_in_group(
			"combat_branch"
		).is_empty(),
		"Strength talent test left a combat branch group member."
	)

	if failures.is_empty():
		print("STRENGTH TALENT EFFECTS SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print(
		"STRENGTH TALENT EFFECTS SMOKE TEST FAIL: %d failure(s)"
		% failures.size()
	)
	get_tree().quit(1)


func test_resources_and_dispatch() -> void:
	var fixture := create_fixture(
		"ResourcesAndDispatchFixture"
	)
	var strength_branch: Node2D = create_strength_branch(
		fixture,
		"DispatchStrength"
	)

	var effect_set: StrengthTalentEffectSet = (
		strength_branch.get("talent_effect_set")
		as StrengthTalentEffectSet
	)

	expect(
		is_instance_valid(effect_set),
		"Strength did not create its own talent effect set."
	)

	var supported_effect_ids: Array[StringName] = (
		effect_set.get_supported_effect_ids()
	)
	var resource_effect_ids: Array[StringName] = []
	var unique_effect_ids: Dictionary = {}

	for resource_path in TALENT_RESOURCE_PATHS:
		var talent_definition: TalentDefinition = (
			load(resource_path) as TalentDefinition
		)

		expect(
			is_instance_valid(talent_definition),
			"Strength TalentDefinition is missing: %s"
			% resource_path
		)

		if not is_instance_valid(talent_definition):
			continue

		expect(
			talent_definition.effect_ids.size() == 1,
			"Talent '%s' does not have exactly one effect ID."
			% talent_definition.talent_id
		)

		if talent_definition.effect_ids.size() != 1:
			continue

		var effect_id: StringName = (
			talent_definition.effect_ids[0]
		)

		expect(
			effect_id != &"",
			"Talent '%s' has an empty effect ID."
			% talent_definition.talent_id
		)

		expect(
			not unique_effect_ids.has(effect_id),
			"Strength talent effect ID '%s' is duplicated."
			% effect_id
		)

		unique_effect_ids[effect_id] = true
		resource_effect_ids.append(effect_id)

		expect(
			effect_set.has_active_effect(effect_id) == false,
			"An unpurchased Strength talent effect is active."
		)

		expect(
			effect_id in supported_effect_ids,
			"Effect ID '%s' is not supported by the effect set."
			% effect_id
		)

	var initially_active_ids: Array[StringName] = (
		strength_branch.call(
			"get_active_talent_effect_ids"
		) as Array[StringName]
	)

	expect(
		initially_active_ids.is_empty(),
		"Strength has active effect IDs without purchases."
	)

	purchase_talents(
		strength_branch,
		[
			&"sweeping_strike",
			&"rebuff",
			&"marked_prey"
		]
	)

	var active_ids: Array[StringName] = (
		strength_branch.call(
			"get_active_talent_effect_ids"
		) as Array[StringName]
	)

	expect(
		active_ids == resource_effect_ids,
		"Purchased effects do not follow TalentTree data order."
	)

	for effect_id in resource_effect_ids:
		expect(
			effect_set.has_active_effect(effect_id),
			"Purchased effect ID '%s' was not activated."
			% effect_id
		)

	test_data_driven_effect_collection(
		strength_branch,
		effect_set
	)

	await cleanup_fixture(fixture)


func test_data_driven_effect_collection(
	strength_branch: Node2D,
	effect_set: StrengthTalentEffectSet
) -> void:
	var first_talent := TalentDefinition.new()
	first_talent.talent_id = &"synthetic_alpha"
	var first_effect_ids: Array[StringName] = [
		&"",
		&"rebuff",
		&"sweeping_strike"
	]
	first_talent.effect_ids = first_effect_ids

	var second_talent := TalentDefinition.new()
	second_talent.talent_id = &"synthetic_beta"
	var second_effect_ids: Array[StringName] = [
		&"rebuff",
		&"marked_prey"
	]
	second_talent.effect_ids = second_effect_ids

	var synthetic_tree := TalentTreeDefinition.new()
	var synthetic_talents: Array[TalentDefinition] = [
		first_talent,
		second_talent
	]
	synthetic_tree.talents = synthetic_talents

	var synthetic_purchases: Dictionary = {}
	synthetic_purchases[first_talent.talent_id] = true
	synthetic_purchases[second_talent.talent_id] = true

	strength_branch.set(
		"talent_tree_definition",
		synthetic_tree
	)
	strength_branch.set(
		"purchased_talents",
		synthetic_purchases
	)

	var active_ids: Array[StringName] = (
		strength_branch.call(
			"get_active_talent_effect_ids"
		) as Array[StringName]
	)

	var expected_ids: Array[StringName] = [
		&"rebuff",
		&"sweeping_strike",
		&"marked_prey"
	]

	expect(
		active_ids == expected_ids,
		"CombatBranch did not ignore empty IDs, remove duplicates, "
		+ "or preserve first data order."
	)

	strength_branch.call(
		"sync_active_talent_effects"
	)

	for effect_id in expected_ids:
		expect(
			effect_set.has_active_effect(effect_id),
			"Synthetic talent ID did not activate data effect '%s'."
			% effect_id
		)


func test_base_attack() -> void:
	var fixture := create_fixture("BaseAttackFixture")
	var strength_branch: Node2D = create_strength_branch(
		fixture,
		"BaseStrength"
	)
	var primary: MockEnemy = create_enemy(
		fixture,
		"Primary",
		Vector2(60.0, 0.0),
		3
	)
	var nearby_enemy: MockEnemy = create_enemy(
		fixture,
		"NearbyEnemy",
		Vector2(90.0, 0.0),
		3
	)

	strength_branch.call(
		"perform_strength_hit",
		primary
	)

	expect_damage(primary.damage_events, 0, 10.0, "Base primary")
	expect(
		nearby_enemy.damage_events.is_empty(),
		"Base attack created a secondary hit."
	)
	expect(
		primary.knockback_events.is_empty(),
		"Base attack created primary knockback."
	)
	expect(
		nearby_enemy.knockback_events.is_empty(),
		"Base attack created secondary knockback."
	)

	var effect_set: StrengthTalentEffectSet = (
		strength_branch.get("talent_effect_set")
		as StrengthTalentEffectSet
	)

	expect_marked_state(
		effect_set,
		0,
		0,
		"Base attack"
	)

	await cleanup_fixture(fixture)


func test_marked_prey() -> void:
	var fixture := create_fixture("MarkedPreyFixture")
	var first_branch: Node2D = create_strength_branch(
		fixture,
		"FirstMarkedStrength"
	)
	var target_a: MockEnemy = create_enemy(
		fixture,
		"TargetA",
		Vector2(60.0, 0.0),
		3
	)
	var target_b: MockEnemy = create_enemy(
		fixture,
		"TargetB",
		Vector2(90.0, 0.0),
		3
	)

	purchase_talents(
		first_branch,
		[&"marked_prey"]
	)

	for hit_index in range(7):
		first_branch.call(
			"perform_strength_hit",
			target_a
		)

	var expected_damage: Array[float] = [
		10.0,
		11.0,
		12.0,
		13.0,
		14.0,
		15.0,
		15.0
	]

	for damage_index in range(expected_damage.size()):
		expect_damage(
			target_a.damage_events,
			damage_index,
			expected_damage[damage_index],
			"Marked Prey target A hit %d"
			% (damage_index + 1)
		)

	first_branch.call(
		"perform_strength_hit",
		target_b
	)
	expect_damage(
		target_b.damage_events,
		0,
		10.0,
		"Marked Prey first target B hit"
	)

	var first_effect_set: StrengthTalentEffectSet = (
		first_branch.get("talent_effect_set")
		as StrengthTalentEffectSet
	)

	first_effect_set.reset_runtime_state()
	first_branch.call(
		"perform_strength_hit",
		target_b
	)
	expect_damage(
		target_b.damage_events,
		1,
		10.0,
		"Marked Prey post-reset hit"
	)

	first_branch.call(
		"perform_strength_hit",
		target_b
	)
	expect_marked_state(
		first_effect_set,
		target_b.get_instance_id(),
		1,
		"Marked Prey before stop"
	)

	first_branch.call("stop_combat")
	expect_marked_state(
		first_effect_set,
		0,
		0,
		"Marked Prey stop_combat reset"
	)

	first_branch.call(
		"perform_strength_hit",
		target_b
	)
	first_branch.call("resume_combat")
	var first_timer := first_branch.get_node(
		"CooldownTimer"
	) as Timer
	first_timer.stop()
	expect_marked_state(
		first_effect_set,
		0,
		0,
		"Marked Prey resume_combat reset"
	)

	var second_branch: Node2D = create_strength_branch(
		fixture,
		"SecondMarkedStrength"
	)
	second_branch.position = Vector2(300.0, 0.0)
	var target_c: MockEnemy = create_enemy(
		fixture,
		"TargetC",
		Vector2(360.0, 0.0),
		3
	)

	expect(
		bool(second_branch.call("has_talent", &"marked_prey")),
		"Second Strength did not receive the shared talent purchase."
	)

	first_branch.call(
		"perform_strength_hit",
		target_a
	)
	first_branch.call(
		"perform_strength_hit",
		target_a
	)
	second_branch.call(
		"perform_strength_hit",
		target_c
	)

	var second_effect_set: StrengthTalentEffectSet = (
		second_branch.get("talent_effect_set")
		as StrengthTalentEffectSet
	)

	expect_marked_state(
		first_effect_set,
		target_a.get_instance_id(),
		1,
		"First Strength independent Marked state"
	)
	expect_marked_state(
		second_effect_set,
		target_c.get_instance_id(),
		0,
		"Second Strength independent Marked state"
	)
	expect(
		first_effect_set != second_effect_set,
		"Two Strength instances share one talent effect set."
	)

	await cleanup_fixture(fixture)


func test_sweeping_strike() -> void:
	await test_sweeping_damage_and_context()
	await test_sweeping_radius_and_priority()
	await test_sweeping_with_marked_prey()


func test_sweeping_damage_and_context() -> void:
	var fixture := create_fixture("SweepingDamageFixture")
	var strength_branch: Node2D = create_strength_branch(
		fixture,
		"SweepingStrength"
	)
	var primary: MockEnemy = create_enemy(
		fixture,
		"Primary",
		Vector2(50.0, 0.0),
		3
	)
	var secondary: MockEnemy = create_enemy(
		fixture,
		"Secondary",
		Vector2(80.0, 0.0),
		4
	)

	purchase_talents(
		strength_branch,
		[&"sweeping_strike"]
	)

	strength_branch.call(
		"perform_strength_hit",
		primary
	)

	expect_damage(primary.damage_events, 0, 10.0, "Sweeping primary")
	expect_damage(secondary.damage_events, 0, 6.0, "Sweeping secondary")
	expect(
		primary.damage_events.size() == 1,
		"Primary target was selected again as the secondary target."
	)

	var effect_set: StrengthTalentEffectSet = (
		strength_branch.get("talent_effect_set")
		as StrengthTalentEffectSet
	)
	var context := AttackContext.new(
		strength_branch,
		secondary,
		10.0
	)
	context.add_tag(&"strength")
	context.add_tag(&"secondary_attack")
	context.set_metadata_value(&"sentinel", 42)
	effect_set.configure_secondary_context(context)

	expect(
		context.attack_id == &"strength_sweeping_strike",
		"Sweeping context attack ID changed."
	)
	expect(
		is_equal_approx(context.damage_multiplier, 0.60),
		"Sweeping context multiplier changed from 0.60."
	)
	expect(
		context.is_secondary_attack,
		"Sweeping context is not marked secondary."
	)
	expect(
		context.tags == [
			&"strength",
			&"secondary_attack",
			&"sweeping_strike"
		],
		"Sweeping context tags changed."
	)
	expect(
		context.metadata.size() == 1
		and context.get_metadata_value(&"sentinel") == 42,
		"Sweeping configuration changed AttackContext metadata."
	)

	await cleanup_fixture(fixture)


func test_sweeping_radius_and_priority() -> void:
	var fixture := create_fixture("SweepingPriorityFixture")
	var strength_branch: Node2D = create_strength_branch(
		fixture,
		"PriorityStrength"
	)
	var primary: MockEnemy = create_enemy(
		fixture,
		"Primary",
		Vector2(10.0, 0.0),
		3
	)
	var outside_radius: MockEnemy = create_enemy(
		fixture,
		"OutsideRadius",
		Vector2(135.0, 0.0),
		3
	)

	purchase_talents(
		strength_branch,
		[&"sweeping_strike"]
	)

	var effect_set: StrengthTalentEffectSet = (
		strength_branch.get("talent_effect_set")
		as StrengthTalentEffectSet
	)

	expect(
		effect_set.find_secondary_target(primary) == null,
		"Sweeping selected a target beyond radius 120."
	)

	outside_radius.targetable = false
	primary.position = Vector2(30.0, 0.0)

	var closer_wrong_lane: MockEnemy = create_enemy(
		fixture,
		"CloserWrongLane",
		Vector2(40.0, 0.0),
		5
	)
	var farther_preferred_lane: MockEnemy = create_enemy(
		fixture,
		"FartherPreferredLane",
		Vector2(100.0, 0.0),
		4
	)

	expect(
		effect_set.find_secondary_target(primary)
		== farther_preferred_lane,
		"Sweeping did not prioritize the smaller lane difference."
	)

	closer_wrong_lane.targetable = false
	farther_preferred_lane.targetable = false

	var closer_tied_lane: MockEnemy = create_enemy(
		fixture,
		"CloserTiedLane",
		Vector2(50.0, 0.0),
		4
	)
	var farther_tied_lane: MockEnemy = create_enemy(
		fixture,
		"FartherTiedLane",
		Vector2(90.0, 0.0),
		2
	)

	expect(
		effect_set.find_secondary_target(primary)
		== closer_tied_lane,
		"Sweeping did not use distance as the lane tie-break."
	)
	expect(
		effect_set.find_secondary_target(primary)
		!= farther_tied_lane,
		"Sweeping chose the farther target on an equal lane difference."
	)

	await cleanup_fixture(fixture)


func test_sweeping_with_marked_prey() -> void:
	var fixture := create_fixture("SweepingMarkedFixture")
	var strength_branch: Node2D = create_strength_branch(
		fixture,
		"SweepingMarkedStrength"
	)
	var primary: MockEnemy = create_enemy(
		fixture,
		"Primary",
		Vector2(50.0, 0.0),
		3
	)
	var secondary: MockEnemy = create_enemy(
		fixture,
		"Secondary",
		Vector2(80.0, 0.0),
		4
	)

	purchase_talents(
		strength_branch,
		[
			&"sweeping_strike",
			&"marked_prey"
		]
	)

	strength_branch.call("perform_strength_hit", primary)
	strength_branch.call("perform_strength_hit", primary)

	expect_damage(
		primary.damage_events,
		1,
		11.0,
		"Marked primary with Sweeping"
	)
	expect_damage(
		secondary.damage_events,
		0,
		6.0,
		"First Sweeping secondary without Marked bonus"
	)
	expect_damage(
		secondary.damage_events,
		1,
		6.0,
		"Repeated Sweeping secondary without Marked bonus"
	)

	await cleanup_fixture(fixture)


func test_rebuff() -> void:
	var fixture := create_fixture("RebuffFixture")
	var strength_branch: Node2D = create_strength_branch(
		fixture,
		"RebuffStrength"
	)
	var primary: MockEnemy = create_enemy(
		fixture,
		"Primary",
		Vector2(50.0, 0.0),
		3
	)
	var secondary: MockEnemy = create_enemy(
		fixture,
		"Secondary",
		Vector2(80.0, 0.0),
		4
	)

	purchase_talents(
		strength_branch,
		[
			&"sweeping_strike",
			&"rebuff"
		]
	)

	strength_branch.call("perform_strength_hit", primary)

	expect_knockback(primary, 0, 35.0, "Rebuff primary")
	expect_knockback(secondary, 0, 35.0, "Rebuff secondary")

	var invalid_target: MockEnemy = create_enemy(
		fixture,
		"InvalidTarget",
		Vector2(100.0, 0.0),
		3
	)
	invalid_target.targetable = false
	strength_branch.call(
		"perform_strength_hit",
		invalid_target
	)
	expect(
		invalid_target.damage_events.is_empty(),
		"Invalid target received a resolved hit."
	)
	expect(
		invalid_target.knockback_events.is_empty(),
		"Invalid target received Rebuff knockback."
	)

	primary.targetable = false
	secondary.targetable = false

	var no_knockback_target := MockEnemyWithoutKnockback.new()
	no_knockback_target.name = "NoKnockbackTarget"
	no_knockback_target.position = Vector2(70.0, 0.0)
	no_knockback_target.lane_index = 3
	fixture.add_child(no_knockback_target)
	no_knockback_target.add_to_group("enemies")

	strength_branch.call(
		"perform_strength_hit",
		no_knockback_target
	)
	expect_damage(
		no_knockback_target.damage_events,
		0,
		10.0,
		"Target without apply_knockback"
	)

	await cleanup_fixture(fixture)


func test_combined_effects() -> void:
	var fixture := create_fixture("CombinedEffectsFixture")
	var strength_branch: Node2D = create_strength_branch(
		fixture,
		"CombinedStrength"
	)
	var primary: MockEnemy = create_enemy(
		fixture,
		"Primary",
		Vector2(50.0, 0.0),
		3
	)
	var secondary: MockEnemy = create_enemy(
		fixture,
		"Secondary",
		Vector2(80.0, 0.0),
		4
	)

	purchase_talents(
		strength_branch,
		[
			&"sweeping_strike",
			&"rebuff",
			&"marked_prey"
		]
	)

	strength_branch.call("perform_strength_hit", primary)
	strength_branch.call("perform_strength_hit", primary)

	expect_damage(primary.damage_events, 0, 10.0, "Combined primary 1")
	expect_damage(primary.damage_events, 1, 11.0, "Combined primary 2")
	expect_damage(secondary.damage_events, 0, 6.0, "Combined secondary 1")
	expect_damage(secondary.damage_events, 1, 6.0, "Combined secondary 2")
	expect_knockback(primary, 0, 35.0, "Combined primary Rebuff 1")
	expect_knockback(primary, 1, 35.0, "Combined primary Rebuff 2")
	expect_knockback(secondary, 0, 35.0, "Combined secondary Rebuff 1")
	expect_knockback(secondary, 1, 35.0, "Combined secondary Rebuff 2")

	await cleanup_fixture(fixture)


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


func create_strength_branch(
	fixture: Node2D,
	branch_name: String
) -> Node2D:
	var strength_branch: Node2D = (
		STRENGTH_SCENE.instantiate()
	)
	strength_branch.name = branch_name
	strength_branch.process_mode = (
		Node.PROCESS_MODE_DISABLED
	)
	strength_branch.set("facing_side", 1)
	strength_branch.set(
		"branch_progress_service",
		fixture.get_node("BranchProgressService")
	)
	fixture.add_child(strength_branch)

	var cooldown_timer := strength_branch.get_node(
		"CooldownTimer"
	) as Timer
	cooldown_timer.stop()

	return strength_branch


func create_enemy(
	fixture: Node2D,
	enemy_name: String,
	enemy_position: Vector2,
	lane_index: int
) -> MockEnemy:
	var enemy := MockEnemy.new()
	enemy.name = enemy_name
	enemy.position = enemy_position
	enemy.lane_index = lane_index
	fixture.add_child(enemy)
	enemy.add_to_group("enemies")
	return enemy


func purchase_talents(
	strength_branch: Node2D,
	talent_ids: Array[StringName]
) -> void:
	var progress_service: BranchProgressService = strength_branch.get(
		"branch_progress_service"
	) as BranchProgressService
	var progress: BranchProgressRecord = progress_service.get_progress(
		&"strength_branch"
	)
	progress.branch_level = 2
	progress.total_talent_points_earned = talent_ids.size()
	progress_service.synchronize_branch(strength_branch as CombatBranch)

	for talent_id in talent_ids:
		expect(
			bool(
				strength_branch.call(
					"purchase_talent",
					talent_id
				)
			),
			"Could not purchase Strength talent '%s'."
			% talent_id
		)


func expect_damage(
	damage_events: Array[float],
	event_index: int,
	expected_damage: float,
	label: String
) -> void:
	expect(
		damage_events.size() > event_index,
		"%s did not resolve damage event %d."
		% [label, event_index]
	)

	if damage_events.size() <= event_index:
		return

	expect(
		is_equal_approx(
			damage_events[event_index],
			expected_damage
		),
		"%s damage was %.3f instead of %.3f."
		% [
			label,
			damage_events[event_index],
			expected_damage
		]
	)


func expect_knockback(
	enemy: MockEnemy,
	event_index: int,
	expected_distance: float,
	label: String
) -> void:
	expect(
		enemy.knockback_events.size() > event_index,
		"%s did not create knockback event %d."
		% [label, event_index]
	)

	if enemy.knockback_events.size() <= event_index:
		return

	expect(
		is_equal_approx(
			enemy.knockback_events[event_index],
			expected_distance
		),
		"%s knockback was %.3f instead of %.3f."
		% [
			label,
			enemy.knockback_events[event_index],
			expected_distance
		]
	)


func expect_marked_state(
	effect_set: StrengthTalentEffectSet,
	expected_target_id: int,
	expected_stacks: int,
	label: String
) -> void:
	var marked_effect: StrengthMarkedPreyEffect = (
		effect_set.marked_prey_effect
	)

	expect(
		marked_effect.get_target_instance_id()
		== expected_target_id,
		"%s target ID was not %d."
		% [label, expected_target_id]
	)
	expect(
		marked_effect.get_stack_count() == expected_stacks,
		"%s stack count was not %d."
		% [label, expected_stacks]
	)


func cleanup_fixture(
	fixture: Node2D
) -> void:
	fixture.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	failures.append(message)
	push_error(message)
