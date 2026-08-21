extends Node


const MAIN_WORLD_SCENE: PackedScene = preload(
	"res://scenes/main_world.tscn"
)

const TEST_AGES: Array[int] = [1, 40, 80, 200]

const EXPECTED_POSITIONS: Array[Vector2] = [
	Vector2(21.0, -32.0),
	Vector2(23.0, -34.0),
	Vector2(32.0, -43.0),
	Vector2(50.0, -52.0)
]

const EXPECTED_SCALES: Array[Vector2] = [
	Vector2(0.3, 0.3),
	Vector2(0.39, 0.39),
	Vector2(0.49, 0.49),
	Vector2(0.58, 0.58)
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
		print("BLOSSOM BRANCH VISUAL PROTOTYPE SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print(
		"BLOSSOM BRANCH VISUAL PROTOTYPE SMOKE TEST FAIL: "
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
		BranchSlotRules.STANDARD_SLOT_2_ID
	)
	var right_branch: CombatBranch = controller.get_runtime_branch(
		BranchSlotRules.STANDARD_SLOT_4_ID
	)
	var left_visual := left_branch.get_node("Visual") as BlossomBranchVisual
	var right_visual := right_branch.get_node("Visual") as BlossomBranchVisual
	var left_sprite := left_visual.get_node("ProductionSprite") as Sprite2D
	var right_sprite := right_visual.get_node("ProductionSprite") as Sprite2D
	var left_instance_id: int = left_branch.get_instance_id()
	var right_instance_id: int = right_branch.get_instance_id()

	expect(
		left_visual.is_using_upper_production_sprite()
		and right_visual.is_using_upper_production_sprite(),
		"Default upper Blossom Branches did not enable the prototype sprite."
	)
	expect(
		left_sprite.texture.resource_path
		== "res://resources/branches/blossom/visuals/blossom_branch.png",
		"LeftUpper uses the wrong prototype texture."
	)
	expect(
		left_sprite.texture.get_width() == 256
		and left_sprite.texture.get_height() == 256,
		"The Blossom prototype texture is not 256x256."
	)
	expect(
		left_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
		and right_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"Upper Blossom sprites are not using nearest-neighbor filtering."
	)

	for stage_index in range(TEST_AGES.size()):
		var tree_age: int = TEST_AGES[stage_index]
		tree_node.set("age", tree_age)
		tree_node.emit_signal("age_changed", tree_age)

		expect(
			left_sprite.visible and right_sprite.visible,
			"An upper Blossom sprite disappeared at Age %d." % tree_age
		)
		expect(
			left_sprite.position
			== Vector2(
				-EXPECTED_POSITIONS[stage_index].x,
				EXPECTED_POSITIONS[stage_index].y
			),
			"LeftUpper used the wrong layout at Age %d." % tree_age
		)
		expect(
			right_sprite.position == EXPECTED_POSITIONS[stage_index],
			"RightUpper used the wrong layout at Age %d." % tree_age
		)
		expect(
			left_sprite.scale == EXPECTED_SCALES[stage_index]
			and right_sprite.scale == EXPECTED_SCALES[stage_index],
			"Upper Blossom scale is wrong at Age %d." % tree_age
		)
		expect(
			left_sprite.flip_h and not right_sprite.flip_h,
			"Upper Blossom mirroring is wrong at Age %d." % tree_age
		)
		expect(
			is_zero_approx(left_sprite.rotation)
			and is_zero_approx(right_sprite.rotation)
			and left_sprite.z_index == 0
			and right_sprite.z_index == 0,
			"Upper Blossom rotation or draw order changed at Age %d."
			% tree_age
		)
		expect(
			left_branch.get_instance_id() == left_instance_id
			and right_branch.get_instance_id() == right_instance_id,
			"Tree stage transition recreated an upper Blossom Branch."
		)

	expect(
		loadout.equip_standard_branch(
			BranchSlotRules.STANDARD_SLOT_1_ID,
			&"blossom_branch"
		),
		"Could not equip the lower Blossom validation fixture."
	)
	await get_tree().process_frame
	var lower_blossom: CombatBranch = controller.get_runtime_branch(
		BranchSlotRules.STANDARD_SLOT_1_ID
	)
	var lower_visual := lower_blossom.get_node("Visual") as BlossomBranchVisual
	expect(
		not lower_visual.is_using_upper_production_sprite()
		and not lower_visual.get_node("ProductionSprite").visible,
		"A lower Blossom slot incorrectly enabled the upper prototype."
	)

	expect(
		loadout.equip_standard_branch(
			BranchSlotRules.STANDARD_SLOT_2_ID,
			&"strength_branch"
		),
		"Could not equip the upper non-Blossom validation fixture."
	)
	await get_tree().process_frame
	var upper_strength: CombatBranch = controller.get_runtime_branch(
		BranchSlotRules.STANDARD_SLOT_2_ID
	)
	expect(
		upper_strength.branch_id == &"strength_branch"
		and upper_strength.get_node_or_null(
			"Visual/ProductionSprite"
		) != null
		and not upper_strength.get_node(
			"Visual/ProductionSprite"
		).visible,
		"A non-Blossom upper slot retained Blossom artwork."
	)

	expect(
		loadout.unequip_standard_branch(
			BranchSlotRules.STANDARD_SLOT_4_ID
		),
		"Could not empty the RightUpper validation slot."
	)
	await get_tree().process_frame
	expect(
		controller.get_runtime_branch(
			BranchSlotRules.STANDARD_SLOT_4_ID
		) == null,
		"An empty upper slot retained Blossom artwork."
	)

	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures.append(message)
	push_error(message)
