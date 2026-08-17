extends Node


const STRENGTH_SCENE: PackedScene = preload("res://scenes/branches/strength_branch.tscn")


class MockTree:
	extends Node2D
	var current_health: float = 100.0
	var max_health: float = 100.0


class MockEnemy:
	extends Node2D
	var lane_index: int = 3
	var current_health: float = 1000.0
	var maximum_health: float = 1000.0
	var normal_enemy: bool = true
	var interruptible: bool = true
	var attacking: bool = true
	var damage_events: Array[float] = []
	var knockback_events: Array[float] = []
	var interrupt_count: int = 0

	func is_targetable() -> bool:
		return current_health > 0.0 and is_inside_tree()

	func get_lane_index() -> int:
		return lane_index

	func take_damage(amount: float, _source: Node = null) -> void:
		damage_events.append(amount)
		current_health = max(current_health - amount, 0.0)

	func apply_knockback(distance: float) -> void:
		knockback_events.append(distance)
		global_position.x += distance

	func can_be_interrupted() -> bool:
		return interruptible and normal_enemy and current_health > 0.0

	func interrupt_attack() -> bool:
		if not can_be_interrupted() or not attacking:
			return false
		attacking = false
		interrupt_count += 1
		return true

	func is_normal_enemy() -> bool:
		return normal_enemy

	func get_current_health() -> float:
		return current_health

	func get_maximum_health() -> float:
		return maximum_health

	func get_health_ratio() -> float:
		return current_health / maximum_health


var failures: Array[String] = []


func _ready() -> void:
	await test_cleaver_chain_and_grand_sweep()
	await test_earthbreaker_chain()
	await test_disruptor_and_protector()
	await test_executioner_and_relentless()
	if failures.is_empty():
		print("STRENGTH FULL TALENT RUNTIME SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("STRENGTH FULL TALENT RUNTIME SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func test_cleaver_chain_and_grand_sweep() -> void:
	var fixture: Node2D = _create_fixture("CleaverFixture")
	var branch: CombatBranch = _create_branch(fixture, 1)
	_purchase_path(branch, [&"sweeping_strike", &"cleaver", &"serrated_arc", &"reaping_sweep", &"whirling_bough"])
	var primary: MockEnemy = _create_enemy(fixture, Vector2(60.0, 0.0))
	var enemies: Array[MockEnemy] = []
	for index in range(7):
		enemies.append(_create_enemy(fixture, Vector2(82.0 + index * 12.0, float(index % 2) * 8.0)))
	branch.call("perform_strength_hit", primary)
	var first_cycle_hits: int = _count_damage_events(enemies)
	expect(first_cycle_hits == 3, "Cleaver + Serrated Arc did not hit exactly three fresh secondary targets.")
	enemies[0].current_health = 1.0
	branch.call("perform_strength_hit", primary)
	expect(_count_damage_events(enemies) - first_cycle_hits == 4, "Reaping Sweep did not add exactly one fresh bonus target after a kill.")
	var before_grand: int = _count_damage_events(enemies)
	branch.call("perform_strength_hit", primary)
	branch.call("perform_strength_hit", primary)
	var grand_cycle_delta: int = _count_damage_events(enemies) - before_grand
	expect(grand_cycle_delta == 8, "Fourth attack did not replace the normal chain with five Grand Sweep targets.")
	expect(branch.talent_effect_set.crusher_effect.resolved_primary_attack_count == 4, "Grand Sweep counter did not track resolved primaries.")
	branch.stop_combat()
	expect(branch.talent_effect_set.crusher_effect.resolved_primary_attack_count == 0, "Crusher runtime counter survived stop_combat().")
	await _cleanup(fixture)


func test_earthbreaker_chain() -> void:
	var fixture: Node2D = _create_fixture("EarthbreakerFixture")
	var branch: CombatBranch = _create_branch(fixture, 1)
	_purchase_path(branch, [&"sweeping_strike", &"earthbreaker", &"fault_line", &"aftershock", &"worldroot_slam"])
	var primary: MockEnemy = _create_enemy(fixture, Vector2(60.0, 0.0))
	var outward: Array[MockEnemy] = []
	for index in range(8):
		outward.append(_create_enemy(fixture, Vector2(90.0 + index * 20.0, 20.0)))
	var opposite_geometry: MockEnemy = _create_enemy(fixture, Vector2(45.0, 0.0))
	for _hit in range(3):
		branch.call("perform_strength_hit", primary)
	expect(_count_damage_events(outward) >= 5, "Fault Line did not hit outward targets on the third primary.")
	var opposite_received_only_sweep_damage: bool = true
	for damage in opposite_geometry.damage_events:
		if not is_equal_approx(damage, 6.0):
			opposite_received_only_sweep_damage = false
	expect(opposite_received_only_sweep_damage, "Fault Line damaged a target behind the primary.")
	var before_aftershock: int = _count_damage_events(outward)
	await get_tree().create_timer(0.30).timeout
	expect(_count_damage_events(outward) > before_aftershock, "Aftershock did not resolve after its delay.")
	for _hit in range(6):
		branch.call("perform_strength_hit", primary)
	expect(branch.talent_effect_set.earthbreaker_effect.earthbreaker_trigger_count == 3, "Worldroot Slam did not occur on the third Earthbreaker trigger.")
	var knocked_targets: int = 0
	for enemy in outward:
		if not enemy.knockback_events.is_empty():
			knocked_targets += 1
	expect(knocked_targets > 0, "Worldroot Slam did not apply normal-enemy knockback.")
	branch.stop_combat()
	await get_tree().create_timer(0.30).timeout
	expect(branch.talent_effect_set.earthbreaker_effect.earthbreaker_trigger_count == 0, "Earthbreaker state survived stop_combat().")
	await _cleanup(fixture)


func test_disruptor_and_protector() -> void:
	var disruptor_fixture: Node2D = _create_fixture("DisruptorFixture")
	var disruptor: CombatBranch = _create_branch(disruptor_fixture, 1)
	_purchase_path(disruptor, [&"rebuff", &"disruptor", &"staggering_blow", &"disruptive_arc", &"uproot"])
	var primary: MockEnemy = _create_enemy(disruptor_fixture, Vector2(60.0, 0.0))
	var nearby: MockEnemy = _create_enemy(disruptor_fixture, Vector2(85.0, 0.0))
	var boss: MockEnemy = _create_enemy(disruptor_fixture, Vector2(100.0, 0.0))
	boss.normal_enemy = false
	boss.interruptible = false
	disruptor.call("perform_strength_hit", primary)
	expect(primary.interrupt_count == 1, "Disruptor did not interrupt the primary normal enemy.")
	expect(nearby.interrupt_count == 1, "Disruptive Arc did not interrupt a nearby normal enemy.")
	expect(boss.interrupt_count == 0, "Disruptive Arc interrupted a boss.")
	primary.attacking = true
	disruptor.call("perform_strength_hit", primary)
	primary.attacking = true
	disruptor.call("perform_strength_hit", primary)
	expect(primary.knockback_events.has(70.0), "Third-hit Staggering Blow did not double Rebuff distance.")
	primary.attacking = true
	disruptor.call("perform_strength_hit", primary)
	primary.attacking = true
	disruptor.call("perform_strength_hit", primary)
	expect(nearby.knockback_events.size() >= 2, "Fifth-hit Uproot did not displace nearby enemies.")
	await _cleanup(disruptor_fixture)

	var protector_fixture: Node2D = _create_fixture("ProtectorFixture")
	var protector: CombatBranch = _create_branch(protector_fixture, 1)
	_purchase_path(protector, [&"rebuff", &"protector", &"hold_the_line", &"sentinel_reflex", &"last_bastion"])
	var tree_node := protector_fixture.get_node("MockTree") as MockTree
	var danger: MockEnemy = _create_enemy(protector_fixture, Vector2(120.0, 0.0))
	var ordinary: MockEnemy = _create_enemy(protector_fixture, Vector2(70.0, 0.0))
	expect(protector.call("find_nearest_enemy") == ordinary, "Protector chose the wrong closest-to-tree danger target.")
	tree_node.current_health = 35.0
	var expanded_danger: MockEnemy = _create_enemy(protector_fixture, Vector2(320.0, 0.0))
	expect(protector.talent_effect_set.warden_effect.get_danger_radius() == 350.0, "Last Bastion did not expand danger radius at 35% HP.")
	protector.call("perform_strength_hit", danger)
	expect(danger.knockback_events.has(87.5), "Last Bastion danger Rebuff was not 2.5x base distance.")
	tree_node.current_health = 36.0
	expect(protector.talent_effect_set.warden_effect.get_danger_radius() == 250.0, "Last Bastion remained active above 35% HP.")
	expanded_danger.current_health = 0.0
	await _cleanup(protector_fixture)


func test_executioner_and_relentless() -> void:
	var execution_fixture: Node2D = _create_fixture("ExecutionFixture")
	var executioner: CombatBranch = _create_branch(execution_fixture, 1)
	_purchase_path(executioner, [&"marked_prey", &"executioner", &"cull_the_weak", &"finishing_rhythm", &"final_cut"])
	var normal: MockEnemy = _create_enemy(execution_fixture, Vector2(60.0, 0.0))
	for _hit in range(6):
		executioner.call("perform_strength_hit", normal)
	normal.current_health = 100.0
	normal.maximum_health = 1000.0
	executioner.call("perform_strength_hit", normal)
	expect(normal.current_health <= 0.0, "Final Cut did not execute a normal enemy through damage.")
	expect(executioner.talent_effect_set.duelist_effect.cull_carryover_stacks == 2, "Cull the Weak did not store two carryover stacks.")
	var boss: MockEnemy = _create_enemy(execution_fixture, Vector2(80.0, 0.0))
	boss.normal_enemy = false
	for _hit in range(6):
		executioner.call("perform_strength_hit", boss)
	boss.current_health = 100.0
	executioner.call("perform_strength_hit", boss)
	expect(boss.current_health > 0.0, "Final Cut instantly executed a boss.")
	await _cleanup(execution_fixture)

	var relentless_fixture: Node2D = _create_fixture("RelentlessFixture")
	var relentless: CombatBranch = _create_branch(relentless_fixture, 1)
	_purchase_path(relentless, [&"marked_prey", &"relentless", &"pursuit", &"unbroken_combo", &"relentless_flurry"])
	var target_a: MockEnemy = _create_enemy(relentless_fixture, Vector2(60.0, 0.0))
	var target_b: MockEnemy = _create_enemy(relentless_fixture, Vector2(80.0, 0.0))
	for _hit in range(5):
		relentless.call("perform_strength_hit", target_a)
	relentless.call("perform_strength_hit", target_b)
	expect(is_equal_approx(target_b.damage_events[0], 12.0), "Relentless did not carry half of four stacks to a new target.")
	relentless.call("perform_strength_hit", target_a)
	expect(relentless.talent_effect_set.marked_prey_effect.get_stack_count() == 4, "Pursuit did not restore the recent higher stack snapshot.")
	relentless.call("perform_strength_hit", target_a)
	var before_followups: int = target_a.damage_events.size()
	relentless.call("perform_strength_hit", target_a)
	await get_tree().create_timer(0.20).timeout
	expect(target_a.damage_events.size() - before_followups == 3, "Relentless Flurry did not add exactly two non-recursive follow-ups.")
	relentless.stop_combat()
	expect(relentless.talent_effect_set.duelist_effect.recent_snapshots.is_empty(), "Pursuit snapshots survived stop_combat().")
	await _cleanup(relentless_fixture)


func _create_fixture(fixture_name: String) -> Node2D:
	var fixture := Node2D.new()
	fixture.name = fixture_name
	var tree_node := MockTree.new()
	tree_node.name = "MockTree"
	fixture.add_child(tree_node)
	tree_node.add_to_group("tree")
	var service := BranchProgressService.new()
	service.name = "BranchProgressService"
	fixture.add_child(service)
	add_child(fixture)
	return fixture


func _create_branch(fixture: Node2D, slot_index: int) -> CombatBranch:
	var branch := STRENGTH_SCENE.instantiate() as CombatBranch
	branch.slot_index = slot_index
	branch.facing_side = 1
	branch.branch_progress_service = fixture.get_node("BranchProgressService") as BranchProgressService
	branch.process_mode = Node.PROCESS_MODE_DISABLED
	fixture.add_child(branch)
	(branch.get_node("CooldownTimer") as Timer).stop()
	return branch


func _create_enemy(fixture: Node2D, enemy_position: Vector2) -> MockEnemy:
	var enemy := MockEnemy.new()
	enemy.position = enemy_position
	fixture.add_child(enemy)
	enemy.add_to_group("enemies")
	return enemy


func _purchase_path(branch: CombatBranch, talent_ids: Array[StringName]) -> void:
	var service: BranchProgressService = branch.branch_progress_service
	var progress: BranchProgressRecord = service.get_progress(branch.branch_id)
	progress.branch_level = 14
	progress.total_talent_points_earned = 5
	service.synchronize_branch(branch)
	for talent_id in talent_ids:
		expect(branch.purchase_talent(talent_id), "Could not purchase runtime talent '%s'." % talent_id)


func _count_damage_events(enemies: Array[MockEnemy]) -> int:
	var total: int = 0
	for enemy in enemies:
		total += enemy.damage_events.size()
	return total


func _cleanup(fixture: Node2D) -> void:
	fixture.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
