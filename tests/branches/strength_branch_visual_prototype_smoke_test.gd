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


const MAIN_WORLD_SCENE: PackedScene = preload(
	"res://scenes/main_world.tscn"
)

const TEST_AGES: Array[int] = [1, 40, 80, 200]

const EXPECTED_POSITIONS: Array[Vector2] = [
	Vector2(28.0, -10.0),
	Vector2(42.0, -18.0),
	Vector2(57.0, -23.0),
	Vector2(71.0, -28.0)
]

const EXPECTED_SCALES: Array[Vector2] = [
	Vector2(0.4, 0.4),
	Vector2(0.5, 0.5),
	Vector2(0.64, 0.64),
	Vector2(0.78, 0.78)
]


var failures: Array[String] = []
var loadout: BranchLoadoutService
var progress: BranchProgressService


func _ready() -> void:
	loadout = get_node("/root/BranchLoadout") as BranchLoadoutService
	progress = get_node("/root/BranchProgress") as BranchProgressService
	loadout.clear_runtime_loadout_for_testing()
	progress.clear_runtime_progress_for_testing()
	await run_test()
	loadout.clear_runtime_loadout_for_testing()
	progress.clear_runtime_progress_for_testing()

	if failures.is_empty():
		print("STRENGTH BRANCH VISUAL PROTOTYPE SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print(
		"STRENGTH BRANCH VISUAL PROTOTYPE SMOKE TEST FAIL: "
		+ "%d failure(s)" % failures.size()
	)
	get_tree().quit(1)


func run_test() -> void:
	var world: Node = MAIN_WORLD_SCENE.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await get_tree().process_frame

	var tree_node: Node = world.get_node("Entities/Tree")
	var controller := tree_node.get_node(
		"Systems/TreeBranchLoadoutController"
	) as TreeBranchLoadoutController
	var left_branch: CombatBranch = controller.get_runtime_branch(
		BranchSlotRules.STANDARD_SLOT_1_ID
	)
	var right_branch: CombatBranch = controller.get_runtime_branch(
		BranchSlotRules.STANDARD_SLOT_3_ID
	)
	var left_visual := left_branch.get_node("Visual") as StrengthBranchVisual
	var right_visual := right_branch.get_node("Visual") as StrengthBranchVisual
	var left_sprite := left_visual.get_node("ProductionSprite") as Sprite2D
	var right_sprite := right_visual.get_node("ProductionSprite") as Sprite2D
	var left_instance_id: int = left_branch.get_instance_id()
	var right_instance_id: int = right_branch.get_instance_id()

	expect(
		left_visual.is_using_lower_production_sprite()
		and right_visual.is_using_lower_production_sprite(),
		"Default lower Strength Branches did not enable the prototype sprite."
	)
	expect(
		left_sprite.texture.resource_path
		== "res://resources/branches/strength/visuals/strength_branch_stage_1.png",
		"LeftLower uses the wrong prototype texture."
	)
	expect(
		left_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and right_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"Lower Strength sprites are not using nearest-neighbor filtering."
	)
	expect(
		is_equal_approx(
			left_visual.get_attack_presentation_angle_degrees(18.0),
			8.0
		)
		and is_equal_approx(
			right_visual.get_attack_presentation_angle_degrees(18.0),
			8.0
		),
		"Lower Strength attack presentation did not use the socket-safe angle."
	)

	for stage_index in range(TEST_AGES.size()):
		var tree_age: int = TEST_AGES[stage_index]
		tree_node.set("age", tree_age)
		tree_node.emit_signal("age_changed", tree_age)

		expect(
			left_sprite.visible and right_sprite.visible,
			"A lower Strength sprite disappeared at Age %d." % tree_age
		)
		expect(
			left_sprite.position
			== Vector2(
				-EXPECTED_POSITIONS[stage_index].x,
				EXPECTED_POSITIONS[stage_index].y
			),
			"LeftLower used the wrong layout at Age %d." % tree_age
		)
		expect(
			right_sprite.position == EXPECTED_POSITIONS[stage_index],
			"RightLower used the wrong layout at Age %d." % tree_age
		)
		expect(
			left_sprite.scale == EXPECTED_SCALES[stage_index]
			and right_sprite.scale == EXPECTED_SCALES[stage_index],
			"Lower Strength scale is wrong at Age %d." % tree_age
		)
		expect(
			left_sprite.flip_h and not right_sprite.flip_h,
			"Lower Strength mirroring is wrong at Age %d." % tree_age
		)
		expect(
			is_zero_approx(left_sprite.rotation)
			and is_zero_approx(right_sprite.rotation),
			"Lower Strength rotation changed at Age %d." % tree_age
		)
		expect(
			left_branch.get_instance_id() == left_instance_id
			and right_branch.get_instance_id() == right_instance_id,
			"Tree stage transition recreated a lower Strength Branch."
		)

	await test_attack_presentation(
		world,
		left_branch,
		right_branch
	)

	expect(
		not loadout.equip_standard_branch(
			BranchSlotRules.STANDARD_SLOT_2_ID,
			&"strength_branch"
		),
		"Upper Standard slot accepted lower-only Strength."
	)
	await get_tree().process_frame
	var upper_blossom: CombatBranch = controller.get_runtime_branch(
		BranchSlotRules.STANDARD_SLOT_2_ID
	)
	var upper_visual := upper_blossom.get_node("Visual") as BlossomBranchVisual
	expect(
		upper_blossom.branch_id == &"blossom_branch"
		and upper_visual.is_using_production_sprite()
		and upper_visual.get_node("ProductionSprite").visible,
		"Rejected upper Strength replacement damaged the Blossom visual."
	)

	expect(
		loadout.equip_standard_branch(
			BranchSlotRules.STANDARD_SLOT_1_ID,
			&"blossom_branch"
		),
		"Could not equip the lower non-Strength validation fixture."
	)
	await get_tree().process_frame
	var lower_blossom: CombatBranch = controller.get_runtime_branch(
		BranchSlotRules.STANDARD_SLOT_1_ID
	)
	var lower_blossom_sprite := lower_blossom.get_node(
		"Visual/ProductionSprite"
	) as Sprite2D
	expect(
		lower_blossom.branch_id == &"blossom_branch"
		and is_instance_valid(lower_blossom_sprite)
		and lower_blossom_sprite.visible
		and lower_blossom_sprite.texture.resource_path
		== "res://resources/branches/blossom/visuals/blossom_branch.png",
		"Lower Blossom did not display its own production artwork."
	)

	expect(
		loadout.unequip_standard_branch(
			BranchSlotRules.STANDARD_SLOT_3_ID
		),
		"Could not empty the RightLower validation slot."
	)
	await get_tree().process_frame
	expect(
		controller.get_runtime_branch(
			BranchSlotRules.STANDARD_SLOT_3_ID
		) == null,
		"An empty lower slot retained Strength artwork."
	)

	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func test_attack_presentation(
	world: Node,
	left_branch: CombatBranch,
	right_branch: CombatBranch
) -> void:
	var branches: Array[CombatBranch] = [
		left_branch,
		right_branch
	]

	for branch in branches:
		var enemy := MockEnemy.new()
		world.add_child(enemy)
		enemy.global_position = (
			branch.global_position
			+ Vector2(
				branch.get_facing_direction() * 100.0,
				0.0
			)
		)
		var resting_position: Vector2 = branch.position
		branch.set("combat_enabled", true)
		branch.set("current_target", enemy)
		branch.call("perform_attack_animation")
		var attack_tween: Tween = branch.get("attack_tween") as Tween
		expect(
			is_instance_valid(attack_tween),
			"Lower Strength attack did not create its presentation tween."
		)

		if is_instance_valid(attack_tween):
			var attack_duration: float = float(
				branch.get("attack_duration")
			)
			attack_tween.custom_step(attack_duration)
			expect(
				is_equal_approx(
					abs(rad_to_deg(branch.rotation)),
					8.0
				),
				"Lower Strength attack exceeded the socket-safe rotation."
			)
			expect(
				branch.position == resting_position,
				"Lower Strength attack translated its gameplay root."
			)
			attack_tween.custom_step(attack_duration)
			expect(
				is_zero_approx(branch.rotation)
				and branch.position == resting_position,
				"Lower Strength attack did not return to its resting transform."
			)

		enemy.queue_free()
		await get_tree().process_frame


func expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures.append(message)
	push_error(message)
