extends Node


const STRENGTH_DEFINITION: BranchDefinition = preload(
	"res://resources/branches/strength_branch_definition.tres"
)

const BLOSSOM_DEFINITION: BranchDefinition = preload(
	"res://resources/branches/blossom_branch_definition.tres"
)

const TREE_SCENE: PackedScene = preload(
	"res://scenes/tree/tree.tscn"
)

const MAIN_WORLD_SCENE: PackedScene = preload(
	"res://scenes/main_world.tscn"
)


var failures: Array[String] = []


func _ready() -> void:
	var legendary_definition: BranchDefinition = (
		test_definition_data()
	)
	test_slot_rules(legendary_definition)
	test_tree_scene_base_structure()
	await test_main_world_runtime()

	expect(
		get_tree().get_nodes_in_group(
			"combat_branch"
		).is_empty(),
		"Apex test left a combat Branch group member."
	)
	expect(
		get_tree().get_nodes_in_group(
			"tree"
		).is_empty(),
		"Apex test left a Tree group member."
	)

	if failures.is_empty():
		print("APEX SLOT RULES SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print(
		"APEX SLOT RULES SMOKE TEST FAIL: %d failure(s)"
		% failures.size()
	)
	get_tree().quit(1)


func test_definition_data() -> BranchDefinition:
	expect(
		is_instance_valid(STRENGTH_DEFINITION),
		"Strength BranchDefinition is missing."
	)
	expect(
		is_instance_valid(BLOSSOM_DEFINITION),
		"Blossom BranchDefinition is missing."
	)
	expect(
		STRENGTH_DEFINITION.category_id
		== BranchDefinition.CATEGORY_STANDARD,
		"Strength is not explicitly standard."
	)
	expect(
		BLOSSOM_DEFINITION.category_id
		== BranchDefinition.CATEGORY_STANDARD,
		"Blossom is not explicitly standard."
	)
	expect(
		STRENGTH_DEFINITION.is_standard_branch(),
		"Strength does not report the standard category."
	)
	expect(
		BLOSSOM_DEFINITION.is_standard_branch(),
		"Blossom does not report the standard category."
	)
	expect(
		STRENGTH_DEFINITION.get_category_display_name()
		== "Standard",
		"Standard category display name changed."
	)
	expect(
		STRENGTH_DEFINITION.is_valid_definition(),
		"Strength BranchDefinition became invalid."
	)
	expect(
		BLOSSOM_DEFINITION.is_valid_definition(),
		"Blossom BranchDefinition became invalid."
	)

	var invalid_definition := (
		STRENGTH_DEFINITION.duplicate(true)
		as BranchDefinition
	)
	invalid_definition.category_id = &"unknown"
	expect(
		not invalid_definition.is_valid_definition(),
		"An unknown Branch category was accepted."
	)
	expect(
		invalid_definition.get_category_display_name()
		== "Unknown",
		"Unknown Branch category has an unexpected label."
	)

	var empty_category_definition := (
		STRENGTH_DEFINITION.duplicate(true)
		as BranchDefinition
	)
	empty_category_definition.category_id = &""
	expect(
		not empty_category_definition.is_valid_definition(),
		"An empty Branch category was accepted."
	)

	var legendary_definition := (
		STRENGTH_DEFINITION.duplicate(true)
		as BranchDefinition
	)
	legendary_definition.category_id = (
		BranchDefinition.CATEGORY_LEGENDARY
	)
	legendary_definition.legendary_tier = (
		BranchDefinition.LEGENDARY_TIER_1
	)
	expect(
		legendary_definition.is_valid_definition(),
		"A legendary copy of Strength is invalid."
	)
	expect(
		legendary_definition.is_legendary_branch(),
		"Legendary definition does not report its category."
	)
	expect(
		legendary_definition.get_category_display_name()
		== "Legendary",
		"Legendary category display name changed."
	)

	return legendary_definition


func test_slot_rules(
	legendary_definition: BranchDefinition
) -> void:
	for slot_index in range(
		BranchSlotRules.FIRST_STANDARD_SLOT,
		BranchSlotRules.LAST_STANDARD_SLOT + 1
	):
		expect(
			BranchSlotRules.is_valid_slot_index(slot_index),
			"Standard slot %d is invalid."
			% slot_index
		)
		expect(
			BranchSlotRules.is_standard_slot(slot_index),
			"Slot %d is not classified as standard."
			% slot_index
		)
		expect(
			BranchSlotRules.can_place_definition(
				STRENGTH_DEFINITION,
				slot_index
			),
			"Standard Strength cannot use slot %d."
			% slot_index
		)
		expect(
			not BranchSlotRules.can_place_definition(
				legendary_definition,
				slot_index
			),
			"Legendary Branch was accepted in slot %d."
			% slot_index
		)

	expect(
		BranchSlotRules.TOTAL_SLOT_COUNT == 5,
		"Total Branch slot count changed from five."
	)
	expect(
		BranchSlotRules.is_apex_slot(
			BranchSlotRules.APEX_SLOT
		),
		"Slot 5 is not the Apex slot."
	)
	expect(
		not BranchSlotRules.can_place_definition(
			STRENGTH_DEFINITION,
			BranchSlotRules.APEX_SLOT
		),
		"Standard Strength was accepted in the Apex slot."
	)
	expect(
		BranchSlotRules.can_place_definition(
			legendary_definition,
			BranchSlotRules.APEX_SLOT
		),
		"Legendary Branch was rejected from the Apex slot."
	)

	for invalid_slot_index in [-5, 0, 6, 99]:
		expect(
			not BranchSlotRules.is_valid_slot_index(
				invalid_slot_index
			),
			"Invalid slot %d was accepted."
			% invalid_slot_index
		)
		expect(
			not BranchSlotRules.can_place_definition(
				STRENGTH_DEFINITION,
				invalid_slot_index
			),
			"Standard Branch used invalid slot %d."
			% invalid_slot_index
		)
		expect(
			not BranchSlotRules.can_place_definition(
				legendary_definition,
				invalid_slot_index
			),
			"Legendary Branch used invalid slot %d."
			% invalid_slot_index
		)

	expect(
		not BranchSlotRules.can_place_definition(
			null,
			BranchSlotRules.FIRST_STANDARD_SLOT
		),
		"A null BranchDefinition was accepted."
	)

	var apex_runtime := CombatBranch.new()
	apex_runtime.branch_definition = legendary_definition
	apex_runtime.slot_index = BranchSlotRules.APEX_SLOT
	expect(
		apex_runtime.is_slot_assignment_valid(),
		"CombatBranch rejected a valid legendary Apex assignment."
	)
	expect(
		apex_runtime.get_branch_category_id()
		== BranchDefinition.CATEGORY_LEGENDARY,
		"CombatBranch returned the wrong category ID."
	)
	expect(
		apex_runtime.is_legendary_branch(),
		"CombatBranch did not identify a legendary definition."
	)
	expect(
		apex_runtime.get_branch_side_name() == "Apex",
		"Slot 5 side name is not Apex."
	)
	apex_runtime.free()


func test_tree_scene_base_structure() -> void:
	var tree_node: Node2D = TREE_SCENE.instantiate()
	var attachment_points: Node = tree_node.get_node_or_null(
		"AttachmentPoints"
	)

	expect(
		is_instance_valid(attachment_points),
		"Tree scene is missing AttachmentPoints."
	)

	if not is_instance_valid(attachment_points):
		tree_node.free()
		return

	var expected_marker_positions: Dictionary = {
		"LeftUpper": Vector2(-30.0, -45.0),
		"LeftLower": Vector2(-35.0, 45.0),
		"RightUpper": Vector2(30.0, -45.0),
		"RightLower": Vector2(35.0, 45.0),
		"Apex": Vector2(0.0, -95.0)
	}

	for marker_name in expected_marker_positions:
		var marker: Node = attachment_points.get_node_or_null(
			marker_name
		)
		expect(
			marker is Marker2D,
			"AttachmentPoints/%s is not a Marker2D."
			% marker_name
		)

		if marker is Marker2D:
			expect_vector(
				(marker as Marker2D).position,
				expected_marker_positions[marker_name],
				"%s base position" % marker_name
			)

	var expected_branch_data: Dictionary = {
		"LeftUpper": Vector2(-20.0, -170.0),
		"LeftLower": Vector2(-20.0, -170.0),
		"RightUpper": Vector2(20.0, -170.0),
		"RightLower": Vector2(20.0, -170.0),
		"Apex": Vector2(0.0, -170.0)
	}

	for marker_name in expected_branch_data:
		var marker: Node = attachment_points.get_node(marker_name)
		expect(
			marker.get_child_count() == 1,
			"%s no longer has exactly one BranchMount child."
			% marker_name
		)

		if marker.get_child_count() != 1:
			continue

		var branch_mount: Node = marker.get_child(0)
		expect(
			branch_mount.name == "BranchMount",
			"%s runtime mount is missing."
			% marker_name
		)
		expect_vector(
			(branch_mount as Node2D).position,
			expected_branch_data[marker_name],
			"%s BranchMount position" % marker_name
		)

	var apex: Node = attachment_points.get_node_or_null("Apex")
	expect(
		is_instance_valid(apex),
		"Tree scene is missing AttachmentPoints/Apex."
	)
	expect(
		is_instance_valid(apex)
		and apex.get_child_count() == 1
		and apex.get_node_or_null("BranchMount") is Node2D
		and (apex.get_node("BranchMount") as Node2D).position == Vector2(0.0, -170.0),
		"Apex marker does not use the dedicated topmost BranchMount offset."
	)

	tree_node.free()


func test_main_world_runtime() -> void:
	var main_world: Node = MAIN_WORLD_SCENE.instantiate()
	main_world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main_world)
	await get_tree().process_frame

	var tree_node: Node2D = main_world.get_node_or_null(
		"Entities/Tree"
	) as Node2D
	var attachment_points: Node = tree_node.get_node_or_null(
		"AttachmentPoints"
	)
	var apex: Marker2D = attachment_points.get_node_or_null(
		"Apex"
	) as Marker2D

	expect(
		is_instance_valid(apex),
		"MainWorld Tree is missing the Apex marker."
	)
	expect(
		is_instance_valid(apex)
		and apex.get_child_count() == 1
		and apex.get_node_or_null("BranchMount") is Node2D
		and apex.get_node("BranchMount").get_child_count() == 0,
		"MainWorld Apex BranchMount is not initialized EMPTY."
	)

	var growth_factor: float = float(
		tree_node.call("get_tree_growth_factor")
	)

	if is_instance_valid(apex):
		expect_vector(
			apex.position,
			Vector2(0.0, -95.0) * growth_factor,
			"Runtime Apex growth position"
		)
		expect_apex_topmost(attachment_points, "Sapling")

		var base_positions: Dictionary = tree_node.get(
			"attachment_base_positions"
		) as Dictionary
		expect(
			base_positions.has(apex.get_path()),
			"Tree growth system did not store the Apex base position."
		)

	var combat_branches: Array[Node] = (
		get_tree().get_nodes_in_group("combat_branch")
	)
	expect(
		combat_branches.size() == 4,
		"MainWorld no longer has exactly four equipped Branches."
	)
	var runtime_slots: Dictionary = {}

	for branch in combat_branches:
		expect(
			branch is CombatBranch,
			"A non-CombatBranch entered the combat_branch group."
		)
		expect(
			branch is not StrengthBranchVisual
			and branch is not BlossomBranchVisual,
			"A visual node was mistaken for a Branch."
		)
		expect(
			bool(branch.call("is_slot_assignment_valid")),
			"A current MainWorld Branch has an invalid slot assignment."
		)

		var slot_index: int = int(branch.get("slot_index"))
		expect(
			BranchSlotRules.is_standard_slot(slot_index),
			"A current Branch uses the Apex slot."
		)
		expect(
			not runtime_slots.has(slot_index),
			"MainWorld Branch slot %d is duplicated."
			% slot_index
		)
		runtime_slots[slot_index] = true

	var panel: Panel = main_world.get_node_or_null(
		"UI/BranchUpgradePanel"
	) as Panel
	expect(
		is_instance_valid(panel),
		"MainWorld is missing BranchUpgradePanel."
	)

	if is_instance_valid(panel):
		var branches_by_slot: Array = panel.get(
			"branches_by_slot"
		) as Array
		expect(
			branches_by_slot.size()
			== BranchSlotRules.TOTAL_SLOT_COUNT,
			"Branch panel does not expose five slots."
		)
		expect(
			branches_by_slot.size() == 5
			and not is_instance_valid(
				branches_by_slot[
					BranchSlotRules.APEX_SLOT - 1
				]
			),
			"Branch panel Apex slot is not empty."
		)

		var expected_button_texts: Array[String] = [
			"STRENGTH",
			"BLOSSOM",
			"STRENGTH",
			"BLOSSOM",
			"APEX"
		]

		for button_index in range(
			expected_button_texts.size()
		):
			var button_path: String = (
				"VBoxContainer/BranchSlotButtons/Slot%dButton"
				% (button_index + 1)
			)
			var slot_button: Button = panel.get_node_or_null(
				button_path
			) as Button
			expect(
				is_instance_valid(slot_button),
				"Branch panel is missing Slot%dButton."
				% (button_index + 1)
			)

			if not is_instance_valid(slot_button):
				continue

			expect(
				slot_button.text
				== expected_button_texts[button_index],
				"Slot %d button text changed."
				% (button_index + 1)
			)

			if button_index == BranchSlotRules.APEX_SLOT - 1:
				expect(
					slot_button.disabled,
					"Empty Apex slot button is enabled."
				)

	var maturity_age: int = int(
		tree_node.get("maturity_age")
	)
	tree_node.set("age", maturity_age)
	tree_node.call("update_tree_growth")

	if is_instance_valid(apex):
		expect_vector(
			apex.position,
			Vector2(0.0, -95.0),
			"Mature Apex growth position"
		)
		expect_apex_topmost(attachment_points, "Mature")

	main_world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func expect_apex_topmost(attachment_points: Node, state_name: String) -> void:
	var apex_mount := attachment_points.get_node("Apex/BranchMount") as Node2D
	var left_mount := attachment_points.get_node("LeftUpper/BranchMount") as Node2D
	var right_mount := attachment_points.get_node("RightUpper/BranchMount") as Node2D
	var apex_y: float = apex_mount.global_position.y
	expect(
		apex_y < left_mount.global_position.y,
		"%s Apex mount is not above LeftUpper." % state_name
	)
	expect(
		apex_y < right_mount.global_position.y,
		"%s Apex mount is not above RightUpper." % state_name
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
