extends Node


const THORN_SCENE: PackedScene = preload("res://scenes/branches/thorn_crown_branch.tscn")
var failures: Array[String] = []


func _ready() -> void:
	var fixture := Node2D.new()
	var progress := BranchProgressService.new()
	fixture.add_child(progress)
	add_child(fixture)
	var branch := THORN_SCENE.instantiate() as CombatBranch
	branch.process_mode = Node.PROCESS_MODE_DISABLED
	branch.slot_index = BranchSlotRules.APEX_SLOT
	branch.branch_progress_service = progress
	fixture.add_child(branch)
	var visual := branch.get_node("Visual") as ThornCrownVisual
	branch.process_mode = Node.PROCESS_MODE_INHERIT
	visual.process_mode = Node.PROCESS_MODE_ALWAYS
	(branch.get_node("CooldownTimer") as Timer).stop()
	expect(is_instance_valid(visual), "Thorn Crown Visual node or script is missing.")
	expect(visual.has_bilateral_geometry(), "Thorn Crown visual is not bilateral.")
	var attack_events: Array[float] = []
	visual.attack_animation_started.connect(
		func(intensity: float) -> void: attack_events.append(intensity)
	)
	visual.play_attack()
	visual.attack_tween.custom_step(0.05)
	expect(visual.is_attack_animation_active(), "Thorn Crown attack Tween was not retained.")
	expect(visual.attack_progress > 0.0, "Thorn Crown procedural pulse did not animate.")
	expect(attack_events == [1.0], "Thorn Crown attack presentation signal is wrong.")
	visual.attack_tween.custom_step(0.50)
	expect(
		not visual.is_attack_animation_active()
		and is_zero_approx(visual.attack_progress)
		and visual.scale == Vector2.ONE,
		"Thorn Crown attack pulse did not return to idle."
	)
	visual.play_attack(1.2)
	visual.stop_attack_animation()
	expect(
		not visual.is_attack_animation_active()
		and is_zero_approx(visual.attack_progress)
		and visual.scale == Vector2.ONE,
		"Thorn Crown attack pulse cleanup did not reset presentation."
	)
	var initial_length: float = visual.get_current_arm_length()
	var initial_thorns: int = visual.get_thorns_per_arm()
	visual.set_branch_level(10)
	expect(
		visual.get_current_arm_length() > initial_length
		and visual.get_thorns_per_arm() > initial_thorns
		and visual.get_arm_tip(-1.0).x < 0.0
		and visual.get_arm_tip(1.0).x > 0.0,
		"Thorn Crown level visual growth or bilateral arm geometry failed."
	)
	var left_burst := ThornBurstVisual.new()
	var right_burst := ThornBurstVisual.new()
	add_child(left_burst)
	add_child(right_burst)
	left_burst.position = Vector2(-100.0, 0.0)
	right_burst.position = Vector2(100.0, 0.0)
	left_burst.setup(90.0)
	right_burst.setup(98.0)
	expect(
		left_burst.position.x < 0.0
		and right_burst.position.x > 0.0
		and is_equal_approx(left_burst.burst_radius, 90.0)
		and is_equal_approx(right_burst.burst_radius, 98.0),
		"Bilateral Thorn Burst feedback setup failed."
	)
	await get_tree().create_timer(0.30).timeout
	expect(
		not is_instance_valid(left_burst) and not is_instance_valid(right_burst),
		"Transient Thorn Burst feedback did not self-clean."
	)
	var dependencies: PackedStringArray = ResourceLoader.get_dependencies(
		"res://scenes/branches/thorn_crown_branch.tscn"
	)
	for dependency in dependencies:
		expect(
			not String(dependency).to_lower().ends_with(".png")
			and not String(dependency).to_lower().ends_with(".svg"),
			"Thorn Crown visual depends on an external image asset."
		)
	fixture.queue_free()
	await get_tree().process_frame

	if failures.is_empty():
		print("THORN CROWN VISUAL SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("THORN CROWN VISUAL SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
