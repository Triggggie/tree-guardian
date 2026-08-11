extends Node


const MAIN_WORLD_SCENE: PackedScene = preload(
	"res://scenes/main_world.tscn"
)


var failures: Array[String] = []


func _ready() -> void:
	await run_test()

	if failures.is_empty():
		print("TALENTS TAB SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print(
		"TALENTS TAB SMOKE TEST FAIL: %d failure(s)"
		% failures.size()
	)

	get_tree().quit(1)


func run_test() -> void:
	var branch_progress := get_node_or_null(
		"/root/BranchProgress"
	) as BranchProgressService
	if is_instance_valid(branch_progress):
		branch_progress.clear_runtime_progress_for_testing()
	var branch_loadout := get_node_or_null(
		"/root/BranchLoadout"
	) as BranchLoadoutService
	if is_instance_valid(branch_loadout):
		branch_loadout.clear_runtime_loadout_for_testing()

	var main_world: Node = MAIN_WORLD_SCENE.instantiate()
	main_world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main_world)
	await get_tree().process_frame

	var ui: CanvasLayer = main_world.get_node_or_null(
		"UI"
	) as CanvasLayer

	var talents_button: Button = main_world.get_node_or_null(
		"UI/TalentsButton"
	) as Button

	var talent_screen: Control = main_world.get_node_or_null(
		"UI/TalentScreen"
	) as Control

	var tree_screen: Control = main_world.get_node_or_null(
		"UI/TreeScreen"
	) as Control

	var active_branch: Node = null
	var visual_mistaken_for_branch: bool = false

	if is_instance_valid(talent_screen):
		active_branch = talent_screen.get(
			"selected_branch"
		) as Node

		var available_branches: Array = talent_screen.get(
			"available_branches"
		) as Array

		for branch in available_branches:
			if (
				branch is StrengthBranchVisual
				or branch is BlossomBranchVisual
			):
				visual_mistaken_for_branch = true

	print(
		"TALENTS node exists: ",
		is_instance_valid(talents_button)
	)

	if is_instance_valid(talents_button):
		print(
			"TALENTS visible: ",
			talents_button.is_visible_in_tree()
		)

		print(
			"TALENTS disabled: ",
			talents_button.disabled
		)

		print(
			"TALENTS parent: ",
			talents_button.get_parent().get_path()
		)

		print(
			"TALENTS global rect: ",
			talents_button.get_global_rect()
		)

	print(
		"Active branch: ",
		active_branch
	)

	print(
		"Active branch class: ",
		active_branch.get_class()
		if is_instance_valid(active_branch)
		else "NONE"
	)

	print(
		"Active branch_id: ",
		active_branch.get("branch_id")
		if is_instance_valid(active_branch)
		else &""
	)

	print(
		"Active branch talent tree valid: ",
		is_instance_valid(
			active_branch.get("talent_tree_definition")
		)
		if is_instance_valid(active_branch)
		else false
	)

	print(
		"Visual mistaken for branch: ",
		visual_mistaken_for_branch
	)

	expect(
		is_instance_valid(ui),
		"MainWorld UI CanvasLayer is missing."
	)

	expect(
		is_instance_valid(talents_button),
		"UI/TalentsButton is missing."
	)

	expect(
		is_instance_valid(talent_screen),
		"UI/TalentScreen is missing."
	)

	if is_instance_valid(talents_button):
		var talents_rect: Rect2 = (
			talents_button.get_global_rect()
		)

		expect(
			talents_button.is_inside_tree(),
			"TalentsButton is not inside the scene tree."
		)

		expect(
			talents_button.is_visible_in_tree(),
			"TalentsButton is not visible in the scene tree."
		)

		expect(
			not talents_button.disabled,
			"TalentsButton is disabled."
		)

		expect(
			talents_button.get_parent() == ui,
			"TalentsButton is not a direct child of UI."
		)

		expect(
			talents_button.text == "TALENTS",
			"TalentsButton text changed."
		)

		expect(
			talents_rect.position.x >= 0.0
			and talents_rect.position.y >= 0.0
			and talents_rect.end.x <= 1920.0
			and talents_rect.end.y <= 1080.0,
			"TalentsButton is outside the base viewport."
		)

	if is_instance_valid(talent_screen):
		test_branch_detection(
			talent_screen,
			visual_mistaken_for_branch
		)

	if (
		is_instance_valid(talents_button)
		and is_instance_valid(talent_screen)
	):
		if is_instance_valid(tree_screen):
			tree_screen.call("open_screen")
		talents_button.pressed.emit()
		await get_tree().process_frame

		expect(
			talent_screen.is_visible_in_tree(),
			"Pressing TALENTS did not open TalentScreen."
		)
		expect(
			not is_instance_valid(tree_screen)
			or not tree_screen.is_visible_in_tree(),
			"Opening TALENTS did not hide TREE."
		)

		var previous_slot_one = talent_screen.call(
			"_find_branch_by_slot_id",
			&"standard_slot_1"
		)
		expect(
			branch_loadout.equip_standard_branch(
				&"standard_slot_1",
				&"blossom_branch"
			),
			"TALENTS runtime swap setup failed."
		)
		await get_tree().process_frame
		var current_slot_one = talent_screen.call(
			"_find_branch_by_slot_id",
			&"standard_slot_1"
		)
		expect(
			not is_instance_valid(previous_slot_one)
			and is_instance_valid(current_slot_one)
			and current_slot_one.branch_id == &"blossom_branch",
			"TALENTS retained the freed Slot 1 Branch."
		)
		var refreshed_branches: Array = talent_screen.get("available_branches")
		expect(
			refreshed_branches.size() == 4
			and refreshed_branches[0].slot_index == 1
			and refreshed_branches[3].slot_index == 4,
			"TALENTS did not preserve runtime slot order."
		)

	main_world.queue_free()
	await get_tree().process_frame
	if is_instance_valid(branch_loadout):
		branch_loadout.clear_runtime_loadout_for_testing()
	await get_tree().process_frame

	expect(
		get_tree().get_nodes_in_group(
			"combat_branch"
		).is_empty(),
		"TALENTS fixture left a combat branch group member."
	)

	expect(
		get_tree().get_nodes_in_group(
			"strength_branch"
		).is_empty(),
		"TALENTS fixture left a Strength group member."
	)

	expect(
		get_tree().get_nodes_in_group(
			"blossom_branch"
		).is_empty(),
		"TALENTS fixture left a Blossom group member."
	)


func test_branch_detection(
	talent_screen: Control,
	visual_mistaken_for_branch: bool
) -> void:
	var available_branches: Array = talent_screen.get(
		"available_branches"
	) as Array

	expect(
		available_branches.size() == 4,
		"TalentScreen did not find all four equipped branches."
	)

	expect(
		not visual_mistaken_for_branch,
		"A Branch visual node was mistaken for a branch."
	)

	var left_strength: Node = null
	var right_strength: Node = null
	var left_blossom: Node = null
	var right_blossom: Node = null

	for branch in available_branches:
		if branch is not CombatBranch:
			continue

		var branch_id: StringName = branch.get("branch_id")
		var facing_side: int = int(branch.get("facing_side"))

		if branch_id == &"strength_branch":
			if facing_side == 0:
				left_strength = branch
			else:
				right_strength = branch
		elif branch_id == &"blossom_branch":
			if facing_side == 0:
				left_blossom = branch
			else:
				right_blossom = branch

	expect(
		is_instance_valid(left_strength),
		"TalentScreen did not accept the left Strength root."
	)

	expect(
		is_instance_valid(right_strength),
		"TalentScreen did not accept the right Strength root."
	)

	expect(
		is_instance_valid(left_blossom),
		"TalentScreen did not accept the left Blossom root."
	)

	expect(
		is_instance_valid(right_blossom),
		"TalentScreen did not accept the right Blossom root."
	)

	for strength_branch in [
		left_strength,
		right_strength
	]:
		if not is_instance_valid(strength_branch):
			continue

		expect(
			strength_branch is CombatBranch,
			"Selected Strength root is not a CombatBranch."
		)

		expect(
			strength_branch.get("branch_id")
			== &"strength_branch",
			"Strength root has an unexpected branch_id."
		)

		expect(
			is_instance_valid(
				strength_branch.get(
					"branch_definition"
				)
			),
			"Strength root has no BranchDefinition."
		)

		expect(
			is_instance_valid(
				strength_branch.get(
					"talent_tree_definition"
				)
			),
			"Strength root has no TalentTreeDefinition."
		)

		var talent_ids: Array[StringName] = (
			strength_branch.call(
				"get_talent_ids"
			) as Array[StringName]
		)

		expect(
			talent_ids.size() == 3,
			"Strength talent tree does not contain three talents."
		)

		talent_screen.call(
			"select_branch",
			strength_branch
		)

		expect(
			talent_screen.get("selected_branch")
			== strength_branch,
			"TalentScreen rejected an equipped Strength root."
		)

	for blossom_branch in [
		left_blossom,
		right_blossom
	]:
		if not is_instance_valid(blossom_branch):
			continue

		expect(
			blossom_branch is CombatBranch,
			"Selected Blossom root is not a CombatBranch."
		)
		expect(
			is_instance_valid(
				blossom_branch.get(
					"talent_tree_definition"
				)
			),
			"Blossom root has no TalentTreeDefinition."
		)

		var blossom_talent_ids: Array[StringName] = (
			blossom_branch.call(
				"get_talent_ids"
			) as Array[StringName]
		)
		var expected_blossom_talent_ids: Array[StringName] = [
			&"abundant_bloom",
			&"quickening_pollen",
			&"twin_petals"
		]
		var expected_blossom_display_names: Array[String] = [
			"Abundant Bloom",
			"Quickening Pollen",
			"Twin Petals"
		]

		expect(
			blossom_talent_ids
			== expected_blossom_talent_ids,
			"Blossom talent order changed."
		)

		for talent_index in range(
			expected_blossom_talent_ids.size()
		):
			expect(
				blossom_branch.call(
					"get_talent_display_name",
					expected_blossom_talent_ids[
						talent_index
					]
				) == expected_blossom_display_names[
					talent_index
				],
				"Blossom talent display name changed."
			)

		talent_screen.call(
			"select_branch",
			blossom_branch
		)

		expect(
			talent_screen.get("selected_branch")
			== blossom_branch,
			"TalentScreen rejected an equipped Blossom root."
		)

		var visible_talent_names: Array[String] = []
		var talent_nodes: Control = talent_screen.get(
			"talent_nodes"
		) as Control

		if is_instance_valid(talent_nodes):
			for talent_node in talent_nodes.get_children():
				if talent_node.is_queued_for_deletion():
					continue

				if talent_node is Button:
					var button_lines: PackedStringArray = (
						(talent_node as Button).text.split("\n")
					)

					if button_lines.size() >= 2:
						visible_talent_names.append(
							button_lines[1]
						)

		expect(
			visible_talent_names
			== expected_blossom_display_names,
			"TalentScreen did not display the three Blossom talents "
			+ "in Resource order."
		)

	if (
		is_instance_valid(left_blossom)
		and is_instance_valid(right_blossom)
	):
		left_blossom.call("add_xp", 2)
		expect(
			left_blossom.get("available_talent_points") == 1
			and right_blossom.get("available_talent_points") == 1,
			"Blossom slots did not each receive the full Talent Point budget."
		)
		talent_screen.call("select_branch", left_blossom)

		expect(
			bool(
				left_blossom.call(
					"purchase_talent",
					&"abundant_bloom"
				)
			),
			"Could not purchase Abundant Bloom on left Blossom."
		)
		expect(
			bool(
				left_blossom.call(
					"has_talent",
					&"abundant_bloom"
				)
			),
			"Left Blossom did not retain its purchased talent."
		)
		expect(
			not bool(
				right_blossom.call(
					"has_talent",
					&"abundant_bloom"
				)
			),
			"Abundant Bloom leaked from Slot 2 to Slot 4."
		)
		expect(
			right_blossom.get("available_talent_points") == 1,
			"Slot 4 lost its independent Talent Point budget."
		)
		talent_screen.call("select_branch", right_blossom)
		expect(
			bool(right_blossom.call("purchase_talent", &"twin_petals")),
			"Could not purchase Twin Petals on Slot 4."
		)
		expect(
			not bool(left_blossom.call("has_talent", &"twin_petals")),
			"Twin Petals leaked from Slot 4 to Slot 2."
		)
		expect(
			left_blossom.get("talent_effect_set")
			!= right_blossom.get("talent_effect_set"),
			"Physical Blossom instances share one talent runtime object."
		)
		expect(
			not bool(left_strength.call("has_talent", &"abundant_bloom"))
			and not bool(right_strength.call("has_talent", &"abundant_bloom")),
			"Blossom talent leaked into Strength slots."
		)

	if is_instance_valid(left_strength):
		talent_screen.call(
			"select_branch",
			left_strength
		)

		expect(
			talent_screen.get("selected_branch")
			== left_strength,
			"TalentScreen did not restore Strength after Blossom."
		)


func expect(condition: bool, message: String) -> void:
	if condition:
		return

	failures.append(message)
	push_error(message)
