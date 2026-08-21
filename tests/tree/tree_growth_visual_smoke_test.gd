extends Node


const TREE_SCENE: PackedScene = preload(
	"res://scenes/tree/tree.tscn"
)

const TEST_AGES: Array[int] = [
	1,
	39,
	40,
	79,
	80,
	199,
	200,
	237
]

const EXPECTED_STAGES: Array[int] = [
	1,
	1,
	2,
	2,
	3,
	3,
	4,
	4
]

const EXPECTED_TEXTURE_PATHS: Array[String] = [
	"res://resources/tree/growth/guardian_tree_stage_1.png",
	"res://resources/tree/growth/guardian_tree_stage_2.png",
	"res://resources/tree/growth/guardian_tree_stage_3.png",
	"res://resources/tree/growth/guardian_tree_stage_4.png"
]

const EXPECTED_POSITIONS: Array[Vector2] = [
	Vector2(2.0, -124.0),
	Vector2(2.775, -127.65),
	Vector2(0.8, -150.4),
	Vector2(1.575, -159.075)
]

const EXPECTED_SCALES: Array[Vector2] = [
	Vector2(2.0, 2.0),
	Vector2(1.85, 1.85),
	Vector2(1.6, 1.6),
	Vector2(1.575, 1.575)
]

const ATTACHMENT_NAMES: Array[StringName] = [
	&"LeftLower",
	&"RightLower",
	&"LeftUpper",
	&"RightUpper",
	&"Apex"
]

const BRANCH_MOUNT_OFFSETS: Dictionary = {
	&"LeftLower": Vector2(-20.0, -170.0),
	&"RightLower": Vector2(20.0, -170.0),
	&"LeftUpper": Vector2(-20.0, -170.0),
	&"RightUpper": Vector2(20.0, -170.0),
	&"Apex": Vector2(0.0, -170.0)
}

const OPAQUE_CENTERS_X: Array[float] = [
	127.0,
	126.5,
	127.5,
	127.0
]

const OPAQUE_BOTTOMS_Y: Array[float] = [
	190.0,
	197.0,
	222.0,
	229.0
]


var failures: Array[String] = []


func _ready() -> void:
	test_stage_resolver()
	await test_runtime_visuals()
	test_tree_soul_unlock_threshold()

	if failures.is_empty():
		print("TREE GROWTH VISUAL SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print(
		"TREE GROWTH VISUAL SMOKE TEST FAIL: %d failure(s)"
		% failures.size()
	)
	get_tree().quit(1)


func test_stage_resolver() -> void:
	for test_index in range(TEST_AGES.size()):
		var tree_age: int = TEST_AGES[test_index]
		var expected_stage: int = EXPECTED_STAGES[test_index]

		expect(
			TreeGrowthVisual.resolve_stage_for_age(tree_age)
			== expected_stage,
			"Age %d did not resolve to Stage %d."
			% [tree_age, expected_stage]
		)


func test_runtime_visuals() -> void:
	var tree_node: Node2D = TREE_SCENE.instantiate() as Node2D
	add_child(tree_node)

	var visual := tree_node.get_node("Visual") as TreeGrowthVisual
	var base_tree_sprite := visual.get_node(
		"BaseTreeSprite"
	) as Sprite2D
	var soul_core_visual := visual.get_node(
		"SoulCoreVisual"
	) as Node2D

	expect(
		base_tree_sprite.texture_filter
		== CanvasItem.TEXTURE_FILTER_NEAREST,
		"BaseTreeSprite is not using nearest-neighbor filtering."
	)
	expect(
		soul_core_visual.get_child_count() == 0,
		"SoulCoreVisual unexpectedly implements a Soul overlay."
	)
	expect(
		base_tree_sprite.modulate == Color.WHITE,
		"The dormant base Tree sprite has a hard-coded Soul tint."
	)

	var mount_paths: Array[NodePath] = [
		NodePath("AttachmentPoints/LeftLower/BranchMount"),
		NodePath("AttachmentPoints/LeftUpper/BranchMount"),
		NodePath("AttachmentPoints/RightLower/BranchMount"),
		NodePath("AttachmentPoints/RightUpper/BranchMount"),
		NodePath("AttachmentPoints/Apex/BranchMount")
	]
	var mounts: Array[Node] = []
	var mount_child_counts: Array[int] = []

	for mount_path in mount_paths:
		var mount: Node2D = tree_node.get_node(mount_path) as Node2D
		mounts.append(mount)
		mount_child_counts.append(mount.get_child_count())

	for test_index in range(TEST_AGES.size()):
		var tree_age: int = TEST_AGES[test_index]
		var expected_stage: int = EXPECTED_STAGES[test_index]
		tree_node.set("age", tree_age)
		tree_node.emit_signal("age_changed", tree_age)
		var expected_layout: Dictionary = (
			TreeGrowthVisual.STAGE_ATTACHMENT_POSITIONS[
				expected_stage - 1
			]
		)

		expect(
			visual.get_current_stage() == expected_stage,
			"Runtime Age %d did not display Stage %d."
			% [tree_age, expected_stage]
		)

		var expected_texture_path: String = (
			EXPECTED_TEXTURE_PATHS[expected_stage - 1]
		)
		expect(
			base_tree_sprite.texture.resource_path
			== expected_texture_path,
			"Runtime Age %d used the wrong Tree texture."
			% tree_age
		)

		for attachment_name: StringName in ATTACHMENT_NAMES:
			var attachment_point := tree_node.get_node(
				"AttachmentPoints/%s" % attachment_name
			) as Node2D
			var branch_mount := attachment_point.get_node(
				"BranchMount"
			) as Node2D
			expect(
				attachment_point.position
				== expected_layout[attachment_name],
				"Age %d used the wrong %s presentation position."
				% [tree_age, attachment_name]
			)
			expect(
				branch_mount.position
				== BRANCH_MOUNT_OFFSETS[attachment_name],
				"Age %d changed the stable %s BranchMount offset."
				% [tree_age, attachment_name]
			)

	for stage_index in range(EXPECTED_TEXTURE_PATHS.size()):
		visual.refresh_for_age(
			[1, 40, 80, 200][stage_index]
		)
		expect(
			base_tree_sprite.texture.get_width() == 256
			and base_tree_sprite.texture.get_height() == 256,
			"Stage %d texture is not 256x256."
			% (stage_index + 1)
		)
		expect(
			base_tree_sprite.scale
			== EXPECTED_SCALES[stage_index],
			"Stage %d visual scale changed."
			% (stage_index + 1)
		)
		expect(
			base_tree_sprite.position
			== EXPECTED_POSITIONS[stage_index],
			"Stage %d visual offset changed."
			% (stage_index + 1)
		)

		var grounded_y: float = (
			base_tree_sprite.position.y
			+ (OPAQUE_BOTTOMS_Y[stage_index] - 128.0)
			* base_tree_sprite.scale.y
		)
		var centered_x: float = (
			base_tree_sprite.position.x
			+ (OPAQUE_CENTERS_X[stage_index] - 128.0)
			* base_tree_sprite.scale.x
		)
		expect(
			is_zero_approx(grounded_y),
			"Stage %d roots are not grounded at Tree y=0."
			% (stage_index + 1)
		)
		expect(
			is_zero_approx(centered_x),
			"Stage %d artwork is not centered at Tree x=0."
			% (stage_index + 1)
		)

	for mount_index in range(mounts.size()):
		var current_mount: Node2D = tree_node.get_node(
			mount_paths[mount_index]
		) as Node2D
		expect(
			current_mount == mounts[mount_index],
			"A visual stage swap recreated a BranchMount."
		)
		expect(
			current_mount.get_child_count()
			== mount_child_counts[mount_index],
			"A visual stage swap recreated or unequipped a Branch."
		)

	tree_node.set("age", 1)
	tree_node.emit_signal("age_changed", 1)
	expect(
		visual.get_current_stage() == TreeGrowthVisual.STAGE_1,
		"A canonical Age reset did not return the visual to Stage 1."
	)

	tree_node.set("age", 137)
	tree_node.emit_signal("age_changed", 137)
	tree_node.call("take_damage", 1000000.0)
	tree_node.call("revive")
	expect(
		int(tree_node.get("age")) == 137,
		"Ordinary death/revive changed canonical Tree Age."
	)
	expect(
		visual.get_current_stage() == TreeGrowthVisual.STAGE_3,
		"Death/revive at Age 137 did not preserve Stage 3."
	)

	tree_node.queue_free()
	await tree_node.tree_exited


func test_tree_soul_unlock_threshold() -> void:
	var available_souls: Array[TreeSoulDefinition] = (
		TreeSouls.get_available_souls()
	)
	expect(
		not available_souls.is_empty(),
		"No Tree Soul is registered for unlock validation."
	)
	if available_souls.is_empty():
		return

	var soul_definition: TreeSoulDefinition = available_souls[0]
	expect(
		not TreeSouls.can_select_soul(soul_definition, 199),
		"Tree Soul selection unlocked before Age 200."
	)
	expect(
		TreeSouls.can_select_soul(soul_definition, 200),
		"Tree Soul selection did not unlock at Age 200."
	)


func expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures.append(message)
	push_error(message)
