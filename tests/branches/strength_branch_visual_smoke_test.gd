extends Node


const STRENGTH_SCRIPT: Script = preload(
	"res://scripts/branches/strength_branch.gd"
)

const STRENGTH_SCENE: PackedScene = preload(
	"res://scenes/branches/strength_branch.tscn"
)


var failures: Array[String] = []


func _ready() -> void:
	await run_test()

	if failures.is_empty():
		print("STRENGTH BRANCH VISUAL SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print(
		"STRENGTH BRANCH VISUAL SMOKE TEST FAIL: %d failure(s)"
		% failures.size()
	)

	get_tree().quit(1)


func run_test() -> void:
	var fixture := Node2D.new()
	fixture.name = "StrengthBranchVisualFixture"
	add_child(fixture)

	var strength_branch: Node2D = (
		STRENGTH_SCENE.instantiate()
	)

	strength_branch.name = "StrengthBranch"
	strength_branch.set_process(false)
	fixture.add_child(strength_branch)

	expect(
		strength_branch.get_script() == STRENGTH_SCRIPT,
		"Strength root no longer uses the Strength runtime."
	)

	var visual_node: Node = strength_branch.get_node_or_null(
		"Visual"
	)

	expect(
		visual_node != null,
		"Strength scene is missing the direct Visual child."
	)

	expect(
		visual_node is StrengthBranchVisual,
		"Visual child is not a StrengthBranchVisual."
	)

	var cooldown_timer: Node = (
		strength_branch.get_node_or_null(
			"CooldownTimer"
		)
	)

	expect(
		cooldown_timer is Timer,
		"CooldownTimer is missing from its original path."
	)

	if visual_node is StrengthBranchVisual:
		var branch_visual := (
			visual_node as StrengthBranchVisual
		)

		test_visual_transform(
			strength_branch,
			branch_visual
		)

		test_visual_growth(
			strength_branch,
			branch_visual
		)

		test_runtime_delegation(
			strength_branch,
			branch_visual
		)

	fixture.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	expect(
		get_tree().get_nodes_in_group(
			"strength_branch"
		).is_empty(),
		"Strength fixture left a Strength group member."
	)

	expect(
		get_tree().get_nodes_in_group(
			"combat_branch"
		).is_empty(),
		"Strength fixture left a combat branch group member."
	)


func test_visual_transform(
	strength_branch: Node2D,
	branch_visual: StrengthBranchVisual
) -> void:
	expect(
		branch_visual.get_parent() == strength_branch,
		"Visual is not a direct child of the Strength root."
	)

	expect(
		branch_visual.position == Vector2.ZERO,
		"Visual local position is not Vector2.ZERO."
	)

	expect(
		is_zero_approx(branch_visual.rotation),
		"Visual local rotation is not zero."
	)

	expect(
		branch_visual.scale == Vector2.ONE,
		"Visual local scale is not Vector2.ONE."
	)

	strength_branch.rotation = 0.25

	expect(
		is_equal_approx(
			branch_visual.global_rotation,
			strength_branch.global_rotation
		),
		"Visual does not inherit the Strength root transform."
	)

	strength_branch.rotation = 0.0


func test_visual_growth(
	strength_branch: Node2D,
	branch_visual: StrengthBranchVisual
) -> void:
	expect(
		branch_visual.branch_level == 1,
		"Initial Visual level is not synchronized to Level 1."
	)

	expect(
		is_equal_approx(
			branch_visual.get_current_length(),
			38.0
		),
		"Level 1 Visual length changed from 38.0."
	)

	expect(
		is_equal_approx(
			branch_visual.get_current_thickness(),
			10.0
		),
		"Level 1 Visual thickness changed from 10.0."
	)

	expect(
		branch_visual.get_unlocked_shoot_count() == 0,
		"Level 1 Visual unlocked a shoot."
	)

	set_branch_level(
		strength_branch,
		branch_visual,
		2
	)

	expect(
		branch_visual.get_unlocked_shoot_count() == 0,
		"Level 2 Visual unlocked a shoot."
	)

	set_branch_level(
		strength_branch,
		branch_visual,
		3
	)

	expect(
		branch_visual.get_unlocked_shoot_count() == 1,
		"Level 3 Visual did not unlock exactly one shoot."
	)

	set_branch_level(
		strength_branch,
		branch_visual,
		7
	)

	expect(
		branch_visual.get_unlocked_shoot_count() <= 5,
		"Level 7 Visual exceeded five shoots."
	)

	set_branch_level(
		strength_branch,
		branch_visual,
		10
	)

	expect(
		is_equal_approx(
			branch_visual.get_current_length(),
			185.0
		),
		"Level 10 Visual length changed from 185.0."
	)

	expect(
		is_equal_approx(
			branch_visual.get_current_thickness(),
			30.0
		),
		"Level 10 Visual thickness changed from 30.0."
	)

	expect(
		branch_visual.get_unlocked_shoot_count() == 5,
		"Level 10 Visual does not have five shoots."
	)

	branch_visual.set_tree_growth_factor(0.72)

	expect(
		is_equal_approx(
			branch_visual.get_current_length(),
			185.0 * 0.72
		),
		"Tree growth factor no longer scales Visual length."
	)

	branch_visual.set_branch_level(0)
	expect(
		branch_visual.branch_level == 1,
		"Visual Branch Level was not clamped to at least 1."
	)

	branch_visual.set_tree_growth_factor(-1.0)
	expect(
		is_zero_approx(branch_visual.tree_growth_factor),
		"Visual tree growth factor was not clamped to 0.0."
	)

	branch_visual.set_facing_direction(-2.0)
	expect(
		branch_visual.facing_direction == -1.0,
		"Visual left facing direction is not -1.0."
	)

	branch_visual.set_facing_direction(0.0)
	expect(
		branch_visual.facing_direction == 1.0,
		"Visual right facing direction is not 1.0."
	)

	strength_branch.set("branch_level", 10)
	strength_branch.set("facing_side", 0)
	strength_branch.call("sync_visual_state")

	expect(
		branch_visual.branch_level == 10,
		"Visual level did not resynchronize with the root."
	)

	expect(
		branch_visual.facing_direction == -1.0,
		"Root left facing did not synchronize to Visual."
	)

	strength_branch.set("facing_side", 1)
	strength_branch.call("sync_visual_state")

	expect(
		branch_visual.facing_direction == 1.0,
		"Root right facing did not synchronize to Visual."
	)


func test_runtime_delegation(
	strength_branch: Node2D,
	branch_visual: StrengthBranchVisual
) -> void:
	expect(
		is_equal_approx(
			float(
				strength_branch.call(
					"get_current_length"
				)
			),
			branch_visual.get_current_length()
		),
		"Strength root length does not delegate to Visual."
	)

	expect(
		is_equal_approx(
			float(
				strength_branch.call(
					"get_current_thickness"
				)
			),
			branch_visual.get_current_thickness()
		),
		"Strength root thickness does not delegate to Visual."
	)

	expect(
		is_equal_approx(
			float(
				strength_branch.call(
					"get_branch_growth_progress"
				)
			),
			branch_visual.get_branch_growth_progress()
		),
		"Strength root growth progress does not delegate to Visual."
	)

	strength_branch.set("range_upgrade_level", 1)

	var expected_range: float = (
		branch_visual.get_current_length()
		+ 100.0
		+ float(
			strength_branch.call(
				"get_current_range_bonus"
			)
		)
	)

	expect(
		is_equal_approx(
			float(
				strength_branch.call(
					"get_current_attack_range"
				)
			),
			expected_range
		),
		"Attack range no longer uses Visual length plus padding and bonus."
	)

	expect(
		is_equal_approx(
			float(strength_branch.get("base_damage")),
			10.0
		),
		"Strength base damage changed from 10.0."
	)

	expect(
		is_equal_approx(
			float(
				strength_branch.get(
					"base_attack_cooldown"
				)
			),
			1.5
		),
		"Strength base cooldown changed from 1.5."
	)

	expect(
		not strength_branch.has_method(
			"draw_main_branch"
		),
		"Strength root still owns draw_main_branch()."
	)

	expect(
		not strength_branch.has_method(
			"draw_natural_shoots"
		),
		"Strength root still owns draw_natural_shoots()."
	)


func set_branch_level(
	strength_branch: Node2D,
	branch_visual: StrengthBranchVisual,
	new_level: int
) -> void:
	strength_branch.set("branch_level", new_level)
	strength_branch.call("on_branch_level_changed")

	expect(
		branch_visual.branch_level == new_level,
		"Visual did not synchronize to Branch Level %d."
		% new_level
	)


func expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures.append(message)
	push_error(message)
