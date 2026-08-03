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
			if branch is StrengthBranchVisual:
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
		talents_button.pressed.emit()
		await get_tree().process_frame

		expect(
			talent_screen.is_visible_in_tree(),
			"Pressing TALENTS did not open TalentScreen."
		)

	main_world.queue_free()
	await get_tree().process_frame
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
		"StrengthBranchVisual was mistaken for a branch."
	)

	var left_strength: Node = null
	var right_strength: Node = null

	for branch in available_branches:
		if branch is not CombatBranch:
			continue

		if branch.get("branch_id") != &"strength_branch":
			continue

		if int(branch.get("facing_side")) == 0:
			left_strength = branch
		else:
			right_strength = branch

	var blossom_branch: Node = null

	for branch in available_branches:
		if branch.get("branch_id") == &"blossom_branch":
			blossom_branch = branch
			break

	expect(
		is_instance_valid(left_strength),
		"TalentScreen did not accept the left Strength root."
	)

	expect(
		is_instance_valid(right_strength),
		"TalentScreen did not accept the right Strength root."
	)

	expect(
		is_instance_valid(blossom_branch),
		"TalentScreen did not accept an equipped Blossom root."
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

	if is_instance_valid(blossom_branch):
		talent_screen.call(
			"select_branch",
			blossom_branch
		)

		expect(
			talent_screen.get("selected_branch")
			== blossom_branch,
			"TalentScreen rejected an equipped Blossom root."
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
