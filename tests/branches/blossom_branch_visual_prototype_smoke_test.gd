extends Node


const MAIN_WORLD_SCENE: PackedScene = preload(
	"res://scenes/main_world.tscn"
)

const TEST_AGES: Array[int] = [1, 40, 80, 200]

const EXPECTED_POSITIONS: Array[Vector2] = [
	Vector2(24.0, -22.0),
	Vector2(24.0, -16.0),
	Vector2(30.0, -19.0),
	Vector2(54.0, -22.0)
]

const EXPECTED_SCALES: Array[Vector2] = [
	Vector2(0.32, 0.32),
	Vector2(0.41, 0.41),
	Vector2(0.51, 0.51),
	Vector2(0.6, 0.6)
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
	for slot_index in range(
		BranchSlotRules.FIRST_STANDARD_SLOT,
		BranchSlotRules.LAST_STANDARD_SLOT + 1
	):
		var slot_id: StringName = BranchSlotRules.get_slot_id(slot_index)
		if loadout.get_equipped_branch_id(slot_id) != &"blossom_branch":
			expect(
				loadout.equip_standard_branch(slot_id, &"blossom_branch"),
				"Could not equip Blossom in Standard slot %d." % slot_index
			)
	await get_tree().process_frame

	var branches_by_slot: Dictionary = {}
	var instance_ids_by_slot: Dictionary = {}
	for slot_index in range(
		BranchSlotRules.FIRST_STANDARD_SLOT,
		BranchSlotRules.LAST_STANDARD_SLOT + 1
	):
		var slot_id: StringName = BranchSlotRules.get_slot_id(slot_index)
		var branch: CombatBranch = controller.get_runtime_branch(slot_id)
		branches_by_slot[slot_id] = branch
		instance_ids_by_slot[slot_id] = branch.get_instance_id()
		expect(
			branch.branch_id == &"blossom_branch",
			"Standard slot %d did not instantiate Blossom." % slot_index
		)

	for stage_index in range(TEST_AGES.size()):
		var tree_age: int = TEST_AGES[stage_index]
		tree_node.set("age", tree_age)
		tree_node.emit_signal("age_changed", tree_age)

		for slot_index in range(
			BranchSlotRules.FIRST_STANDARD_SLOT,
			BranchSlotRules.LAST_STANDARD_SLOT + 1
		):
			var slot_id: StringName = BranchSlotRules.get_slot_id(slot_index)
			var branch: CombatBranch = branches_by_slot[slot_id] as CombatBranch
			var visual := branch.get_node("Visual") as BlossomBranchVisual
			var sprite := visual.get_node("ProductionSprite") as Sprite2D
			var is_left_slot: bool = slot_index in [1, 2]
			var expected_position: Vector2 = EXPECTED_POSITIONS[stage_index]
			if is_left_slot:
				expected_position.x = -expected_position.x

			expect(
				visual.is_using_production_sprite() and sprite.visible,
				"Blossom slot %d fell back from production art at Age %d."
				% [slot_index, tree_age]
			)
			expect(
				sprite.texture.resource_path
				== "res://resources/branches/blossom/visuals/blossom_branch.png",
				"Blossom slot %d uses the wrong production texture."
				% slot_index
			)
			expect(
				sprite.texture.get_width() == 256
				and sprite.texture.get_height() == 256
				and sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
				"Blossom slot %d production texture metadata changed."
				% slot_index
			)
			expect(
				sprite.position == expected_position
				and sprite.scale == EXPECTED_SCALES[stage_index],
				"Blossom slot %d used the wrong layout at Age %d."
				% [slot_index, tree_age]
			)
			expect(
				sprite.flip_h == is_left_slot
				and is_zero_approx(sprite.rotation)
				and sprite.z_index == 0,
				"Blossom slot %d mirroring or draw order changed at Age %d."
				% [slot_index, tree_age]
			)
			expect(
				branch.get_instance_id() == int(instance_ids_by_slot[slot_id]),
				"Tree stage transition recreated Blossom in slot %d."
				% slot_index
			)

	var replacement_slots: Array[StringName] = [
		BranchSlotRules.STANDARD_SLOT_1_ID,
		BranchSlotRules.STANDARD_SLOT_2_ID
	]
	for slot_id in replacement_slots:
		expect(
			loadout.equip_standard_branch(slot_id, &"poison_vine"),
			"Could not replace Blossom with Poison Vine in %s." % slot_id
		)
		await get_tree().process_frame
		var poison_branch: CombatBranch = controller.get_runtime_branch(slot_id)
		expect(
			poison_branch.branch_id == &"poison_vine"
			and poison_branch.get_node_or_null("Visual/ProductionSprite") == null,
			"Poison Vine replacement retained Blossom artwork in %s." % slot_id
		)
		expect(
			loadout.equip_standard_branch(slot_id, &"blossom_branch"),
			"Could not restore Blossom in %s." % slot_id
		)
		await get_tree().process_frame
		var restored_branch: CombatBranch = controller.get_runtime_branch(slot_id)
		var restored_visual := restored_branch.get_node("Visual") as BlossomBranchVisual
		expect(
			restored_visual.is_using_production_sprite()
			and restored_visual.get_node("ProductionSprite").visible,
			"Restored Blossom did not recover production artwork in %s." % slot_id
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
		"An empty Standard slot retained Blossom artwork."
	)

	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures.append(message)
	push_error(message)
