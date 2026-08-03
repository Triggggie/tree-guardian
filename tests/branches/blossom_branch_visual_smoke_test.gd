extends Node


const BLOSSOM_SCRIPT: Script = preload(
	"res://scripts/branches/blossom_branch.gd"
)

const BLOSSOM_SCENE: PackedScene = preload(
	"res://scenes/branches/blossom_branch.tscn"
)


var failures: Array[String] = []


func _ready() -> void:
	await run_test()

	if failures.is_empty():
		print("BLOSSOM BRANCH VISUAL SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print(
		"BLOSSOM BRANCH VISUAL SMOKE TEST FAIL: %d failure(s)"
		% failures.size()
	)
	get_tree().quit(1)


func run_test() -> void:
	var fixture := Node2D.new()
	fixture.name = "BlossomBranchVisualFixture"
	add_child(fixture)

	var blossom_branch: Node2D = (
		BLOSSOM_SCENE.instantiate()
	)
	blossom_branch.name = "BlossomBranch"
	blossom_branch.process_mode = Node.PROCESS_MODE_DISABLED
	fixture.add_child(blossom_branch)

	var visual_node: Node = blossom_branch.get_node_or_null(
		"Visual"
	)
	var attack_origin: Node = blossom_branch.get_node_or_null(
		"AttackOrigin"
	)
	var cooldown_timer: Node = blossom_branch.get_node_or_null(
		"CooldownTimer"
	)

	test_structure(
		blossom_branch,
		visual_node,
		attack_origin,
		cooldown_timer
	)

	if visual_node is BlossomBranchVisual:
		var branch_visual := (
			visual_node as BlossomBranchVisual
		)

		test_delegation(
			blossom_branch,
			branch_visual
		)

		test_growth_and_flowers(
			blossom_branch,
			branch_visual
		)

		test_direction_and_projectile_spawn(
			blossom_branch,
			branch_visual
		)

		test_root_transform_and_feedback(
			blossom_branch,
			branch_visual
		)

	test_missing_visual_fallback()
	test_unchanged_gameplay_values(blossom_branch)

	fixture.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	expect(
		get_tree().get_nodes_in_group(
			"blossom_branch"
		).is_empty(),
		"Blossom visual fixture left a Blossom group member."
	)

	expect(
		get_tree().get_nodes_in_group(
			"combat_branch"
		).is_empty(),
		"Blossom visual fixture left a combat branch group member."
	)


func test_structure(
	blossom_branch: Node2D,
	visual_node: Node,
	attack_origin: Node,
	cooldown_timer: Node
) -> void:
	expect(
		blossom_branch is CombatBranch,
		"Blossom root is not a CombatBranch."
	)
	expect(
		blossom_branch.get_script() == BLOSSOM_SCRIPT,
		"Blossom root no longer uses the Blossom runtime."
	)
	expect(
		is_instance_valid(visual_node),
		"Blossom scene is missing the direct Visual child."
	)
	expect(
		visual_node is BlossomBranchVisual,
		"Visual child is not a BlossomBranchVisual."
	)
	expect(
		visual_node.get_parent() == blossom_branch,
		"Visual is not a direct child of the Blossom root."
	)
	expect(
		not visual_node.is_in_group("combat_branch"),
		"Blossom Visual was added to the combat_branch group."
	)
	expect(
		attack_origin is Marker2D,
		"AttackOrigin is missing from its original path."
	)
	expect(
		cooldown_timer is Timer,
		"CooldownTimer is missing from its original path."
	)

	if visual_node is not Node2D:
		return

	var visual_2d := visual_node as Node2D
	expect(
		visual_2d.position == Vector2.ZERO,
		"Visual local position changed from Vector2.ZERO."
	)
	expect(
		is_zero_approx(visual_2d.rotation),
		"Visual local rotation changed from zero."
	)
	expect(
		visual_2d.scale == Vector2.ONE,
		"Visual local scale changed from Vector2.ONE."
	)

	for combat_method in [
		&"apply_blossom_healing",
		&"process_healing",
		&"process_ranged_attack",
		&"perform_ranged_attack",
		&"get_projectile_spawn_position",
		&"play_ranged_attack_feedback",
		&"purchase_upgrade"
	]:
		expect(
			not visual_node.has_method(combat_method),
			"Blossom Visual owns combat API '%s'."
			% combat_method
		)


func test_delegation(
	blossom_branch: Node2D,
	branch_visual: BlossomBranchVisual
) -> void:
	expect(
		is_equal_approx(
			float(
				blossom_branch.call(
					"get_branch_growth_progress"
				)
			),
			branch_visual.get_branch_growth_progress()
		),
		"Blossom root growth progress does not delegate to Visual."
	)
	expect(
		is_equal_approx(
			float(
				blossom_branch.call(
					"get_current_length"
				)
			),
			branch_visual.get_current_length()
		),
		"Blossom root length does not delegate to Visual."
	)
	expect(
		is_equal_approx(
			float(
				blossom_branch.call(
					"get_current_thickness"
				)
			),
			branch_visual.get_current_thickness()
		),
		"Blossom root thickness does not delegate to Visual."
	)


func test_growth_and_flowers(
	blossom_branch: Node2D,
	branch_visual: BlossomBranchVisual
) -> void:
	set_branch_level(
		blossom_branch,
		branch_visual,
		1
	)
	expect(
		is_zero_approx(
			branch_visual.get_branch_growth_progress()
		),
		"Level 1 Blossom growth progress is not zero."
	)
	expect_value(
		branch_visual.get_current_length(),
		34.0,
		"Level 1 Blossom length"
	)
	expect_value(
		branch_visual.get_current_thickness(),
		8.0,
		"Level 1 Blossom thickness"
	)
	expect(
		branch_visual.get_visible_flower_count() == 1,
		"Level 1 Blossom does not have one flower."
	)

	set_branch_level(
		blossom_branch,
		branch_visual,
		2
	)
	expect(
		branch_visual.get_visible_flower_count() == 2,
		"Level 2 Blossom does not have two flowers."
	)

	set_branch_level(
		blossom_branch,
		branch_visual,
		5
	)
	var raw_level_five_progress: float = 4.0 / 9.0
	var expected_level_five_progress: float = (
		1.0
		- pow(
			1.0 - raw_level_five_progress,
			2.0
		)
	)
	expect_value(
		branch_visual.get_branch_growth_progress(),
		expected_level_five_progress,
		"Level 5 Blossom eased growth progress"
	)

	set_branch_level(
		blossom_branch,
		branch_visual,
		7
	)
	expect(
		branch_visual.get_visible_flower_count() == 7,
		"Level 7 Blossom does not have seven flowers."
	)

	set_branch_level(
		blossom_branch,
		branch_visual,
		10
	)
	expect_value(
		branch_visual.get_branch_growth_progress(),
		1.0,
		"Level 10 Blossom growth progress"
	)
	expect_value(
		branch_visual.get_current_length(),
		155.0,
		"Level 10 Blossom length"
	)
	expect_value(
		branch_visual.get_current_thickness(),
		22.0,
		"Level 10 Blossom thickness"
	)
	expect(
		branch_visual.get_visible_flower_count() == 7,
		"Level 10 Blossom exceeded seven flowers."
	)

	set_branch_level(
		blossom_branch,
		branch_visual,
		20
	)
	expect_value(
		branch_visual.get_branch_growth_progress(),
		1.0,
		"Post-mature Blossom growth progress"
	)
	expect(
		branch_visual.get_visible_flower_count() == 7,
		"Post-mature Blossom exceeded seven flowers."
	)

	branch_visual.maximum_flowers = 4
	expect(
		branch_visual.get_visible_flower_count() == 4,
		"Blossom Visual ignored maximum_flowers."
	)
	branch_visual.maximum_flowers = 7

	branch_visual.set_tree_growth_factor(0.5)
	expect_value(
		branch_visual.get_current_length(),
		77.5,
		"Half-grown Blossom length"
	)
	expect_value(
		branch_visual.get_current_thickness(),
		11.0,
		"Half-grown Blossom thickness"
	)

	branch_visual.set_tree_growth_factor(1.0)
	expect_value(
		branch_visual.get_current_length(),
		155.0,
		"Restored Blossom length"
	)
	expect_value(
		branch_visual.get_current_thickness(),
		22.0,
		"Restored Blossom thickness"
	)

	branch_visual.set_branch_level(0)
	expect(
		branch_visual.branch_level == 1,
		"Blossom Visual level was not clamped to at least 1."
	)
	branch_visual.set_tree_growth_factor(-1.0)
	expect(
		is_zero_approx(branch_visual.tree_growth_factor),
		"Blossom Visual Tree growth factor was not clamped to zero."
	)

	branch_visual.set_tree_growth_factor(1.0)
	blossom_branch.set("branch_level", 10)
	blossom_branch.call("sync_visual_state")


func test_direction_and_projectile_spawn(
	blossom_branch: Node2D,
	branch_visual: BlossomBranchVisual
) -> void:
	blossom_branch.position = Vector2(200.0, 100.0)
	blossom_branch.rotation = 0.0
	blossom_branch.scale = Vector2.ONE
	blossom_branch.set("branch_level", 10)

	blossom_branch.set("facing_side", 1)
	blossom_branch.call("sync_visual_state")
	expect(
		branch_visual.facing_direction == 1.0,
		"Right Blossom facing did not synchronize to Visual."
	)
	expect(
		branch_visual.get_visible_flower_count() == 7,
		"Right facing changed the Blossom flower count."
	)

	var right_spawn_global: Vector2 = blossom_branch.call(
		"get_projectile_spawn_position"
	)
	var right_spawn_local: Vector2 = blossom_branch.to_local(
		right_spawn_global
	)
	expect_value(
		right_spawn_local.x,
		branch_visual.get_current_length(),
		"Right Blossom projectile spawn X"
	)
	expect(
		right_spawn_local.x > 0.0,
		"Right Blossom projectile spawn is not on positive local X."
	)

	blossom_branch.set("facing_side", 0)
	blossom_branch.call("sync_visual_state")
	expect(
		branch_visual.facing_direction == -1.0,
		"Left Blossom facing did not synchronize to Visual."
	)
	expect(
		branch_visual.get_visible_flower_count() == 7,
		"Left facing changed the Blossom flower count."
	)

	var left_spawn_global: Vector2 = blossom_branch.call(
		"get_projectile_spawn_position"
	)
	var left_spawn_local: Vector2 = blossom_branch.to_local(
		left_spawn_global
	)
	expect_value(
		left_spawn_local.x,
		-branch_visual.get_current_length(),
		"Left Blossom projectile spawn X"
	)
	expect(
		left_spawn_local.x < 0.0,
		"Left Blossom projectile spawn is not on negative local X."
	)

	branch_visual.set_tree_growth_factor(0.5)
	var half_growth_spawn_global: Vector2 = blossom_branch.call(
		"get_projectile_spawn_position"
	)
	var half_growth_spawn_local: Vector2 = blossom_branch.to_local(
		half_growth_spawn_global
	)
	expect_value(
		abs(half_growth_spawn_local.x),
		77.5,
		"Half-grown Blossom projectile spawn distance"
	)

	branch_visual.set_facing_direction(-7.0)
	expect(
		branch_visual.facing_direction == -1.0,
		"Negative Blossom facing did not normalize to -1.0."
	)
	branch_visual.set_facing_direction(0.0)
	expect(
		branch_visual.facing_direction == 1.0,
		"Zero Blossom facing did not normalize safely to 1.0."
	)
	branch_visual.set_tree_growth_factor(1.0)
	blossom_branch.call("sync_visual_state")


func test_root_transform_and_feedback(
	blossom_branch: Node2D,
	branch_visual: BlossomBranchVisual
) -> void:
	blossom_branch.scale = Vector2(1.25, 1.25)
	expect(
		branch_visual.global_scale.is_equal_approx(
			blossom_branch.global_scale
		),
		"Blossom Visual does not inherit root scale."
	)
	expect(
		blossom_branch.has_method(
			"play_ranged_attack_feedback"
		),
		"Blossom root lost ranged attack feedback."
	)
	expect(
		not branch_visual.has_method(
			"play_ranged_attack_feedback"
		),
		"Ranged attack feedback moved into Blossom Visual."
	)

	var root_transform_before: Transform2D = (
		blossom_branch.transform
	)
	branch_visual.set_branch_level(3)
	branch_visual.set_tree_growth_factor(0.75)
	branch_visual.set_facing_direction(-1.0)
	expect(
		blossom_branch.transform == root_transform_before,
		"Blossom Visual changed the root transform."
	)

	blossom_branch.scale = Vector2.ONE
	blossom_branch.call("sync_visual_state")


func test_missing_visual_fallback() -> void:
	var fallback_branch: Node2D = BLOSSOM_SCRIPT.new()
	fallback_branch.set(
		"has_warned_missing_branch_visual",
		true
	)

	expect_value(
		float(
			fallback_branch.call(
				"get_branch_growth_progress"
			)
		),
		0.0,
		"Missing Blossom Visual growth fallback"
	)
	expect_value(
		float(
			fallback_branch.call(
				"get_current_length"
			)
		),
		0.0,
		"Missing Blossom Visual length fallback"
	)
	expect_value(
		float(
			fallback_branch.call(
				"get_current_thickness"
			)
		),
		0.0,
		"Missing Blossom Visual thickness fallback"
	)
	fallback_branch.free()


func test_unchanged_gameplay_values(
	blossom_branch: Node2D
) -> void:
	expect_value(
		float(blossom_branch.get("base_healing_per_tick")),
		3.0,
		"Blossom base healing"
	)
	expect_value(
		float(blossom_branch.get("base_healing_tick_interval")),
		2.0,
		"Blossom healing interval"
	)
	expect_value(
		float(blossom_branch.get("minimum_healing_tick_interval")),
		0.75,
		"Blossom minimum healing interval"
	)
	expect_value(
		float(blossom_branch.get("healing_effect_duration")),
		6.0,
		"Blossom healing effect duration"
	)
	expect_value(
		float(blossom_branch.get("effect_refresh_interval")),
		6.0,
		"Blossom healing refresh interval"
	)
	expect_value(
		float(blossom_branch.get("base_ranged_damage")),
		3.0,
		"Blossom base petal damage"
	)
	expect_value(
		float(blossom_branch.get("ranged_attack_interval")),
		2.0,
		"Blossom ranged attack interval"
	)
	expect_value(
		float(blossom_branch.get("ranged_attack_range")),
		650.0,
		"Blossom ranged attack range"
	)


func set_branch_level(
	blossom_branch: Node2D,
	branch_visual: BlossomBranchVisual,
	new_level: int
) -> void:
	blossom_branch.set("branch_level", new_level)
	blossom_branch.call("on_branch_level_changed")
	expect(
		branch_visual.branch_level == max(new_level, 1),
		"Blossom Visual did not synchronize to Branch Level %d."
		% new_level
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
		% [
			label,
			actual_value,
			expected_value
		]
	)


func expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	failures.append(message)
	push_error(message)
