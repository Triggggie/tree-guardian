extends Node


var failures: Array[String] = []
var depleted_signal_count: int = 0
var attack_request_count: int = 0
var enemies_cleared_count: int = 0


func _ready() -> void:
	print("ENEMY RUNTIME SMOKE TEST START")

	test_enemy_definition()
	test_bark_runner_definition()
	await test_bark_runner_scene()
	await test_guardian_grove_boss_definitions_and_scenes()
	test_wave_enemy_entry_definition()
	test_guardian_grove_schedule_and_waves()
	test_stage_and_wave_definition()
	test_wave_definition_multi_entry_data()
	test_substage_definition_validation()
	test_wave_director_substage_queries()
	test_enemy_spawn_request()
	test_health_component()
	await test_attack_component()
	await test_movement_component()
	await test_enemy_tracker()
	await test_lane_registry()
	await test_spawn_director_multi_request_batch()
	await test_spawn_director_mixed_enemy_batch()

	finish_test()


func expect(
	condition: bool,
	message: String
) -> void:
	if condition:
		return

	failures.append(message)
	push_error(message)


func test_enemy_definition() -> void:
	var definition: EnemyDefinition = (
		GameContent.get_enemy(&"bark_beetle")
	)

	expect(
		is_instance_valid(definition),
		"Bark Beetle EnemyDefinition was not found."
	)

	if not is_instance_valid(definition):
		return

	expect(
		definition.is_valid_definition(),
		"Bark Beetle EnemyDefinition is invalid."
	)
	expect(
		definition.enemy_id == &"bark_beetle",
		"Bark Beetle enemy ID is incorrect."
	)
	expect(
		definition.enemy_scene != null,
		"Bark Beetle enemy scene is missing."
	)
	expect(
		is_equal_approx(
			definition.movement_speed,
			120.0
		),
		"Bark Beetle movement speed is not 120.0."
	)
	expect(
		is_equal_approx(
			definition.maximum_health,
			12.0
		),
		"Bark Beetle maximum health is not 12.0."
	)
	expect(
		is_equal_approx(
			definition.attack_damage,
			1.5
		),
		"Bark Beetle attack damage is not 1.5."
	)
	expect(
		is_equal_approx(
			definition.attack_interval,
			1.5
		),
		"Bark Beetle attack interval is not 1.5."
	)
	expect(
		is_equal_approx(
			definition.attack_range,
			130.0
		),
		"Bark Beetle attack range is not 130.0."
	)
	expect(
		definition.essence_reward == 1,
		"Bark Beetle Essence reward is not 1."
	)
	expect(
		definition.experience_reward == 1,
		"Bark Beetle XP reward is not 1."
	)
	expect(
		GameContent.get_enemy(&"missing_enemy") == null,
		"Missing enemy lookup did not return null."
	)


func test_bark_runner_definition() -> void:
	var bark_beetle: EnemyDefinition = (
		GameContent.get_enemy(&"bark_beetle")
	)
	var bark_runner: EnemyDefinition = (
		GameContent.get_enemy(&"bark_runner")
	)

	expect(
		is_instance_valid(bark_runner),
		"Bark Runner EnemyDefinition was not found."
	)

	if not is_instance_valid(bark_runner):
		return

	expect(
		bark_runner.is_valid_definition(),
		"Bark Runner EnemyDefinition is invalid."
	)
	expect(
		bark_runner.enemy_id == &"bark_runner",
		"Bark Runner enemy ID is incorrect."
	)
	expect(
		bark_runner.display_name == "Bark Runner",
		"Bark Runner display name is incorrect."
	)
	expect(
		bark_runner.enemy_scene != null,
		"Bark Runner enemy scene is missing."
	)
	expect(
		is_equal_approx(
			bark_runner.maximum_health,
			7.0
		),
		"Bark Runner maximum health is not 7.0."
	)
	expect(
		is_equal_approx(
			bark_runner.movement_speed,
			185.0
		),
		"Bark Runner movement speed is not 185.0."
	)
	expect(
		is_equal_approx(
			bark_runner.attack_damage,
			0.75
		),
		"Bark Runner attack damage is not 0.75."
	)
	expect(
		is_equal_approx(
			bark_runner.attack_interval,
			1.0
		),
		"Bark Runner attack interval is not 1.0."
	)
	expect(
		is_equal_approx(
			bark_runner.attack_range,
			110.0
		),
		"Bark Runner attack range is not 110.0."
	)
	expect(
		bark_runner.essence_reward == 1,
		"Bark Runner Essence reward is not 1."
	)
	expect(
		bark_runner.experience_reward == 1,
		"Bark Runner XP reward is not 1."
	)

	if is_instance_valid(bark_beetle):
		expect(
			bark_runner.movement_speed
			> bark_beetle.movement_speed,
			"Bark Runner is not faster than Bark Beetle."
		)
		expect(
			bark_runner.maximum_health
			< bark_beetle.maximum_health,
			"Bark Runner is not weaker than Bark Beetle."
		)
		expect(
			bark_runner.attack_damage
			< bark_beetle.attack_damage,
			"Bark Runner is not less damaging than Bark Beetle."
		)

	print(
		"BARK RUNNER DEFINITION TEST PASS: "
		+ "health=7, speed=185, damage=0.75"
	)


func test_bark_runner_scene() -> void:
	var definition: EnemyDefinition = (
		GameContent.get_enemy(&"bark_runner")
	)

	expect(
		is_instance_valid(definition),
		"Bark Runner scene test could not load its definition."
	)

	if not is_instance_valid(definition):
		return

	var fixture := Node2D.new()
	fixture.name = "BarkRunnerSceneFixture"
	add_child(fixture)

	var tree_target := Node2D.new()
	tree_target.name = "Tree"
	tree_target.position = Vector2(500.0, 40.0)
	fixture.add_child(tree_target)
	tree_target.add_to_group("tree")

	var enemy_tracker := EnemyTracker.new()
	enemy_tracker.name = "EnemyTracker"
	fixture.add_child(enemy_tracker)

	var lane_registry := LaneRegistry.new()
	lane_registry.name = "LaneRegistry"
	fixture.add_child(lane_registry)

	var runner_instance: Node = definition.enemy_scene.instantiate()
	expect(
		is_instance_valid(runner_instance),
		"Bark Runner scene did not instantiate."
	)
	expect(
		runner_instance is CharacterBody2D,
		"Bark Runner scene root is not CharacterBody2D."
	)

	if not (runner_instance is CharacterBody2D):
		if is_instance_valid(runner_instance):
			runner_instance.free()
		fixture.queue_free()
		await get_tree().process_frame
		return

	var runner: CharacterBody2D = (
		runner_instance as CharacterBody2D
	)
	var configured_successfully: bool = bool(
		runner.call(
			"configure_from_definition",
			definition,
			definition.maximum_health,
			1.0
		)
	)
	expect(
		configured_successfully,
		"Bark Runner rejected its EnemyDefinition."
	)

	fixture.add_child(runner)
	runner.global_position = Vector2(0.0, 40.0)
	runner.call(
		"setup_crowd_formation",
		-1.0,
		0,
		40.0,
		0,
		1.0,
		0.0,
		1.0
	)

	var health_component: EnemyHealthComponent = (
		runner.get_node_or_null("HealthComponent")
		as EnemyHealthComponent
	)
	var attack_component: EnemyAttackComponent = (
		runner.get_node_or_null("AttackComponent")
		as EnemyAttackComponent
	)
	var movement_component: EnemyMovementComponent = (
		runner.get_node_or_null("MovementComponent")
		as EnemyMovementComponent
	)

	expect(
		is_instance_valid(health_component),
		"Bark Runner has no HealthComponent."
	)
	expect(
		is_instance_valid(attack_component),
		"Bark Runner has no AttackComponent."
	)
	expect(
		is_instance_valid(movement_component),
		"Bark Runner has no MovementComponent."
	)
	expect(
		runner.get_node_or_null("CollisionShape2D") != null,
		"Bark Runner has no CollisionShape2D."
	)
	expect(
		runner.get_node_or_null("AttackComponent/AttackTimer")
		is Timer,
		"Bark Runner has no AttackTimer."
	)
	expect(
		runner.get_node_or_null("Visual") is Node2D,
		"Bark Runner has no Visual node."
	)
	expect(
		runner.get_node_or_null("HealthBar") != null,
		"Bark Runner has no HealthBar."
	)
	expect(
		runner.get("enemy_definition") == definition,
		"Bark Runner did not retain its EnemyDefinition."
	)
	expect(
		int(runner.get("forest_essence_reward")) == 1,
		"Bark Runner did not apply its Essence reward."
	)
	expect(
		int(runner.get("xp_reward")) == 1,
		"Bark Runner did not apply its XP reward."
	)

	if is_instance_valid(health_component):
		expect(
			health_component.is_initialized(),
			"Bark Runner HealthComponent was not initialized."
		)
		expect(
			is_equal_approx(
				health_component.get_maximum_health(),
				7.0
			),
			"Bark Runner HealthComponent maximum is not 7.0."
		)

	if is_instance_valid(attack_component):
		expect(
			attack_component.is_initialized(),
			"Bark Runner AttackComponent was not initialized."
		)
		expect(
			is_equal_approx(
				attack_component.get_attack_damage(),
				0.75
			),
			"Bark Runner AttackComponent damage is not 0.75."
		)
		expect(
			is_equal_approx(
				attack_component.get_attack_interval(),
				1.0
			),
			"Bark Runner AttackComponent interval is not 1.0."
		)

	if is_instance_valid(movement_component):
		expect(
			movement_component.is_initialized(),
			"Bark Runner MovementComponent was not initialized."
		)
		expect(
			is_equal_approx(
				float(movement_component.get("_move_speed")),
				185.0
			),
			"Bark Runner MovementComponent speed is not 185.0."
		)

	expect(
		enemy_tracker.get_enemy_count() == 1,
		"Bark Runner did not register with EnemyTracker."
	)
	expect(
		lane_registry.is_enemy_registered(runner),
		"Bark Runner did not register with LaneRegistry."
	)

	runner.call("stop_combat")
	runner.remove_from_group("enemies")
	runner.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	expect(
		enemy_tracker.get_enemy_count() == 0,
		"EnemyTracker retained Bark Runner after cleanup."
	)
	expect(
		lane_registry.get_lane_enemy_count(-1.0, 0) == 0,
		"LaneRegistry retained Bark Runner after cleanup."
	)
	expect(
		get_tree().get_nodes_in_group("enemies").is_empty(),
		"Bark Runner scene cleanup left an enemy group member."
	)

	fixture.queue_free()
	await get_tree().process_frame

	expect(
		get_tree().get_nodes_in_group("enemy_tracker").is_empty(),
		"Bark Runner scene fixture left EnemyTracker registered."
	)
	expect(
		get_tree().get_nodes_in_group("lane_registry").is_empty(),
		"Bark Runner scene fixture left LaneRegistry registered."
	)
	expect(
		get_tree().get_nodes_in_group("tree").is_empty(),
		"Bark Runner scene fixture left a tree group member."
	)

	print(
		"BARK RUNNER SCENE TEST PASS: components and cleanup verified"
	)


func test_wave_enemy_entry_definition() -> void:
	var entry: WaveEnemyEntryDefinition = (
		_create_standard_test_enemy_entry()
	)

	expect(
		entry.is_valid_definition(),
		"Valid WaveEnemyEntryDefinition was rejected."
	)
	expect(
		entry.get_count_for_stage_wave(1) == 2,
		"Entry Stage Wave 1 count is not 2."
	)
	expect(
		entry.get_count_for_stage_wave(2) == 2,
		"Entry Stage Wave 2 count is not 2."
	)
	expect(
		entry.get_count_for_stage_wave(3) == 2,
		"Entry Stage Wave 3 count is not 2."
	)
	expect(
		entry.get_count_for_stage_wave(4) == 3,
		"Entry Stage Wave 4 count is not 3."
	)
	expect(
		entry.get_count_for_stage_wave(6) == 3,
		"Entry Stage Wave 6 count is not 3."
	)
	expect(
		entry.get_count_for_stage_wave(7) == 4,
		"Entry Stage Wave 7 count is not 4."
	)
	expect(
		entry.get_count_for_stage_wave(100) == 30,
		"Entry Stage Wave 100 count is not capped at 30."
	)
	expect(
		entry.get_count_for_stage_wave(1000) == 30,
		"Entry Stage Wave 1000 count is not capped at 30."
	)
	expect(
		entry.get_count_for_stage_wave(0) == 2,
		"Entry Stage Wave 0 safe count is not 2."
	)

	var delayed_entry: WaveEnemyEntryDefinition = (
		_create_standard_test_enemy_entry()
	)
	delayed_entry.base_count_per_side = 1
	delayed_entry.count_scaling_start_stage_wave = 101
	delayed_entry.count_increase_interval = 10
	delayed_entry.count_increase_amount = 1
	delayed_entry.maximum_count_per_side = 5

	expect(
		delayed_entry.is_valid_definition(),
		"Valid delayed Wave enemy entry was rejected."
	)
	expect(
		delayed_entry.get_count_for_stage_wave(100) == 1,
		"Delayed entry Stage Wave 100 count is not 1."
	)
	expect(
		delayed_entry.get_count_for_stage_wave(101) == 1,
		"Delayed entry Stage Wave 101 count is not 1."
	)
	expect(
		delayed_entry.get_count_for_stage_wave(110) == 1,
		"Delayed entry Stage Wave 110 count is not 1."
	)
	expect(
		delayed_entry.get_count_for_stage_wave(111) == 2,
		"Delayed entry Stage Wave 111 count is not 2."
	)
	expect(
		delayed_entry.get_count_for_stage_wave(121) == 3,
		"Delayed entry Stage Wave 121 count is not 3."
	)

	var fixed_entry: WaveEnemyEntryDefinition = (
		_create_standard_test_enemy_entry()
	)
	fixed_entry.base_count_per_side = 4
	fixed_entry.count_increase_interval = 0
	fixed_entry.count_increase_amount = 0
	fixed_entry.maximum_count_per_side = 4
	expect(
		fixed_entry.is_valid_definition(),
		"Valid fixed-count Wave enemy entry was rejected."
	)
	expect(
		fixed_entry.get_count_for_stage_wave(1000) == 4,
		"Fixed-count entry changed across Stage Waves."
	)

	var empty_id_entry: WaveEnemyEntryDefinition = (
		_create_standard_test_enemy_entry()
	)
	empty_id_entry.enemy_id = &""
	expect(
		not empty_id_entry.is_valid_definition(),
		"Wave enemy entry accepted an empty enemy ID."
	)

	var zero_base_entry: WaveEnemyEntryDefinition = (
		_create_standard_test_enemy_entry()
	)
	zero_base_entry.base_count_per_side = 0
	expect(
		not zero_base_entry.is_valid_definition(),
		"Wave enemy entry accepted base count 0."
	)

	var zero_start_entry: WaveEnemyEntryDefinition = (
		_create_standard_test_enemy_entry()
	)
	zero_start_entry.count_scaling_start_stage_wave = 0
	expect(
		not zero_start_entry.is_valid_definition(),
		"Wave enemy entry accepted scaling start 0."
	)

	var negative_interval_entry: WaveEnemyEntryDefinition = (
		_create_standard_test_enemy_entry()
	)
	negative_interval_entry.count_increase_interval = -1
	expect(
		not negative_interval_entry.is_valid_definition(),
		"Wave enemy entry accepted a negative count interval."
	)

	var negative_amount_entry: WaveEnemyEntryDefinition = (
		_create_standard_test_enemy_entry()
	)
	negative_amount_entry.count_increase_amount = -1
	expect(
		not negative_amount_entry.is_valid_definition(),
		"Wave enemy entry accepted a negative count amount."
	)

	var zero_interval_entry: WaveEnemyEntryDefinition = (
		_create_standard_test_enemy_entry()
	)
	zero_interval_entry.count_increase_interval = 0
	zero_interval_entry.count_increase_amount = 1
	expect(
		not zero_interval_entry.is_valid_definition(),
		"Wave enemy entry accepted zero interval with positive amount."
	)

	var zero_amount_entry: WaveEnemyEntryDefinition = (
		_create_standard_test_enemy_entry()
	)
	zero_amount_entry.count_increase_interval = 3
	zero_amount_entry.count_increase_amount = 0
	expect(
		not zero_amount_entry.is_valid_definition(),
		"Wave enemy entry accepted positive interval with zero amount."
	)

	var low_maximum_entry: WaveEnemyEntryDefinition = (
		_create_standard_test_enemy_entry()
	)
	low_maximum_entry.maximum_count_per_side = 1
	expect(
		not low_maximum_entry.is_valid_definition(),
		"Wave enemy entry accepted maximum count below base count."
	)

	var zero_health_entry: WaveEnemyEntryDefinition = (
		_create_standard_test_enemy_entry()
	)
	zero_health_entry.health_multiplier = 0.0
	expect(
		not zero_health_entry.is_valid_definition(),
		"Wave enemy entry accepted health multiplier 0."
	)

	var zero_damage_entry: WaveEnemyEntryDefinition = (
		_create_standard_test_enemy_entry()
	)
	zero_damage_entry.damage_multiplier = 0.0
	expect(
		not zero_damage_entry.is_valid_definition(),
		"Wave enemy entry accepted damage multiplier 0."
	)

	print(
		"WAVE ENEMY ENTRY TEST PASS: Stage Wave scaling verified"
	)


func _create_standard_test_enemy_entry() -> WaveEnemyEntryDefinition:
	var entry := WaveEnemyEntryDefinition.new()
	entry.enemy_id = &"bark_beetle"
	entry.base_count_per_side = 2
	entry.count_scaling_start_stage_wave = 1
	entry.count_increase_interval = 3
	entry.count_increase_amount = 1
	entry.maximum_count_per_side = 30
	entry.health_multiplier = 1.0
	entry.damage_multiplier = 1.0
	return entry


func test_guardian_grove_schedule_and_waves() -> void:
	var stage: StageDefinition = (
		GameContent.get_stage(&"guardian_grove")
	)

	expect(
		is_instance_valid(stage),
		"Schedule test could not load Guardian Grove."
	)

	if not is_instance_valid(stage):
		return

	var first_substage: SubstageDefinition = stage.get_substage(0)
	expect(
		is_instance_valid(first_substage),
		"Schedule test could not load Guardian Grove Substage 1."
	)

	if not is_instance_valid(first_substage):
		return

	var schedule: SubstageWaveScheduleDefinition = (
		first_substage.wave_schedule
	)
	expect(
		is_instance_valid(schedule),
		"Guardian Grove standard schedule is missing."
	)

	if not is_instance_valid(schedule):
		return

	expect(
		schedule.is_valid_definition(),
		"Guardian Grove standard schedule is invalid."
	)
	expect(
		schedule.schedule_id == &"guardian_grove_standard",
		"Guardian Grove schedule ID is incorrect."
	)
	expect(
		schedule.display_name == "Guardian Grove Standard Schedule",
		"Guardian Grove schedule display name is incorrect."
	)
	expect(
		schedule.entries.size() == 19,
		"Guardian Grove schedule does not contain exactly 19 entries."
	)
	expect(
		schedule.get_wave_for_number(0) == null,
		"Guardian Grove schedule accepted Wave 0."
	)
	expect(
		schedule.get_wave_for_number(101) == null,
		"Guardian Grove schedule accepted Wave 101."
	)

	var schedule_boundaries: Array[Dictionary] = [
		{"wave": 1, "wave_id": &"standard_bark_beetle"},
		{"wave": 10, "wave_id": &"standard_bark_beetle"},
		{"wave": 11, "wave_id": &"bark_runner_intro"},
		{"wave": 19, "wave_id": &"bark_runner_intro"},
		{"wave": 20, "wave_id": &"bark_beetle_runner_mixed"},
		{"wave": 21, "wave_id": &"standard_bark_beetle"},
		{"wave": 29, "wave_id": &"standard_bark_beetle"},
		{"wave": 30, "wave_id": &"bark_beetle_runner_mixed"},
		{"wave": 31, "wave_id": &"standard_bark_beetle"},
		{"wave": 39, "wave_id": &"standard_bark_beetle"},
		{"wave": 40, "wave_id": &"bark_runner_rush"},
		{"wave": 41, "wave_id": &"standard_bark_beetle"},
		{"wave": 49, "wave_id": &"standard_bark_beetle"},
		{"wave": 50, "wave_id": &"guardian_grove_miniboss"},
		{"wave": 51, "wave_id": &"standard_bark_beetle"},
		{"wave": 59, "wave_id": &"standard_bark_beetle"},
		{"wave": 60, "wave_id": &"bark_runner_rush"},
		{"wave": 61, "wave_id": &"standard_bark_beetle"},
		{"wave": 69, "wave_id": &"standard_bark_beetle"},
		{"wave": 70, "wave_id": &"bark_beetle_runner_mixed"},
		{"wave": 71, "wave_id": &"standard_bark_beetle"},
		{"wave": 79, "wave_id": &"standard_bark_beetle"},
		{"wave": 80, "wave_id": &"bark_runner_rush"},
		{"wave": 81, "wave_id": &"standard_bark_beetle"},
		{"wave": 89, "wave_id": &"standard_bark_beetle"},
		{"wave": 90, "wave_id": &"bark_beetle_runner_mixed"},
		{"wave": 91, "wave_id": &"standard_bark_beetle"},
		{"wave": 99, "wave_id": &"standard_bark_beetle"},
		{"wave": 100, "wave_id": &"guardian_grove_boss"}
	]

	for boundary in schedule_boundaries:
		var wave_number: int = int(boundary["wave"])
		var wave_definition: WaveDefinition = (
			schedule.get_wave_for_number(wave_number)
		)
		expect(
			is_instance_valid(wave_definition),
			"Schedule Wave %d did not resolve a WaveDefinition."
			% wave_number
		)

		if is_instance_valid(wave_definition):
			expect(
				wave_definition.wave_id
				== StringName(boundary["wave_id"]),
				"Schedule Wave %d resolved the wrong Wave ID."
				% wave_number
			)

	for wave_number in range(1, 101):
		expect(
			is_instance_valid(
				schedule.get_wave_for_number(wave_number)
			),
			"Guardian Grove schedule does not cover Wave %d."
			% wave_number
		)

	var standard_wave: WaveDefinition = GameContent.get_wave(
		&"guardian_grove",
		&"standard_bark_beetle"
	)
	var intro_wave: WaveDefinition = GameContent.get_wave(
		&"guardian_grove",
		&"bark_runner_intro"
	)
	var mixed_wave: WaveDefinition = GameContent.get_wave(
		&"guardian_grove",
		&"bark_beetle_runner_mixed"
	)
	var rush_wave: WaveDefinition = GameContent.get_wave(
		&"guardian_grove",
		&"bark_runner_rush"
	)
	var miniboss_wave: WaveDefinition = GameContent.get_wave(
		&"guardian_grove",
		&"guardian_grove_miniboss"
	)
	var boss_wave: WaveDefinition = GameContent.get_wave(
		&"guardian_grove",
		&"guardian_grove_boss"
	)
	var scheduled_waves: Array[WaveDefinition] = [
		standard_wave,
		intro_wave,
		mixed_wave,
		rush_wave,
		miniboss_wave,
		boss_wave
	]

	for wave_definition in scheduled_waves:
		expect(
			is_instance_valid(wave_definition),
			"A Guardian Grove scheduled WaveDefinition is missing."
		)
		if is_instance_valid(wave_definition):
			expect(
				wave_definition.is_valid_definition(),
				"Guardian Grove Wave '%s' is invalid."
				% wave_definition.wave_id
			)

	if (
		not is_instance_valid(standard_wave)
		or not is_instance_valid(intro_wave)
		or not is_instance_valid(mixed_wave)
		or not is_instance_valid(rush_wave)
		or not is_instance_valid(miniboss_wave)
		or not is_instance_valid(boss_wave)
	):
		return

	var unique_waves: Array[WaveDefinition] = (
		schedule.get_unique_wave_definitions()
	)
	expect(
		unique_waves == scheduled_waves,
		"Guardian Grove schedule unique Waves are not in first-use order."
	)

	_expect_wave_identity_and_timing(
		intro_wave,
		&"bark_runner_intro",
		"Bark Runner Introduction",
		0.16,
		0.35,
		0.25
	)
	_expect_wave_entry_data(
		intro_wave,
		0,
		&"bark_runner",
		4,
		11,
		100,
		1,
		10
	)
	_expect_wave_identity_and_timing(
		mixed_wave,
		&"bark_beetle_runner_mixed",
		"Bark Beetle and Bark Runner Mixed Wave",
		0.15,
		0.4,
		0.3
	)
	_expect_wave_entry_data(
		mixed_wave,
		0,
		&"bark_beetle",
		4,
		20,
		30,
		1,
		10
	)
	_expect_wave_entry_data(
		mixed_wave,
		1,
		&"bark_runner",
		2,
		20,
		30,
		1,
		8
	)
	_expect_wave_identity_and_timing(
		rush_wave,
		&"bark_runner_rush",
		"Bark Runner Rush",
		0.12,
		0.4,
		0.3
	)
	_expect_wave_entry_data(
		rush_wave,
		0,
		&"bark_runner",
		6,
		40,
		40,
		1,
		12
	)
	for substage_index in range(10):
		var substage: SubstageDefinition = stage.get_substage(
			substage_index
		)

		if not is_instance_valid(substage):
			continue

		expect(
			substage.wave_schedule == schedule,
			"Guardian Grove Substage %d does not share the schedule."
			% (substage_index + 1)
		)
		expect(
			substage.is_valid_definition(),
			"Guardian Grove Substage %d rejected its schedule."
			% (substage_index + 1)
		)
		expect(
			substage.get_wave_for_index(0) == standard_wave,
			"Substage %d index 0 is not the standard Wave."
			% (substage_index + 1)
		)
		expect(
			substage.get_wave_for_index(10) == intro_wave,
			"Substage %d index 10 is not Runner Intro."
			% (substage_index + 1)
		)
		expect(
			substage.get_wave_for_index(19) == mixed_wave,
			"Substage %d index 19 is not Mixed."
			% (substage_index + 1)
		)
		expect(
			substage.get_wave_for_index(59) == rush_wave,
			"Substage %d index 59 is not Runner Rush."
			% (substage_index + 1)
		)
		expect(
			substage.get_wave_for_index(49) == miniboss_wave,
			"Substage %d index 49 is not the Miniboss."
			% (substage_index + 1)
		)
		expect(
			substage.get_wave_for_index(99) == boss_wave,
			"Substage %d index 99 is not the Boss."
			% (substage_index + 1)
		)

	var standard_counts: Array[Dictionary] = [
		{"wave": 1, "count": 3},
		{"wave": 10, "count": 3},
		{"wave": 11, "count": 4},
		{"wave": 20, "count": 4},
		{"wave": 21, "count": 5},
		{"wave": 30, "count": 5},
		{"wave": 31, "count": 6},
		{"wave": 40, "count": 6},
		{"wave": 41, "count": 7},
		{"wave": 50, "count": 7},
		{"wave": 100, "count": 12}
	]

	for count_fixture in standard_counts:
		var stage_wave: int = int(count_fixture["wave"])
		expect(
			standard_wave.get_enemy_count_for_id(
				&"bark_beetle",
				stage_wave
			) == int(count_fixture["count"]),
			"Standard Wave Stage Wave %d count is incorrect."
			% stage_wave
		)

	var intro_counts: Array[Dictionary] = [
		{"wave": 11, "count": 4},
		{"wave": 19, "count": 4},
		{"wave": 111, "count": 5},
		{"wave": 911, "count": 10}
	]

	for count_fixture in intro_counts:
		var stage_wave: int = int(count_fixture["wave"])
		expect(
			intro_wave.get_enemy_count_for_id(
				&"bark_runner",
				stage_wave
			) == int(count_fixture["count"]),
			"Runner Intro Stage Wave %d count is incorrect."
			% stage_wave
		)

	var mixed_counts: Array[Dictionary] = [
		{"wave": 20, "beetle": 4, "runner": 2},
		{"wave": 30, "beetle": 4, "runner": 2},
		{"wave": 50, "beetle": 5, "runner": 3},
		{"wave": 80, "beetle": 6, "runner": 4}
	]

	for count_fixture in mixed_counts:
		var stage_wave: int = int(count_fixture["wave"])
		expect(
			mixed_wave.get_enemy_count_for_id(
				&"bark_beetle",
				stage_wave
			) == int(count_fixture["beetle"]),
			"Mixed Stage Wave %d Bark Beetle count is incorrect."
			% stage_wave
		)
		expect(
			mixed_wave.get_enemy_count_for_id(
				&"bark_runner",
				stage_wave
			) == int(count_fixture["runner"]),
			"Mixed Stage Wave %d Bark Runner count is incorrect."
			% stage_wave
		)

	var rush_counts: Array[Dictionary] = [
		{"wave": 40, "count": 6},
		{"wave": 60, "count": 6},
		{"wave": 80, "count": 7}
	]

	for count_fixture in rush_counts:
		var stage_wave: int = int(count_fixture["wave"])
		expect(
			rush_wave.get_enemy_count_for_id(
				&"bark_runner",
				stage_wave
			) == int(count_fixture["count"]),
			"Runner Rush Stage Wave %d count is incorrect."
			% stage_wave
		)

	expect(
		miniboss_wave.get_enemy_count_for_id(&"bark_warden", 999) == 1,
		"Miniboss count changed with later Stage Waves."
	)
	expect(
		boss_wave.get_enemy_count_for_id(&"ancient_bark_colossus", 999) == 1,
		"Boss count changed with later Stage Waves."
	)

	var total_health_fixtures: Array[Dictionary] = [
		{"wave": 2, "health": 36.54},
		{"wave": 20, "health": 79.67},
		{"wave": 21, "health": 78.0},
		{"wave": 29, "health": 85.2},
		{"wave": 30, "health": 88.97},
		{"wave": 49, "health": 144.48},
		{"wave": 50, "health": 208.2}
	]

	for health_fixture in total_health_fixtures:
		var stage_wave: int = int(health_fixture["wave"])
		expect(
			is_equal_approx(
				_get_total_enemy_health_per_side(
					stage,
					stage_wave
				),
				float(health_fixture["health"])
			),
			"Stage Wave %d total health per side is incorrect."
			% stage_wave
		)

	expect(
		is_equal_approx(
			_get_total_enemy_health_per_side(stage, 2) * 2.0,
			73.08
		),
		"Stage Wave 2 total health across both sides is incorrect."
	)

	var enemies_per_side_waves_1_to_50: int = 0

	for stage_wave in range(1, 51):
		var scheduled_wave: WaveDefinition = (
			stage.get_wave_for_stage_index(stage_wave - 1)
		)

		if is_instance_valid(scheduled_wave):
			enemies_per_side_waves_1_to_50 += (
				scheduled_wave.get_total_enemies_per_side(stage_wave)
			)

	expect(
		enemies_per_side_waves_1_to_50 == 247,
		"Waves 1-50 do not spawn 247 enemies per side."
	)

	print(
		"SUBSTAGE SCHEDULE TEST PASS: entries=19, coverage=1-100"
	)
	print(
		"PRODUCTION WAVE DATA TEST PASS: scheduled_waves=6, ordered mixed entries"
	)
	print(
		"EARLY BALANCE TEST PASS: counts, continuity, total_spawned_1_50=494"
	)


func _get_total_enemy_health_per_side(
	stage: StageDefinition,
	stage_wave: int
) -> float:
	var wave_definition: WaveDefinition = (
		stage.get_wave_for_stage_index(stage_wave - 1)
	)

	if not is_instance_valid(wave_definition):
		return 0.0

	var total_health: float = 0.0

	for enemy_id in wave_definition.get_enemy_ids():
		var enemy_definition: EnemyDefinition = (
			GameContent.get_enemy(enemy_id)
		)

		if not is_instance_valid(enemy_definition):
			continue

		total_health += (
			stage.get_enemy_count_for_stage_wave(
				wave_definition,
				enemy_id,
				stage_wave
			)
			* stage.get_enemy_health_for_stage_wave(
				wave_definition,
				enemy_definition,
				stage_wave
			)
		)

	return total_health


func _expect_wave_identity_and_timing(
	wave_definition: WaveDefinition,
	expected_id: StringName,
	expected_name: String,
	expected_spawn_interval: float,
	expected_completion_duration: float,
	expected_time_after_wave: float
) -> void:
	expect(
		wave_definition.wave_id == expected_id,
		"Wave '%s' has the wrong ID." % expected_name
	)
	expect(
		wave_definition.display_name == expected_name,
		"Wave '%s' has the wrong display name." % expected_id
	)
	expect(
		is_equal_approx(
			wave_definition.spawn_interval,
			expected_spawn_interval
		),
		"Wave '%s' has the wrong spawn interval." % expected_id
	)
	expect(
		is_equal_approx(
			wave_definition.completion_message_duration,
			expected_completion_duration
		),
		"Wave '%s' has the wrong completion duration." % expected_id
	)
	expect(
		is_equal_approx(
			wave_definition.time_after_wave,
			expected_time_after_wave
		),
		"Wave '%s' has the wrong time after Wave." % expected_id
	)


func _expect_wave_entry_data(
	wave_definition: WaveDefinition,
	entry_index: int,
	expected_enemy_id: StringName,
	expected_base_count: int,
	expected_scaling_start: int,
	expected_interval: int,
	expected_amount: int,
	expected_maximum: int
) -> void:
	expect(
		entry_index >= 0
		and entry_index < wave_definition.enemy_entries.size(),
		"Wave '%s' is missing enemy entry %d."
		% [wave_definition.wave_id, entry_index]
	)

	if (
		entry_index < 0
		or entry_index >= wave_definition.enemy_entries.size()
	):
		return

	var entry: WaveEnemyEntryDefinition = (
		wave_definition.enemy_entries[entry_index]
	)
	expect(
		is_instance_valid(entry),
		"Wave '%s' enemy entry %d is null."
		% [wave_definition.wave_id, entry_index]
	)

	if not is_instance_valid(entry):
		return

	expect(
		entry.enemy_id == expected_enemy_id,
		"Wave '%s' enemy entry %d has the wrong ID."
		% [wave_definition.wave_id, entry_index]
	)
	expect(
		entry.base_count_per_side == expected_base_count,
		"Wave '%s' enemy entry %d has the wrong base count."
		% [wave_definition.wave_id, entry_index]
	)
	expect(
		entry.count_scaling_start_stage_wave == expected_scaling_start,
		"Wave '%s' enemy entry %d has the wrong scaling start."
		% [wave_definition.wave_id, entry_index]
	)
	expect(
		entry.count_increase_interval == expected_interval,
		"Wave '%s' enemy entry %d has the wrong interval."
		% [wave_definition.wave_id, entry_index]
	)
	expect(
		entry.count_increase_amount == expected_amount,
		"Wave '%s' enemy entry %d has the wrong increase amount."
		% [wave_definition.wave_id, entry_index]
	)
	expect(
		entry.maximum_count_per_side == expected_maximum,
		"Wave '%s' enemy entry %d has the wrong maximum."
		% [wave_definition.wave_id, entry_index]
	)
	expect(
		is_equal_approx(entry.health_multiplier, 1.0),
		"Wave '%s' enemy entry %d health multiplier is not 1.0."
		% [wave_definition.wave_id, entry_index]
	)
	expect(
		is_equal_approx(entry.damage_multiplier, 1.0),
		"Wave '%s' enemy entry %d damage multiplier is not 1.0."
		% [wave_definition.wave_id, entry_index]
	)


func test_stage_and_wave_definition() -> void:
	var stage: StageDefinition = (
		GameContent.get_stage(&"guardian_grove")
	)

	expect(
		is_instance_valid(stage),
		"Guardian Grove StageDefinition was not found."
	)
	expect(
		GameContent.get_stage(&"missing_stage") == null,
		"Missing Stage lookup did not return null."
	)

	if not is_instance_valid(stage):
		return

	expect(
		stage.is_valid_definition(),
		"Guardian Grove StageDefinition is invalid."
	)
	expect(
		stage.stage_id == &"guardian_grove",
		"Guardian Grove Stage ID is incorrect."
	)
	expect(
		stage.get_substage_count() == 10,
		"Guardian Grove does not contain 10 Substages."
	)
	expect(
		stage.get_required_substage_count() == 10,
		"Guardian Grove does not require 10 Substages."
	)
	expect(
		stage.get_waves_per_substage() == 100,
		"Guardian Grove does not expose 100 Waves per Substage."
	)
	expect(
		stage.get_total_wave_count() == 1000,
		"Guardian Grove does not expose 1000 total Waves."
	)
	expect(
		stage.get_wave_count() == 1000,
		"Guardian Grove compatibility Wave count is not 1000."
	)
	expect(
		stage.repeat_indefinitely,
		"Guardian Grove is not configured to repeat indefinitely."
	)
	expect(
		is_equal_approx(stage.health_growth_per_stage_wave, 0.015),
		"Guardian Grove health growth per Stage Wave is not 0.015."
	)
	expect(
		is_equal_approx(stage.damage_growth_per_stage_wave, 0.003),
		"Guardian Grove damage growth per Stage Wave is not 0.003."
	)
	expect(
		is_equal_approx(stage.maximum_enemy_health, 1000000.0),
		"Guardian Grove maximum enemy health is not 1000000.0."
	)

	stage.health_growth_per_stage_wave = -0.01
	expect(
		not stage.is_valid_definition(),
		"StageDefinition accepted negative health growth."
	)
	stage.health_growth_per_stage_wave = 0.015

	stage.damage_growth_per_stage_wave = -0.01
	expect(
		not stage.is_valid_definition(),
		"StageDefinition accepted negative damage growth."
	)
	stage.damage_growth_per_stage_wave = 0.003
	expect(
		stage.is_valid_definition(),
		"Guardian Grove remained invalid after restoring growth values."
	)

	var standard_wave: WaveDefinition = (
		stage.get_wave_for_stage_index(0)
	)

	expect(
		is_instance_valid(standard_wave),
		"Guardian Grove first Wave template is missing."
	)

	if not is_instance_valid(standard_wave):
		return

	for substage_index in range(10):
		var substage: SubstageDefinition = (
			stage.get_substage(substage_index)
		)
		var expected_substage_id: StringName = StringName(
			"guardian_grove_substage_%02d"
			% (substage_index + 1)
		)

		expect(
			is_instance_valid(substage),
			"Guardian Grove Substage %d is missing."
			% (substage_index + 1)
		)

		if not is_instance_valid(substage):
			continue

		expect(
			substage.is_valid_definition(),
			"Guardian Grove Substage %d is invalid."
			% (substage_index + 1)
		)
		expect(
			substage.substage_id == expected_substage_id,
			"Guardian Grove Substage %d has the wrong ID."
			% (substage_index + 1)
		)
		expect(
			substage.get_wave_count() == 100,
			"Guardian Grove Substage %d does not expose 100 Waves."
			% (substage_index + 1)
		)
		expect(
			substage.get_wave_pattern_count() == 19,
			"Guardian Grove Substage %d does not have 19 schedule entries."
			% (substage_index + 1)
		)
		expect(
			substage.get_wave_for_index(0) == standard_wave,
			"Guardian Grove Substage %d does not share the standard Wave."
			% (substage_index + 1)
		)

	var stage_wave_indexes: Array[int] = [
		0,
		99,
		100,
		187,
		246,
		999
	]
	var expected_substage_indexes: Array[int] = [
		0,
		0,
		1,
		1,
		2,
		9
	]
	var expected_wave_indexes: Array[int] = [
		0,
		99,
		0,
		87,
		46,
		99
	]
	var expected_wave_ids: Array[StringName] = [
		&"standard_bark_beetle",
		&"guardian_grove_boss",
		&"standard_bark_beetle",
		&"standard_bark_beetle",
		&"standard_bark_beetle",
		&"guardian_grove_boss"
	]

	for mapping_index in range(stage_wave_indexes.size()):
		var stage_wave_index: int = stage_wave_indexes[
			mapping_index
		]

		expect(
			stage.get_substage_index_for_stage_wave(
				stage_wave_index
			) == expected_substage_indexes[mapping_index],
			"Stage Wave index %d resolved to the wrong Substage."
			% stage_wave_index
		)
		expect(
			stage.get_wave_index_in_substage_for_stage_wave(
				stage_wave_index
			) == expected_wave_indexes[mapping_index],
			"Stage Wave index %d resolved to the wrong Substage Wave."
			% stage_wave_index
		)
		var mapped_wave: WaveDefinition = (
			stage.get_wave_for_stage_index(stage_wave_index)
		)
		expect(
			is_instance_valid(mapped_wave)
			and mapped_wave.wave_id == expected_wave_ids[mapping_index],
			"Stage Wave index %d resolved the wrong scheduled Wave."
			% stage_wave_index
		)

	expect(
		stage.get_substage_index_for_stage_wave(-1) == -1,
		"Guardian Grove accepted negative Stage Wave mapping."
	)
	expect(
		stage.get_substage_index_for_stage_wave(1000) == -1,
		"Guardian Grove accepted Stage Wave mapping 1000."
	)
	expect(
		stage.get_wave_index_in_substage_for_stage_wave(-1) == -1,
		"Guardian Grove accepted negative Substage Wave mapping."
	)
	expect(
		stage.get_wave_index_in_substage_for_stage_wave(1000) == -1,
		"Guardian Grove accepted Substage Wave mapping 1000."
	)
	expect(
		stage.get_substage_start_wave_index(0) == 0,
		"Substage 1 does not start at Stage Wave index 0."
	)
	expect(
		stage.get_substage_start_wave_index(1) == 100,
		"Substage 2 does not start at Stage Wave index 100."
	)
	expect(
		stage.get_substage_start_wave_index(9) == 900,
		"Substage 10 does not start at Stage Wave index 900."
	)
	expect(
		stage.get_substage_start_wave_index(-1) == -1,
		"Guardian Grove accepted a negative Substage start index."
	)
	expect(
		stage.get_substage_start_wave_index(10) == -1,
		"Guardian Grove accepted Substage start index 10."
	)
	expect(
		stage.get_wave_for_stage_index(-1) == null,
		"Guardian Grove accepted a negative Wave index."
	)
	expect(
		stage.get_wave_for_stage_index(1000) == null,
		"Guardian Grove accepted Wave index 1000."
	)

	var unique_waves: Array[WaveDefinition] = (
		stage.get_unique_wave_definitions()
	)
	expect(
		unique_waves.size() == 6,
		"Guardian Grove does not expose six unique WaveDefinitions."
	)
	if unique_waves.size() == 6:
		expect(
			unique_waves[0] == standard_wave,
			"Guardian Grove unique Wave list does not start with standard."
		)
		expect(
			unique_waves[1].wave_id == &"bark_runner_intro"
			and unique_waves[2].wave_id == &"bark_beetle_runner_mixed"
			and unique_waves[3].wave_id == &"bark_runner_rush"
			and unique_waves[4].wave_id == &"guardian_grove_miniboss"
			and unique_waves[5].wave_id == &"guardian_grove_boss",
			"Guardian Grove unique Wave list has the wrong first-use order."
		)

	expect(
		standard_wave.wave_id == &"standard_bark_beetle",
		"Standard Bark Beetle Wave ID is incorrect."
	)
	expect(
		standard_wave.is_valid_definition(),
		"Standard Bark Beetle WaveDefinition is invalid."
	)
	var enemy_ids: Array[StringName] = standard_wave.get_enemy_ids()
	expect(
		standard_wave.enemy_entries.size() == 1,
		"Standard Wave does not contain exactly one enemy entry."
	)
	expect(
		enemy_ids.size() == 1
		and enemy_ids[0] == &"bark_beetle",
		"Standard Wave enemy ID order is not Bark Beetle."
	)

	var bark_beetle_entry: WaveEnemyEntryDefinition = (
		standard_wave.get_enemy_entry(&"bark_beetle")
	)
	expect(
		is_instance_valid(bark_beetle_entry),
		"Standard Wave Bark Beetle entry is missing."
	)

	if is_instance_valid(bark_beetle_entry):
		expect(
			bark_beetle_entry.enemy_id == &"bark_beetle",
			"Standard Wave entry has the wrong enemy ID."
		)
		expect(
			bark_beetle_entry.base_count_per_side == 3,
			"Standard Wave entry base count is not 3."
		)
		expect(
			bark_beetle_entry.count_scaling_start_stage_wave == 1,
			"Standard Wave entry scaling start is not 1."
		)
		expect(
			bark_beetle_entry.count_increase_interval == 10,
			"Standard Wave entry count interval is not 10."
		)
		expect(
			bark_beetle_entry.count_increase_amount == 1,
			"Standard Wave entry count amount is not 1."
		)
		expect(
			bark_beetle_entry.maximum_count_per_side == 12,
			"Standard Wave entry maximum count is not 12."
		)
		expect(
			is_equal_approx(
				bark_beetle_entry.health_multiplier,
				1.0
			),
			"Standard Wave entry health multiplier is not 1.0."
		)
		expect(
			is_equal_approx(
				bark_beetle_entry.damage_multiplier,
				1.0
			),
			"Standard Wave entry damage multiplier is not 1.0."
		)

	expect(
		standard_wave.get_enemy_count_for_id(
			&"bark_beetle",
			1
		) == 3,
		"Standard Wave Stage Wave 1 count is not 3."
	)
	expect(
		standard_wave.get_enemy_count_for_id(
			&"bark_beetle",
			10
		) == 3,
		"Standard Wave Stage Wave 10 count is not 3."
	)
	expect(
		standard_wave.get_enemy_count_for_id(
			&"bark_beetle",
			11
		) == 4,
		"Standard Wave Stage Wave 11 count is not 4."
	)
	expect(
		standard_wave.get_enemy_count_for_id(
			&"bark_beetle",
			100
		) == 12,
		"Standard Wave Stage Wave 100 count is not 12."
	)
	expect(
		standard_wave.get_enemy_count_for_id(
			&"missing_enemy",
			1
		) == 0,
		"Standard Wave unknown enemy count is not 0."
	)
	expect(
		standard_wave.get_total_enemies_per_side(1) == 3,
		"Standard Wave Stage Wave 1 total count is not 3."
	)
	expect(
		standard_wave.get_total_enemies_per_side(11) == 4,
		"Standard Wave Stage Wave 11 total count is not 4."
	)
	expect(
		standard_wave.get_total_enemies_per_side(100) == 12,
		"Standard Wave Stage Wave 100 total count is not 12."
	)
	expect(
		is_equal_approx(
			standard_wave.spawn_interval,
			0.18
		),
		"Standard Wave spawn interval is not 0.18."
	)
	expect(
		is_equal_approx(
			standard_wave.get_health_multiplier_for_id(
				&"bark_beetle"
			),
			1.0
		),
		"Standard Wave Bark Beetle health multiplier is not 1.0."
	)
	expect(
		is_equal_approx(
			standard_wave.get_damage_multiplier_for_id(
				&"bark_beetle"
			),
			1.0
		),
		"Standard Wave Bark Beetle damage multiplier is not 1.0."
	)
	expect(
		is_equal_approx(
			standard_wave.get_health_multiplier_for_id(
				&"missing_enemy"
			),
			1.0
		),
		"Standard Wave unknown health multiplier fallback is not 1.0."
	)
	expect(
		is_equal_approx(
			standard_wave.get_damage_multiplier_for_id(
				&"missing_enemy"
			),
			1.0
		),
		"Standard Wave unknown damage multiplier fallback is not 1.0."
	)
	expect(
		is_equal_approx(
			standard_wave.completion_message_duration,
			0.35
		),
		"Standard Wave completion message duration is not 0.35."
	)
	expect(
		is_equal_approx(
			standard_wave.time_after_wave,
			0.25
		),
		"Standard Wave time after Wave is not 0.25."
	)

	var bark_beetle_definition: EnemyDefinition = (
		GameContent.get_enemy(&"bark_beetle")
	)
	var bark_runner_definition: EnemyDefinition = (
		GameContent.get_enemy(&"bark_runner")
	)
	var intro_wave: WaveDefinition = GameContent.get_wave(
		&"guardian_grove",
		&"bark_runner_intro"
	)
	expect(
		is_instance_valid(bark_beetle_definition),
		"Stage test could not load Bark Beetle EnemyDefinition."
	)
	expect(
		is_instance_valid(bark_runner_definition),
		"Stage test could not load Bark Runner EnemyDefinition."
	)
	expect(
		is_instance_valid(intro_wave),
		"Stage test could not load Bark Runner Intro Wave."
	)

	if (
		is_instance_valid(bark_beetle_definition)
		and is_instance_valid(bark_runner_definition)
		and is_instance_valid(intro_wave)
	):
		var scaling_fixtures: Array[Dictionary] = [
			{
				"wave": 1,
				"beetle_health": 12.0,
				"runner_health": 7.0,
				"damage_multiplier": 1.0,
				"beetle_damage": 1.5,
				"runner_damage": 0.75
			},
			{
				"wave": 2,
				"beetle_health": 12.18,
				"runner_health": 7.105,
				"damage_multiplier": 1.003,
				"beetle_damage": 1.5045,
				"runner_damage": 0.75225
			},
			{
				"wave": 20,
				"beetle_health": 15.42,
				"runner_health": 8.995,
				"damage_multiplier": 1.057,
				"beetle_damage": 1.5855,
				"runner_damage": 0.79275
			},
			{
				"wave": 21,
				"beetle_health": 15.6,
				"runner_health": 9.1,
				"damage_multiplier": 1.06,
				"beetle_damage": 1.59,
				"runner_damage": 0.795
			},
			{
				"wave": 31,
				"beetle_health": 17.4,
				"runner_health": 10.15,
				"damage_multiplier": 1.09,
				"beetle_damage": 1.635,
				"runner_damage": 0.8175
			},
			{
				"wave": 40,
				"beetle_health": 19.02,
				"runner_health": 11.095,
				"damage_multiplier": 1.117,
				"beetle_damage": 1.6755,
				"runner_damage": 0.83775
			},
			{
				"wave": 50,
				"beetle_health": 20.82,
				"runner_health": 12.145,
				"damage_multiplier": 1.147,
				"beetle_damage": 1.7205,
				"runner_damage": 0.86025
			},
			{
				"wave": 100,
				"beetle_health": 29.82,
				"runner_health": 17.395,
				"damage_multiplier": 1.297,
				"beetle_damage": 1.9455,
				"runner_damage": 0.97275
			}
		]

		for scaling_fixture in scaling_fixtures:
			var stage_wave: int = int(scaling_fixture["wave"])
			var beetle_health: float = (
				stage.get_enemy_health_for_stage_wave(
					standard_wave,
					bark_beetle_definition,
					stage_wave
				)
			)
			var runner_health: float = (
				stage.get_enemy_health_for_stage_wave(
					intro_wave,
					bark_runner_definition,
					stage_wave
				)
			)
			var beetle_damage_multiplier: float = (
				stage.get_enemy_damage_multiplier(
					standard_wave,
					&"bark_beetle",
					stage_wave
				)
			)
			var runner_damage_multiplier: float = (
				stage.get_enemy_damage_multiplier(
					intro_wave,
					&"bark_runner",
					stage_wave
				)
			)

			expect(
				is_equal_approx(
					beetle_health,
					float(scaling_fixture["beetle_health"])
				),
				"Stage Wave %d Bark Beetle health is incorrect."
				% stage_wave
			)
			expect(
				is_equal_approx(
					runner_health,
					float(scaling_fixture["runner_health"])
				),
				"Stage Wave %d Bark Runner health is incorrect."
				% stage_wave
			)
			expect(
				is_equal_approx(
					beetle_damage_multiplier,
					float(scaling_fixture["damage_multiplier"])
				),
				"Stage Wave %d Bark Beetle damage multiplier is incorrect."
				% stage_wave
			)
			expect(
				is_equal_approx(
					runner_damage_multiplier,
					float(scaling_fixture["damage_multiplier"])
				),
				"Stage Wave %d Bark Runner damage multiplier is incorrect."
				% stage_wave
			)
			expect(
				is_equal_approx(
					bark_beetle_definition.attack_damage
					* beetle_damage_multiplier,
					float(scaling_fixture["beetle_damage"])
				),
				"Stage Wave %d Bark Beetle applied damage is incorrect."
				% stage_wave
			)
			expect(
				is_equal_approx(
					bark_runner_definition.attack_damage
					* runner_damage_multiplier,
					float(scaling_fixture["runner_damage"])
				),
				"Stage Wave %d Bark Runner applied damage is incorrect."
				% stage_wave
			)
			expect(
				is_equal_approx(
					runner_health / beetle_health,
					7.0 / 12.0
				),
				"Stage Wave %d did not preserve the Runner HP ratio."
				% stage_wave
			)

		var wave_31_beetles_per_side: int = (
			stage.get_enemy_count_for_stage_wave(
				standard_wave,
				&"bark_beetle",
				31
			)
		)
		var wave_31_total_beetles: int = (
			wave_31_beetles_per_side * 2
		)
		var wave_31_applied_damage: float = (
			bark_beetle_definition.attack_damage
			* stage.get_enemy_damage_multiplier(
				standard_wave,
				&"bark_beetle",
				31
			)
		)
		var wave_31_theoretical_dps: float = (
			wave_31_applied_damage
			/ bark_beetle_definition.attack_interval
			* wave_31_total_beetles
		)
		var previous_wave_31_applied_damage: float = (
			2.0 * (1.0 + 0.005 * 30.0)
		)
		var previous_wave_31_theoretical_dps: float = (
			previous_wave_31_applied_damage
			/ 1.5
			* wave_31_total_beetles
		)
		var wave_31_dps_reduction: float = (
			1.0
			- wave_31_theoretical_dps
			/ previous_wave_31_theoretical_dps
		)

		expect(
			wave_31_beetles_per_side == 6
			and wave_31_total_beetles == 12,
			"Stage Wave 31 does not contain 6 Beetles per side."
		)
		expect(
			is_equal_approx(wave_31_applied_damage, 1.635),
			"Stage Wave 31 Bark Beetle applied damage is not 1.635."
		)
		expect(
			is_equal_approx(wave_31_theoretical_dps, 13.08),
			"Stage Wave 31 theoretical Beetle DPS is not 13.08."
		)
		expect(
			is_equal_approx(
				previous_wave_31_theoretical_dps,
				18.4
			),
			"Previous Stage Wave 31 theoretical DPS is not 18.4."
		)
		expect(
			is_equal_approx(
				wave_31_dps_reduction,
				0.2891304348
			),
			"Stage Wave 31 DPS reduction is not approximately 28.9%."
		)

		print(
			"WAVE 31 DPS DIAGNOSTIC TEST PASS: "
			+ "previous=18.40, current=13.08, reduction=28.9%"
		)

	expect(
		is_equal_approx(
			stage.get_enemy_damage_multiplier(
				standard_wave,
				&"missing_enemy",
				100
			),
			1.0
		),
		"Stage unknown enemy damage fallback is not 1.0."
	)

	var indexed_wave: WaveDefinition = GameContent.get_wave(
		&"guardian_grove",
		&"standard_bark_beetle"
	)
	expect(
		indexed_wave == standard_wave,
		"Scoped Guardian Grove Wave lookup returned the wrong Resource."
	)

	print(
		"STAGE/SUBSTAGE MAPPING TEST PASS: "
		+ "substages=10, waves_per_substage=100, total_waves=1000"
	)
	print(
		"STAGE PERCENT SCALING TEST PASS: HP and damage Waves 1-100"
	)


func test_wave_definition_multi_entry_data() -> void:
	var bark_beetle_entry: WaveEnemyEntryDefinition = (
		_create_standard_test_enemy_entry()
	)
	var runner_entry := WaveEnemyEntryDefinition.new()
	runner_entry.enemy_id = &"test_runner"
	runner_entry.base_count_per_side = 1
	runner_entry.count_scaling_start_stage_wave = 1
	runner_entry.count_increase_interval = 0
	runner_entry.count_increase_amount = 0
	runner_entry.maximum_count_per_side = 1
	runner_entry.health_multiplier = 0.5
	runner_entry.damage_multiplier = 1.25

	var multi_entry_wave := WaveDefinition.new()
	multi_entry_wave.wave_id = &"test_multi_entry_wave"
	multi_entry_wave.display_name = "Test Multi-entry Wave"
	var ordered_entries: Array[WaveEnemyEntryDefinition] = [
		bark_beetle_entry,
		runner_entry
	]
	multi_entry_wave.enemy_entries = ordered_entries

	expect(
		multi_entry_wave.is_valid_definition(),
		"Valid in-memory multi-entry WaveDefinition was rejected."
	)

	var ordered_enemy_ids: Array[StringName] = (
		multi_entry_wave.get_enemy_ids()
	)
	expect(
		ordered_enemy_ids.size() == 2
		and ordered_enemy_ids[0] == &"bark_beetle"
		and ordered_enemy_ids[1] == &"test_runner",
		"Multi-entry Wave did not preserve enemy block order."
	)
	expect(
		multi_entry_wave.get_enemy_count_for_id(
			&"bark_beetle",
			4
		) == 3,
		"Multi-entry Wave Bark Beetle count is not independent."
	)
	expect(
		multi_entry_wave.get_enemy_count_for_id(
			&"test_runner",
			4
		) == 1,
		"Multi-entry Wave test runner count is not fixed at 1."
	)
	expect(
		multi_entry_wave.get_total_enemies_per_side(4) == 4,
		"Multi-entry Wave total count is not 4."
	)
	expect(
		is_equal_approx(
			multi_entry_wave.get_health_multiplier_for_id(
				&"bark_beetle"
			),
			1.0
		),
		"Multi-entry Wave Bark Beetle health multiplier changed."
	)
	expect(
		is_equal_approx(
			multi_entry_wave.get_health_multiplier_for_id(
				&"test_runner"
			),
			0.5
		),
		"Multi-entry Wave test runner health multiplier is not 0.5."
	)
	expect(
		is_equal_approx(
			multi_entry_wave.get_damage_multiplier_for_id(
				&"bark_beetle"
			),
			1.0
		),
		"Multi-entry Wave Bark Beetle damage multiplier changed."
	)
	expect(
		is_equal_approx(
			multi_entry_wave.get_damage_multiplier_for_id(
				&"test_runner"
			),
			1.25
		),
		"Multi-entry Wave test runner damage multiplier is not 1.25."
	)

	runner_entry.health_multiplier = 0.75
	expect(
		is_equal_approx(
			bark_beetle_entry.health_multiplier,
			1.0
		),
		"Mutating one Wave enemy entry changed another entry."
	)

	var duplicate_entry: WaveEnemyEntryDefinition = (
		_create_standard_test_enemy_entry()
	)
	var duplicate_wave := WaveDefinition.new()
	duplicate_wave.wave_id = &"test_duplicate_entry_wave"
	duplicate_wave.display_name = "Test Duplicate Entry Wave"
	var duplicate_entries: Array[WaveEnemyEntryDefinition] = [
		bark_beetle_entry,
		duplicate_entry
	]
	duplicate_wave.enemy_entries = duplicate_entries
	expect(
		not duplicate_wave.is_valid_definition(),
		"WaveDefinition accepted duplicate enemy IDs."
	)

	var null_entry_wave := WaveDefinition.new()
	null_entry_wave.wave_id = &"test_null_entry_wave"
	null_entry_wave.display_name = "Test Null Entry Wave"
	var null_entries: Array[WaveEnemyEntryDefinition] = [
		bark_beetle_entry,
		null
	]
	null_entry_wave.enemy_entries = null_entries
	expect(
		not null_entry_wave.is_valid_definition(),
		"WaveDefinition accepted a null enemy entry."
	)

	print(
		"MULTI-ENTRY WAVE DATA TEST PASS: ordered entries=2"
	)


func test_substage_definition_validation() -> void:
	var standard_wave: WaveDefinition = GameContent.get_wave(
		&"guardian_grove",
		&"standard_bark_beetle"
	)

	expect(
		is_instance_valid(standard_wave),
		"Substage validation test could not load the standard Wave."
	)

	if not is_instance_valid(standard_wave):
		return

	var valid_substage: SubstageDefinition = (
		_create_test_substage(standard_wave)
	)
	expect(
		valid_substage.is_valid_definition(),
		"Valid in-memory SubstageDefinition was rejected."
	)

	var empty_id_substage: SubstageDefinition = (
		_create_test_substage(standard_wave)
	)
	empty_id_substage.substage_id = &""
	expect(
		not empty_id_substage.is_valid_definition(),
		"SubstageDefinition accepted an empty ID."
	)

	var empty_name_substage: SubstageDefinition = (
		_create_test_substage(standard_wave)
	)
	empty_name_substage.display_name = "   "
	expect(
		not empty_name_substage.is_valid_definition(),
		"SubstageDefinition accepted an empty display name."
	)

	var null_schedule_substage: SubstageDefinition = (
		_create_test_substage(standard_wave)
	)
	null_schedule_substage.wave_schedule = null
	expect(
		not null_schedule_substage.is_valid_definition(),
		"SubstageDefinition accepted a null Wave schedule."
	)

	var empty_schedule_id: SubstageWaveScheduleDefinition = (
		_create_test_wave_schedule(standard_wave)
	)
	empty_schedule_id.schedule_id = &""
	expect(
		not empty_schedule_id.is_valid_definition(),
		"Wave schedule accepted an empty ID."
	)

	var empty_schedule_name: SubstageWaveScheduleDefinition = (
		_create_test_wave_schedule(standard_wave)
	)
	empty_schedule_name.display_name = "   "
	expect(
		not empty_schedule_name.is_valid_definition(),
		"Wave schedule accepted an empty display name."
	)

	var empty_schedule: SubstageWaveScheduleDefinition = (
		_create_test_wave_schedule(standard_wave)
	)
	empty_schedule.entries = []
	expect(
		not empty_schedule.is_valid_definition(),
		"Wave schedule accepted empty entries."
	)

	var null_entry_schedule: SubstageWaveScheduleDefinition = (
		_create_test_wave_schedule(standard_wave)
	)
	var null_schedule_entries: Array[SubstageWaveScheduleEntryDefinition] = [
		null
	]
	null_entry_schedule.entries = null_schedule_entries
	expect(
		not null_entry_schedule.is_valid_definition(),
		"Wave schedule accepted a null entry."
	)

	var invalid_start_schedule: SubstageWaveScheduleDefinition = (
		_create_test_wave_schedule(standard_wave)
	)
	invalid_start_schedule.entries[0].start_wave = 0
	expect(
		not invalid_start_schedule.is_valid_definition(),
		"Wave schedule accepted start Wave 0."
	)

	var invalid_end_schedule: SubstageWaveScheduleDefinition = (
		_create_test_wave_schedule(standard_wave)
	)
	invalid_end_schedule.entries[0].end_wave = 101
	expect(
		not invalid_end_schedule.is_valid_definition(),
		"Wave schedule accepted end Wave 101."
	)

	var reversed_range_schedule: SubstageWaveScheduleDefinition = (
		_create_test_wave_schedule(standard_wave)
	)
	reversed_range_schedule.entries[0].start_wave = 60
	reversed_range_schedule.entries[0].end_wave = 40
	expect(
		not reversed_range_schedule.is_valid_definition(),
		"Wave schedule accepted a reversed range."
	)

	var null_wave_schedule: SubstageWaveScheduleDefinition = (
		_create_test_wave_schedule(standard_wave)
	)
	null_wave_schedule.entries[0].wave_definition = null
	expect(
		not null_wave_schedule.is_valid_definition(),
		"Wave schedule accepted an entry without a WaveDefinition."
	)

	var gap_schedule: SubstageWaveScheduleDefinition = (
		_create_test_wave_schedule(standard_wave)
	)
	gap_schedule.entries = [
		_create_schedule_entry(1, 49, standard_wave),
		_create_schedule_entry(51, 100, standard_wave)
	]
	expect(
		not gap_schedule.is_valid_definition(),
		"Wave schedule accepted a coverage gap."
	)

	var overlap_schedule: SubstageWaveScheduleDefinition = (
		_create_test_wave_schedule(standard_wave)
	)
	overlap_schedule.entries = [
		_create_schedule_entry(1, 60, standard_wave),
		_create_schedule_entry(60, 100, standard_wave)
	]
	expect(
		not overlap_schedule.is_valid_definition(),
		"Wave schedule accepted overlapping ranges."
	)

	var out_of_order_schedule: SubstageWaveScheduleDefinition = (
		_create_test_wave_schedule(standard_wave)
	)
	out_of_order_schedule.entries = [
		_create_schedule_entry(51, 100, standard_wave),
		_create_schedule_entry(1, 50, standard_wave)
	]
	expect(
		not out_of_order_schedule.is_valid_definition(),
		"Wave schedule accepted entries out of order."
	)

	var late_start_schedule: SubstageWaveScheduleDefinition = (
		_create_test_wave_schedule(standard_wave)
	)
	late_start_schedule.entries = [
		_create_schedule_entry(2, 100, standard_wave)
	]
	expect(
		not late_start_schedule.is_valid_definition(),
		"Wave schedule accepted a first range starting after Wave 1."
	)

	var early_end_schedule: SubstageWaveScheduleDefinition = (
		_create_test_wave_schedule(standard_wave)
	)
	early_end_schedule.entries = [
		_create_schedule_entry(1, 99, standard_wave)
	]
	expect(
		not early_end_schedule.is_valid_definition(),
		"Wave schedule accepted a final range ending before Wave 100."
	)

	var negative_reward_substage: SubstageDefinition = (
		_create_test_substage(standard_wave)
	)
	negative_reward_substage.completion_essence_reward = -1
	expect(
		not negative_reward_substage.is_valid_definition(),
		"SubstageDefinition accepted a negative completion reward."
	)

	var empty_effect_substage: SubstageDefinition = (
		_create_test_substage(standard_wave)
	)
	var empty_effect_ids: Array[StringName] = [&""]
	empty_effect_substage.completion_effect_ids = empty_effect_ids
	expect(
		not empty_effect_substage.is_valid_definition(),
		"SubstageDefinition accepted an empty completion effect ID."
	)

	var duplicate_effect_substage: SubstageDefinition = (
		_create_test_substage(standard_wave)
	)
	var duplicate_effect_ids: Array[StringName] = [
		&"test_effect",
		&"test_effect"
	]
	duplicate_effect_substage.completion_effect_ids = (
		duplicate_effect_ids
	)
	expect(
		not duplicate_effect_substage.is_valid_definition(),
		"SubstageDefinition accepted duplicate completion effect IDs."
	)

	var repeated_wave_schedule: SubstageWaveScheduleDefinition = (
		_create_test_wave_schedule(standard_wave)
	)
	repeated_wave_schedule.entries = [
		_create_schedule_entry(1, 20, standard_wave),
		_create_schedule_entry(21, 40, standard_wave),
		_create_schedule_entry(41, 100, standard_wave)
	]
	expect(
		repeated_wave_schedule.is_valid_definition(),
		"Wave schedule rejected a repeated identical Wave Resource."
	)
	expect(
		repeated_wave_schedule.get_unique_wave_definitions().size() == 1,
		"Wave schedule did not deduplicate an identical Wave Resource."
	)

	var conflicting_wave := WaveDefinition.new()
	conflicting_wave.wave_id = standard_wave.wave_id
	conflicting_wave.display_name = "Conflicting Standard Wave"
	var conflicting_entries: Array[WaveEnemyEntryDefinition] = [
		_create_standard_test_enemy_entry()
	]
	conflicting_wave.enemy_entries = conflicting_entries

	expect(
		conflicting_wave.is_valid_definition(),
		"In-memory conflicting WaveDefinition fixture is invalid."
	)

	var conflicting_wave_schedule: SubstageWaveScheduleDefinition = (
		_create_test_wave_schedule(standard_wave)
	)
	conflicting_wave_schedule.entries = [
		_create_schedule_entry(1, 50, standard_wave),
		_create_schedule_entry(51, 100, conflicting_wave)
	]
	expect(
		not conflicting_wave_schedule.is_valid_definition(),
		(
			"Wave schedule accepted different Wave Resources "
			+ "with the same ID."
		)
	)

	print(
		"SUBSTAGE SCHEDULE VALIDATION TEST PASS: negative fixtures verified"
	)


func _create_test_substage(
	wave_definition: WaveDefinition
) -> SubstageDefinition:
	var substage := SubstageDefinition.new()
	substage.substage_id = &"test_substage"
	substage.display_name = "Test Substage"
	substage.wave_schedule = _create_test_wave_schedule(
		wave_definition
	)
	return substage


func _create_test_wave_schedule(
	wave_definition: WaveDefinition
) -> SubstageWaveScheduleDefinition:
	var schedule := SubstageWaveScheduleDefinition.new()
	schedule.schedule_id = &"test_schedule"
	schedule.display_name = "Test Schedule"
	schedule.entries = [
		_create_schedule_entry(1, 100, wave_definition)
	]
	return schedule


func _create_schedule_entry(
	start_wave: int,
	end_wave: int,
	wave_definition: WaveDefinition
) -> SubstageWaveScheduleEntryDefinition:
	var entry := SubstageWaveScheduleEntryDefinition.new()
	entry.start_wave = start_wave
	entry.end_wave = end_wave
	entry.wave_definition = wave_definition
	return entry


func test_wave_director_substage_queries() -> void:
	var production_world: Node = load("res://scenes/main_world.tscn").instantiate()
	var production_director: WaveDirector = production_world.get_node("WaveDirector") as WaveDirector
	expect(
		production_director.debug_start_global_wave == 0,
		"Production MainWorld has an active debug Wave start."
	)
	production_world.free()

	var stage: StageDefinition = (
		GameContent.get_stage(&"guardian_grove")
	)
	var standard_wave: WaveDefinition = GameContent.get_wave(
		&"guardian_grove",
		&"standard_bark_beetle"
	)
	var bark_beetle_definition: EnemyDefinition = (
		GameContent.get_enemy(&"bark_beetle")
	)

	expect(
		is_instance_valid(stage),
		"WaveDirector mapping test could not load Guardian Grove."
	)
	expect(
		is_instance_valid(standard_wave),
		"WaveDirector mapping test could not load the standard Wave."
	)
	expect(
		is_instance_valid(bark_beetle_definition),
		"WaveDirector mapping test could not load Bark Beetle."
	)

	if (
		not is_instance_valid(stage)
		or not is_instance_valid(standard_wave)
		or not is_instance_valid(bark_beetle_definition)
	):
		return

	var director := WaveDirector.new()
	director.stage_definition = stage
	director.enemy_definitions_by_id[&"bark_beetle"] = (
		bark_beetle_definition
	)

	expect(
		director.get_safe_substages_per_stage() == 10,
		"WaveDirector does not expose 10 Substages per Stage."
	)
	expect(
		director.get_safe_waves_per_substage() == 100,
		"WaveDirector does not expose 100 Waves per Substage."
	)
	expect(
		director.get_safe_waves_per_stage() == 1000,
		"WaveDirector does not expose 1000 Waves per Stage."
	)
	expect(
		director.get_current_progress_code() == "1-1-1",
		"WaveDirector initial progress code is not 1-1-1."
	)

	var debug_progress_mappings: Array[Dictionary] = [
		{"global_wave": 20, "code": "1-1-20"},
		{"global_wave": 21, "code": "1-1-21"},
		{"global_wave": 40, "code": "1-1-40"},
		{"global_wave": 50, "code": "1-1-50"},
		{"global_wave": 100, "code": "1-1-100"},
		{"global_wave": 101, "code": "1-2-1"},
		{"global_wave": 1001, "code": "2-1-1"}
	]

	for mapping in debug_progress_mappings:
		var global_wave: int = int(mapping["global_wave"])
		director.current_wave = global_wave
		expect(
			director.get_current_progress_code()
			== String(mapping["code"]),
			"Debug global Wave %d produced the wrong progress code."
			% global_wave
		)

	var mappings: Array[Dictionary] = [
		{
			"global_wave": 1,
			"stage": 1,
			"substage": 1,
			"wave": 1,
			"stage_start": 1,
			"substage_start": 1,
			"code": "1-1-1"
		},
		{
			"global_wave": 100,
			"stage": 1,
			"substage": 1,
			"wave": 100,
			"stage_start": 1,
			"substage_start": 1,
			"code": "1-1-100"
		},
		{
			"global_wave": 101,
			"stage": 1,
			"substage": 2,
			"wave": 1,
			"stage_start": 1,
			"substage_start": 101,
			"code": "1-2-1"
		},
		{
			"global_wave": 188,
			"stage": 1,
			"substage": 2,
			"wave": 88,
			"stage_start": 1,
			"substage_start": 101,
			"code": "1-2-88"
		},
		{
			"global_wave": 247,
			"stage": 1,
			"substage": 3,
			"wave": 47,
			"stage_start": 1,
			"substage_start": 201,
			"code": "1-3-47"
		},
		{
			"global_wave": 1000,
			"stage": 1,
			"substage": 10,
			"wave": 100,
			"stage_start": 1,
			"substage_start": 901,
			"code": "1-10-100"
		},
		{
			"global_wave": 1001,
			"stage": 2,
			"substage": 1,
			"wave": 1,
			"stage_start": 1001,
			"substage_start": 1001,
			"code": "2-1-1"
		},
		{
			"global_wave": 1047,
			"stage": 2,
			"substage": 1,
			"wave": 47,
			"stage_start": 1001,
			"substage_start": 1001,
			"code": "2-1-47"
		}
	]

	for mapping in mappings:
		var global_wave: int = int(mapping["global_wave"])
		director.current_wave = global_wave

		expect(
			director.get_current_stage_number()
			== int(mapping["stage"]),
			"Global Wave %d resolved to the wrong Stage."
			% global_wave
		)
		expect(
			director.get_current_substage_number()
			== int(mapping["substage"]),
			"Global Wave %d resolved to the wrong Substage."
			% global_wave
		)
		expect(
			director.get_current_wave_in_substage()
			== int(mapping["wave"]),
			"Global Wave %d resolved to the wrong Substage Wave."
			% global_wave
		)
		expect(
			director.get_current_stage_start_wave()
			== int(mapping["stage_start"]),
			"Global Wave %d resolved to the wrong Stage start."
			% global_wave
		)
		expect(
			director.get_current_substage_start_wave()
			== int(mapping["substage_start"]),
			"Global Wave %d resolved to the wrong Substage start."
			% global_wave
		)
		expect(
			director.get_current_progress_code()
			== String(mapping["code"]),
			"Global Wave %d produced the wrong progress code."
			% global_wave
		)
		expect(
			is_instance_valid(
				director.get_current_wave_definition()
			)
			and director.get_current_wave_definition().wave_id
			== (
				&"guardian_grove_boss"
				if int(mapping["wave"]) == 100
				else &"standard_bark_beetle"
			),
			"Global Wave %d resolved the wrong WaveDefinition."
			% global_wave
		)

	if OS.is_debug_build():
		director.current_wave = 0
		director.highest_completed_wave = 7
		director.debug_start_global_wave = 50
		expect(
			director._apply_debug_start_if_needed(),
			"WaveDirector did not apply a valid debug start."
		)
		expect(
			director.current_wave == 49,
			"Debug start did not prepare Wave 50 without off-by-one."
		)
		expect(
			director.highest_completed_wave == 7,
			"Debug start changed highest completed Wave."
		)

		director.current_wave += 1
		expect(
			director.get_current_progress_code() == "1-1-50",
			"Prepared debug start did not resolve to 1-1-50."
		)

		director.debug_start_global_wave = 20
		expect(
			not director._apply_debug_start_if_needed(),
			"WaveDirector applied debug start more than once."
		)
		expect(
			director.current_wave == 50,
			"Repeated debug start changed the current Wave."
		)

	director.current_wave = 1001
	expect(
		director.get_current_wave_in_stage() == 1,
		"Global Wave 1001 did not reset balance to Stage Wave 1."
	)
	expect(
		director.get_current_enemies_per_side() == 3,
		"Global Wave 1001 did not reset Bark Beetle count to 3."
	)
	expect(
		is_equal_approx(
			director.get_current_enemy_health(),
			12.0
		),
		"Global Wave 1001 did not reset Bark Beetle health to 12."
	)

	print(
		"WAVE DIRECTOR PROGRESS TEST PASS: "
		+ "1-1-1 through 2-1-47 boundaries verified"
	)
	print(
		"DEBUG START TEST PASS: one-shot mapping and progression isolation"
	)

	director.free()


func test_guardian_grove_boss_definitions_and_scenes() -> void:
	var expected_data: Array[Dictionary] = [
		{
			"id": &"bark_warden",
			"rank": EnemyDefinition.ENCOUNTER_RANK_MINIBOSS,
			"speed": 85.0,
			"health": 120.0,
			"damage": 4.0,
			"interval": 1.4,
			"range": 145.0,
			"essence": 8,
			"xp": 8,
			"chance": 0.05,
			"pity": 1
		},
		{
			"id": &"ancient_bark_colossus",
			"rank": EnemyDefinition.ENCOUNTER_RANK_BOSS,
			"speed": 60.0,
			"health": 300.0,
			"damage": 7.0,
			"interval": 1.8,
			"range": 165.0,
			"essence": 20,
			"xp": 20,
			"chance": 0.15,
			"pity": 3
		}
	]
	var stage: StageDefinition = GameContent.get_stage(&"guardian_grove")

	for expected in expected_data:
		var definition: EnemyDefinition = GameContent.get_enemy(expected["id"])
		expect(is_instance_valid(definition), "Boss EnemyDefinition is missing.")
		if not is_instance_valid(definition):
			continue

		expect(definition.is_valid_definition(), "Boss EnemyDefinition is invalid.")
		expect(definition.encounter_rank_id == expected["rank"], "Boss rank differs.")
		expect(is_equal_approx(definition.movement_speed, expected["speed"]), "Boss speed differs.")
		expect(is_equal_approx(definition.maximum_health, expected["health"]), "Boss health differs.")
		expect(is_equal_approx(definition.attack_damage, expected["damage"]), "Boss damage differs.")
		expect(is_equal_approx(definition.attack_interval, expected["interval"]), "Boss interval differs.")
		expect(is_equal_approx(definition.attack_range, expected["range"]), "Boss range differs.")
		expect(definition.essence_reward == expected["essence"], "Boss Essence differs.")
		expect(definition.experience_reward == expected["xp"], "Boss XP differs.")
		expect(is_equal_approx(definition.branch_seed_roll_chance, expected["chance"]), "Boss seed chance differs.")
		expect(definition.branch_seed_pity_points == expected["pity"], "Boss pity differs.")

		var enemy: Node = definition.enemy_scene.instantiate()
		expect(enemy is CharacterBody2D, "Boss scene root is not CharacterBody2D.")
		expect(enemy.has_node("HealthComponent"), "Boss has no HealthComponent.")
		expect(enemy.has_node("AttackComponent"), "Boss has no AttackComponent.")
		expect(enemy.has_node("MovementComponent"), "Boss has no MovementComponent.")
		expect(
			bool(enemy.call("configure_from_definition", definition))
			and bool(enemy.call("configure_stage_context", stage)),
			"Boss scene rejected definition or Stage context."
		)
		expect(enemy.get("stage_definition") == stage, "Boss did not retain Stage context.")
		enemy.free()

	var schedule: SubstageWaveScheduleDefinition = preload(
		"res://resources/wave_schedules/guardian_grove_standard_schedule.tres"
	)
	expect(
		schedule.get_wave_for_number(50).wave_id == &"guardian_grove_miniboss",
		"Guardian Grove Wave 50 is not the miniboss Wave."
	)
	expect(
		schedule.get_wave_for_number(100).wave_id == &"guardian_grove_boss",
		"Guardian Grove Wave 100 is not the boss Wave."
	)
	print("GUARDIAN GROVE BOSS DEFINITIONS TEST PASS")


func test_enemy_spawn_request() -> void:
	var definition: EnemyDefinition = (
		GameContent.get_enemy(&"bark_beetle")
	)
	var stage: StageDefinition = GameContent.get_stage(&"guardian_grove")

	expect(
		is_instance_valid(definition),
		"Spawn request test could not load Bark Beetle definition."
	)

	if not is_instance_valid(definition) or not is_instance_valid(stage):
		return

	var valid_request := EnemySpawnRequest.new(
		definition,
		2,
		definition.maximum_health,
		1.0,
		stage
	)

	expect(
		valid_request.is_valid_request(),
		"Valid EnemySpawnRequest was rejected."
	)
	expect(
		valid_request.get_enemy_id() == &"bark_beetle",
		"EnemySpawnRequest returned the wrong enemy ID."
	)
	expect(
		valid_request.enemies_per_side == 2,
		"EnemySpawnRequest did not retain enemy count 2."
	)
	expect(
		is_equal_approx(
			valid_request.maximum_health,
			12.0
		),
		"EnemySpawnRequest did not retain maximum health 12.0."
	)
	expect(
		is_equal_approx(
			valid_request.attack_damage_multiplier,
			1.0
		),
		"EnemySpawnRequest did not retain damage multiplier 1.0."
	)

	var missing_definition_request := EnemySpawnRequest.new(
		null,
		2,
		12.0,
		1.0,
		stage
	)
	var zero_count_request := EnemySpawnRequest.new(
		definition,
		0,
		12.0,
		1.0,
		stage
	)
	var zero_health_request := EnemySpawnRequest.new(
		definition,
		2,
		0.0,
		1.0,
		stage
	)
	var zero_damage_request := EnemySpawnRequest.new(
		definition,
		2,
		12.0,
		0.0,
		stage
	)
	var missing_stage_request := EnemySpawnRequest.new(
		definition,
		2,
		12.0,
		1.0,
		null
	)

	expect(
		not missing_definition_request.is_valid_request(),
		"EnemySpawnRequest accepted a null definition."
	)
	expect(
		missing_definition_request.get_enemy_id() == &"",
		"Invalid EnemySpawnRequest returned a non-empty enemy ID."
	)
	expect(
		not zero_count_request.is_valid_request(),
		"EnemySpawnRequest accepted zero enemies per side."
	)
	expect(
		not zero_health_request.is_valid_request(),
		"EnemySpawnRequest accepted zero maximum health."
	)
	expect(
		not zero_damage_request.is_valid_request(),
		"EnemySpawnRequest accepted zero damage multiplier."
	)
	expect(
		not missing_stage_request.is_valid_request(),
		"EnemySpawnRequest accepted a missing StageDefinition."
	)
	expect(
		valid_request.stage_definition == stage,
		"EnemySpawnRequest did not retain the StageDefinition instance."
	)

	var mixed_wave: WaveDefinition = GameContent.get_wave(
		&"guardian_grove",
		&"bark_beetle_runner_mixed"
	)
	var bark_runner: EnemyDefinition = GameContent.get_enemy(
		&"bark_runner"
	)

	expect(
		is_instance_valid(stage),
		"Production SpawnRequest test could not load Guardian Grove."
	)
	expect(
		is_instance_valid(mixed_wave),
		"Production SpawnRequest test could not load the mixed Wave."
	)
	expect(
		is_instance_valid(bark_runner),
		"Production SpawnRequest test could not load Bark Runner."
	)

	if (
		is_instance_valid(stage)
		and is_instance_valid(mixed_wave)
		and is_instance_valid(bark_runner)
	):
		var stage_wave: int = 20
		var production_requests: Array[EnemySpawnRequest] = [
			EnemySpawnRequest.new(
				definition,
				stage.get_enemy_count_for_stage_wave(
					mixed_wave,
					&"bark_beetle",
					stage_wave
				),
				stage.get_enemy_health_for_stage_wave(
					mixed_wave,
					definition,
					stage_wave
				),
				stage.get_enemy_damage_multiplier(
					mixed_wave,
					&"bark_beetle",
					stage_wave
				),
				stage
			),
			EnemySpawnRequest.new(
				bark_runner,
				stage.get_enemy_count_for_stage_wave(
					mixed_wave,
					&"bark_runner",
					stage_wave
				),
				stage.get_enemy_health_for_stage_wave(
					mixed_wave,
					bark_runner,
					stage_wave
				),
				stage.get_enemy_damage_multiplier(
					mixed_wave,
					&"bark_runner",
					stage_wave
				),
				stage
			)
		]
		var beetle_request: EnemySpawnRequest = production_requests[0]
		var runner_request: EnemySpawnRequest = production_requests[1]

		expect(
			beetle_request.is_valid_request()
			and runner_request.is_valid_request(),
			"Production mixed Wave created an invalid SpawnRequest."
		)
		expect(
			beetle_request.enemies_per_side == 4
			and runner_request.enemies_per_side == 2,
			"Production mixed SpawnRequests have incorrect counts."
		)
		expect(
			is_equal_approx(beetle_request.maximum_health, 15.42)
			and is_equal_approx(runner_request.maximum_health, 8.995),
			"Production mixed SpawnRequests have incorrect health."
		)
		expect(
			is_equal_approx(
				definition.attack_damage
				* beetle_request.attack_damage_multiplier,
				1.5855
			)
			and is_equal_approx(
				bark_runner.attack_damage
				* runner_request.attack_damage_multiplier,
				0.79275
			),
			"Production mixed SpawnRequests have incorrect damage."
		)


func test_health_component() -> void:
	depleted_signal_count = 0

	var health: EnemyHealthComponent = (
		EnemyHealthComponent.new()
	)
	health.depleted.connect(
		_on_health_depleted
	)

	expect(
		not health.is_initialized(),
		"Health component started initialized."
	)
	expect(
		not health.apply_damage(5.0),
		"Health component accepted damage before initialization."
	)

	health.initialize(30.0)

	expect(
		is_equal_approx(
			health.get_maximum_health(),
			30.0
		),
		"Health component maximum health is not 30.0."
	)
	expect(
		is_equal_approx(
			health.get_current_health(),
			30.0
		),
		"Health component current health did not initialize to 30.0."
	)
	expect(
		is_equal_approx(
			health.get_health_ratio(),
			1.0
		),
		"Health component initial ratio is not 1.0."
	)

	expect(
		health.apply_damage(5.0),
		"Health component rejected valid damage."
	)
	expect(
		is_equal_approx(
			health.get_current_health(),
			25.0
		),
		"Health component did not reduce health to 25.0."
	)
	expect(
		is_equal_approx(
			health.get_health_ratio(),
			25.0 / 30.0
		),
		"Health component ratio is incorrect after damage."
	)

	expect(
		health.apply_damage(25.0),
		"Health component rejected depleting damage."
	)
	expect(
		is_equal_approx(
			health.get_current_health(),
			0.0
		),
		"Health component did not reach zero health."
	)
	expect(
		health.is_depleted(),
		"Health component did not report depletion."
	)
	expect(
		depleted_signal_count == 1,
		"Health depleted signal was not emitted exactly once."
	)
	expect(
		not health.apply_damage(5.0),
		"Health component accepted damage after depletion."
	)
	expect(
		is_equal_approx(
			health.get_current_health(),
			0.0
		),
		"Health component changed health after depletion."
	)
	expect(
		depleted_signal_count == 1,
		"Health depleted signal repeated after depletion."
	)

	health.free()


func test_attack_component() -> void:
	attack_request_count = 0

	var attack_component: EnemyAttackComponent = (
		EnemyAttackComponent.new()
	)
	var timer := Timer.new()
	timer.name = "AttackTimer"
	attack_component.add_child(timer)
	attack_component.attack_requested.connect(
		_on_attack_requested
	)
	add_child(attack_component)

	await get_tree().process_frame

	attack_component.initialize(
		5.0,
		0.02
	)

	expect(
		attack_component.is_initialized(),
		"Attack component did not initialize."
	)
	expect(
		is_equal_approx(
			attack_component.get_attack_damage(),
			5.0
		),
		"Attack component damage is not 5.0."
	)
	expect(
		is_equal_approx(
			attack_component.get_attack_interval(),
			0.02
		),
		"Attack component interval is not 0.02."
	)
	expect(
		not attack_component.is_attacking(),
		"Attack component started its timer during initialization."
	)

	attack_component.start_attacking()
	expect(
		attack_component.is_attacking(),
		"Attack component timer did not start."
	)
	await get_tree().create_timer(0.08).timeout

	expect(
		attack_request_count > 0,
		"Attack component did not request an attack."
	)

	attack_component.set_enabled(false)
	var requests_after_disable: int = (
		attack_request_count
	)
	await get_tree().create_timer(0.05).timeout

	expect(
		attack_request_count == requests_after_disable,
		"Attack component requested an attack after being disabled."
	)
	expect(
		not attack_component.is_attacking(),
		"Attack component timer kept running after disable."
	)
	expect(
		not attack_component.is_enabled(),
		"Attack component did not retain disabled state."
	)

	attack_component.queue_free()
	await get_tree().process_frame


func test_movement_component() -> void:
	var body := CharacterBody2D.new()
	var target := Node2D.new()
	var movement: EnemyMovementComponent = (
		EnemyMovementComponent.new()
	)

	body.global_position = Vector2.ZERO
	target.global_position = Vector2(500.0, 0.0)

	add_child(body)
	add_child(target)
	add_child(movement)

	await get_tree().physics_frame

	var initialized: bool = movement.initialize(
		body,
		target,
		120.0,
		130.0,
		5.0,
		240.0,
		70.0
	)
	expect(
		initialized,
		"Movement component did not initialize."
	)

	if not initialized:
		movement.queue_free()
		body.queue_free()
		target.queue_free()
		await get_tree().process_frame
		return

	var formation_configured: bool = (
		movement.configure_formation(
			1.0,
			40.0,
			1.0,
			0.0,
			1.1
		)
	)
	expect(
		formation_configured,
		"Movement component formation was not configured."
	)
	expect(
		movement.is_formation_configured(),
		"Movement component did not report configured formation."
	)
	expect(
		is_equal_approx(
			movement.get_formation_side(),
			1.0
		),
		"Movement component formation side is not 1."
	)
	expect(
		is_equal_approx(
			movement.get_lane_y(),
			40.0
		),
		"Movement component lane Y is not 40."
	)
	expect(
		body.scale.is_equal_approx(
			Vector2(1.1, 1.1)
		),
		"Movement component did not apply crowd scale."
	)
	expect(
		body.z_index == 40,
		"Movement component initial z-index is not 40."
	)
	expect(
		is_equal_approx(
			movement.get_target_x(0),
			630.0
		),
		"Movement component column 0 target X is not 630."
	)
	expect(
		is_equal_approx(
			movement.get_target_x(1),
			700.0
		),
		"Movement component column 1 target X is not 700."
	)

	body.global_position = Vector2(
		movement.get_target_x(0),
		40.0
	)
	var reached_target: bool = movement.physics_step(
		0.016,
		0
	)
	expect(
		reached_target,
		"Movement component did not report its reached target."
	)
	expect(
		body.velocity.is_zero_approx(),
		"Movement component retained velocity at its target."
	)

	body.global_position = Vector2.ZERO
	var moved_toward_target: bool = movement.physics_step(
		0.016,
		0
	)
	expect(
		not moved_toward_target,
		"Movement component reported a distant target as reached."
	)
	expect(
		body.velocity.x > 0.0,
		"Movement component did not set positive X velocity."
	)
	expect(
		body.global_position.y > 0.0
		and body.global_position.y < 40.0,
		"Movement component did not approach lane Y."
	)
	expect(
		body.z_index == int(body.global_position.y),
		"Movement component z-index does not match global Y."
	)

	movement.set_enabled(false)
	expect(
		body.velocity.is_zero_approx(),
		"Movement component retained velocity after disable."
	)

	movement.queue_free()
	body.queue_free()
	target.queue_free()
	await get_tree().process_frame


func test_enemy_tracker() -> void:
	enemies_cleared_count = 0

	var tracker := EnemyTracker.new()
	tracker.enemies_cleared.connect(
		_on_enemies_cleared
	)
	add_child(tracker)

	await get_tree().process_frame

	var first_enemy := Node.new()
	var second_enemy := Node.new()
	add_child(first_enemy)
	add_child(second_enemy)

	expect(
		tracker.get_enemy_count() == 0,
		"EnemyTracker did not start empty."
	)

	tracker.register_enemy(first_enemy)
	tracker.register_enemy(second_enemy)

	var tracked_enemies: Array[Node] = (
		tracker.get_enemies()
	)
	expect(
		tracker.get_enemy_count() == 2,
		"EnemyTracker count is not 2 after registration."
	)
	expect(
		tracker.has_enemies(),
		"EnemyTracker did not report registered enemies."
	)
	expect(
		tracked_enemies.has(first_enemy)
		and tracked_enemies.has(second_enemy),
		"EnemyTracker did not return both registered enemies."
	)

	tracker.register_enemy(first_enemy)
	expect(
		tracker.get_enemy_count() == 2,
		"EnemyTracker duplicated an enemy registration."
	)

	tracker.unregister_enemy(first_enemy)
	expect(
		tracker.get_enemy_count() == 1,
		"EnemyTracker count is not 1 after unregistering one enemy."
	)
	expect(
		enemies_cleared_count == 0,
		"EnemyTracker emitted enemies_cleared too early."
	)

	tracker.unregister_enemy(second_enemy)
	expect(
		tracker.get_enemy_count() == 0,
		"EnemyTracker count is not 0 after clearing enemies."
	)
	expect(
		not tracker.has_enemies(),
		"EnemyTracker still reports enemies after clearing."
	)
	expect(
		enemies_cleared_count == 1,
		"EnemyTracker did not emit enemies_cleared exactly once."
	)

	tracker.unregister_enemy(second_enemy)
	expect(
		tracker.get_enemy_count() == 0,
		"EnemyTracker changed count after repeated unregister."
	)
	expect(
		enemies_cleared_count == 1,
		"EnemyTracker repeated enemies_cleared after unregister."
	)

	first_enemy.queue_free()
	second_enemy.queue_free()
	tracker.queue_free()
	await get_tree().process_frame


func test_lane_registry() -> void:
	var registry := LaneRegistry.new()
	add_child(registry)

	await get_tree().process_frame

	var enemy_a := Node.new()
	var enemy_b := Node.new()
	var enemy_c := Node.new()
	add_child(enemy_a)
	add_child(enemy_b)
	add_child(enemy_c)

	registry.register_enemy(
		enemy_a,
		-1.0,
		2,
		1
	)
	registry.register_enemy(
		enemy_b,
		-1.0,
		2,
		0
	)
	registry.register_enemy(
		enemy_c,
		1.0,
		2,
		0
	)

	expect(
		registry.get_queue_column(enemy_b) == 0,
		"LaneRegistry did not put enemy B at left column 0."
	)
	expect(
		registry.get_queue_column(enemy_a) == 1,
		"LaneRegistry did not put enemy A at left column 1."
	)
	expect(
		registry.get_queue_column(enemy_c) == 0,
		"LaneRegistry did not put enemy C at right column 0."
	)
	expect(
		registry.get_lane_enemy_count(-1.0, 2) == 2,
		"LaneRegistry left lane count is not 2."
	)
	expect(
		registry.get_lane_enemy_count(1.0, 2) == 1,
		"LaneRegistry right lane count is not 1."
	)

	var left_lane_enemies: Array[Node] = (
		registry.get_lane_enemies(-1.0, 2)
	)
	var right_lane_enemies: Array[Node] = (
		registry.get_lane_enemies(1.0, 2)
	)

	expect(
		not left_lane_enemies.has(enemy_c)
		and not right_lane_enemies.has(enemy_a)
		and not right_lane_enemies.has(enemy_b),
		"LaneRegistry mixed enemies between formation sides."
	)
	expect(
		left_lane_enemies.size() == 2,
		"LaneRegistry did not return two ordered left enemies."
	)

	if left_lane_enemies.size() == 2:
		expect(
			left_lane_enemies[0] == enemy_b
			and left_lane_enemies[1] == enemy_a,
			"LaneRegistry left lane order is not B, A."
		)

	registry.unregister_enemy(enemy_b)
	expect(
		registry.get_queue_column(enemy_a) == 0,
		"LaneRegistry did not promote enemy A to column 0."
	)
	expect(
		registry.get_lane_enemy_count(-1.0, 2) == 1,
		"LaneRegistry left lane count is not 1 after unregister."
	)

	registry.unregister_enemy(enemy_b)
	expect(
		registry.get_queue_column(enemy_a) == 0,
		"LaneRegistry changed state after repeated unregister."
	)
	expect(
		registry.get_lane_enemy_count(-1.0, 2) == 1,
		"LaneRegistry changed lane count after repeated unregister."
	)

	registry.unregister_enemy(enemy_a)
	registry.unregister_enemy(enemy_c)
	expect(
		registry.get_lane_enemy_count(-1.0, 2) == 0,
		"LaneRegistry left lane did not become empty."
	)
	expect(
		registry.get_lane_enemy_count(1.0, 2) == 0,
		"LaneRegistry right lane did not become empty."
	)

	enemy_a.queue_free()
	enemy_b.queue_free()
	enemy_c.queue_free()
	registry.queue_free()
	await get_tree().process_frame


func test_spawn_director_multi_request_batch() -> void:
	var definition: EnemyDefinition = (
		GameContent.get_enemy(&"bark_beetle")
	)
	var stage: StageDefinition = GameContent.get_stage(&"guardian_grove")

	expect(
		is_instance_valid(definition),
		"Multi-request fixture could not load Bark Beetle definition."
	)

	if not is_instance_valid(definition) or not is_instance_valid(stage):
		return

	var fixture := Node2D.new()
	fixture.name = "SpawnDirectorFixture"
	add_child(fixture)

	var entities := Node2D.new()
	entities.name = "Entities"
	fixture.add_child(entities)

	var world := Node2D.new()
	world.name = "World"
	fixture.add_child(world)

	var left_spawn_point := Marker2D.new()
	left_spawn_point.name = "LeftSpawnPoint"
	left_spawn_point.position = Vector2(0.0, 40.0)
	world.add_child(left_spawn_point)

	var right_spawn_point := Marker2D.new()
	right_spawn_point.name = "RightSpawnPoint"
	right_spawn_point.position = Vector2(1000.0, 40.0)
	world.add_child(right_spawn_point)

	var tree_target := Node2D.new()
	tree_target.name = "Tree"
	tree_target.position = Vector2(500.0, 40.0)
	fixture.add_child(tree_target)
	tree_target.add_to_group("tree")

	var enemy_tracker := EnemyTracker.new()
	enemy_tracker.name = "EnemyTracker"
	fixture.add_child(enemy_tracker)

	var lane_registry := LaneRegistry.new()
	lane_registry.name = "LaneRegistry"
	fixture.add_child(lane_registry)

	var spawn_director := SpawnDirector.new()
	spawn_director.name = "SpawnDirector"
	fixture.add_child(spawn_director)

	await get_tree().process_frame

	expect(
		spawn_director.is_ready_to_spawn(),
		"Multi-request fixture SpawnDirector is not ready."
	)

	var requests: Array[EnemySpawnRequest] = [
		EnemySpawnRequest.new(
			definition,
			6,
			30.0,
			1.0,
			stage
		),
		EnemySpawnRequest.new(
			definition,
			4,
			30.0,
			1.0,
			stage
		)
	]

	var completed: bool = await (
		spawn_director.spawn_wave(
			requests,
			0.001,
			_always_continue
		)
	)

	expect(
		completed,
		"SpawnDirector did not complete the multi-request batch."
	)

	var spawned_enemies: Array[Node] = entities.get_children()
	expect(
		spawned_enemies.size() == 20,
		"Multi-request fixture did not spawn exactly 20 enemies."
	)

	var left_enemy_count: int = 0
	var right_enemy_count: int = 0
	var queue_keys: Dictionary = {}

	for enemy in spawned_enemies:
		expect(
			enemy.get("stage_definition") == stage,
			"SpawnDirector did not preserve the exact StageDefinition."
		)
		var formation_side: float = float(
			enemy.get("formation_side")
		)
		var lane_index: int = int(
			enemy.get("lane_index")
		)
		var queue_order: int = int(
			enemy.get("queue_order")
		)

		if formation_side < 0.0:
			left_enemy_count += 1
		elif formation_side > 0.0:
			right_enemy_count += 1

		var queue_key: String = "%d:%d:%d" % [
			int(formation_side),
			lane_index,
			queue_order
		]
		var queue_key_is_unique: bool = (
			not queue_keys.has(queue_key)
		)

		expect(
			queue_key_is_unique,
			"Multi-request fixture produced duplicate queue key %s."
			% queue_key
		)
		queue_keys[queue_key] = true

		expect(
			lane_registry.get_queue_column(enemy)
			== queue_order,
			(
				"LaneRegistry column does not match queue order "
				+ "for key %s."
			)
			% queue_key
		)

	expect(
		left_enemy_count == 10,
		"Multi-request fixture did not spawn 10 left enemies."
	)
	expect(
		right_enemy_count == 10,
		"Multi-request fixture did not spawn 10 right enemies."
	)
	expect(
		queue_keys.size() == 20,
		"Multi-request fixture did not produce 20 unique queue keys."
	)

	print(
		(
			"ENEMY MULTI-REQUEST FIXTURE: enemies=%d, "
			+ "unique_queue_keys=%d"
		)
		% [
			spawned_enemies.size(),
			queue_keys.size()
		]
	)

	for enemy in spawned_enemies:
		if not is_instance_valid(enemy):
			continue

		if enemy.has_method("stop_combat"):
			enemy.call("stop_combat")

		enemy.remove_from_group("enemies")
		enemy.queue_free()

	await get_tree().process_frame
	await get_tree().process_frame

	expect(
		enemy_tracker.get_enemy_count() == 0,
		"EnemyTracker retained fixture enemies after cleanup."
	)
	expect(
		entities.get_child_count() == 0,
		"Fixture Entities retained enemies after cleanup."
	)

	fixture.queue_free()
	await get_tree().process_frame

	expect(
		get_tree().get_nodes_in_group("enemy_tracker").is_empty(),
		"Fixture left an EnemyTracker group member behind."
	)
	expect(
		get_tree().get_nodes_in_group("lane_registry").is_empty(),
		"Fixture left a LaneRegistry group member behind."
	)
	expect(
		get_tree().get_nodes_in_group("spawn_director").is_empty(),
		"Fixture left a SpawnDirector group member behind."
	)
	expect(
		get_tree().get_nodes_in_group("tree").is_empty(),
		"Fixture left a tree group member behind."
	)
	expect(
		get_tree().get_nodes_in_group("enemies").is_empty(),
		"Fixture left an enemies group member behind."
	)


func test_spawn_director_mixed_enemy_batch() -> void:
	var bark_beetle: EnemyDefinition = (
		GameContent.get_enemy(&"bark_beetle")
	)
	var bark_runner: EnemyDefinition = (
		GameContent.get_enemy(&"bark_runner")
	)
	var bark_warden: EnemyDefinition = (
		GameContent.get_enemy(&"bark_warden")
	)
	var ancient_bark_colossus: EnemyDefinition = (
		GameContent.get_enemy(&"ancient_bark_colossus")
	)
	var stage: StageDefinition = GameContent.get_stage(&"guardian_grove")

	expect(
		is_instance_valid(bark_beetle),
		"Mixed fixture could not load Bark Beetle."
	)
	expect(
		is_instance_valid(bark_runner),
		"Mixed fixture could not load Bark Runner."
	)
	expect(
		is_instance_valid(bark_warden),
		"Mixed fixture could not load Bark Warden."
	)
	expect(
		is_instance_valid(ancient_bark_colossus),
		"Mixed fixture could not load Ancient Bark Colossus."
	)

	if (
		not is_instance_valid(bark_beetle)
		or not is_instance_valid(bark_runner)
		or not is_instance_valid(bark_warden)
		or not is_instance_valid(ancient_bark_colossus)
		or not is_instance_valid(stage)
	):
		return

	var fixture := Node2D.new()
	fixture.name = "MixedSpawnDirectorFixture"
	add_child(fixture)

	var entities := Node2D.new()
	entities.name = "Entities"
	fixture.add_child(entities)

	var world := Node2D.new()
	world.name = "World"
	fixture.add_child(world)

	var left_spawn_point := Marker2D.new()
	left_spawn_point.name = "LeftSpawnPoint"
	left_spawn_point.position = Vector2(0.0, 40.0)
	world.add_child(left_spawn_point)

	var right_spawn_point := Marker2D.new()
	right_spawn_point.name = "RightSpawnPoint"
	right_spawn_point.position = Vector2(1000.0, 40.0)
	world.add_child(right_spawn_point)

	var tree_target := Node2D.new()
	tree_target.name = "Tree"
	tree_target.position = Vector2(500.0, 40.0)
	fixture.add_child(tree_target)
	tree_target.add_to_group("tree")

	var enemy_tracker := EnemyTracker.new()
	enemy_tracker.name = "EnemyTracker"
	fixture.add_child(enemy_tracker)

	var lane_registry := LaneRegistry.new()
	lane_registry.name = "LaneRegistry"
	fixture.add_child(lane_registry)

	var spawn_director := SpawnDirector.new()
	spawn_director.name = "SpawnDirector"
	fixture.add_child(spawn_director)

	await get_tree().process_frame

	expect(
		spawn_director.is_ready_to_spawn(),
		"Mixed fixture SpawnDirector is not ready."
	)

	var requests: Array[EnemySpawnRequest] = [
		EnemySpawnRequest.new(
			bark_beetle,
			1,
			bark_beetle.maximum_health,
			1.0,
			stage
		),
		EnemySpawnRequest.new(
			bark_runner,
			1,
			bark_runner.maximum_health,
			1.0,
			stage
		),
		EnemySpawnRequest.new(
			bark_warden,
			1,
			bark_warden.maximum_health,
			1.0,
			stage
		),
		EnemySpawnRequest.new(
			ancient_bark_colossus,
			1,
			ancient_bark_colossus.maximum_health,
			1.0,
			stage
		)
	]

	var completed: bool = await (
		spawn_director.spawn_wave(
			requests,
			0.001,
			_always_continue
		)
	)

	expect(
		completed,
		"SpawnDirector did not complete the mixed enemy batch."
	)

	var spawned_enemies: Array[Node] = entities.get_children()
	expect(
		spawned_enemies.size() == 8,
		"Mixed fixture did not spawn exactly 8 enemies."
	)
	expect(
		enemy_tracker.get_enemy_count() == 8,
		"Mixed fixture did not register all enemies with EnemyTracker."
	)

	var bark_beetle_count: int = 0
	var bark_runner_count: int = 0
	var bark_warden_count: int = 0
	var ancient_bark_colossus_count: int = 0
	var left_enemy_count: int = 0
	var right_enemy_count: int = 0
	var queue_keys: Dictionary = {}

	for enemy_index in range(spawned_enemies.size()):
		var enemy: Node = spawned_enemies[enemy_index]
		expect(
			enemy.get("stage_definition") == stage,
			"Mixed SpawnDirector lost the exact StageDefinition."
		)
		var enemy_definition: EnemyDefinition = (
			enemy.get("enemy_definition") as EnemyDefinition
		)

		expect(
			is_instance_valid(enemy_definition),
			"Mixed fixture enemy has no applied definition."
		)

		if not is_instance_valid(enemy_definition):
			continue

		var enemy_id: StringName = enemy_definition.enemy_id

		if enemy_id == &"bark_beetle":
			bark_beetle_count += 1
		elif enemy_id == &"bark_runner":
			bark_runner_count += 1
		elif enemy_id == &"bark_warden":
			bark_warden_count += 1
		elif enemy_id == &"ancient_bark_colossus":
			ancient_bark_colossus_count += 1

		var expected_enemy_ids: Array[StringName] = [
			&"bark_beetle",
			&"bark_runner",
			&"bark_warden",
			&"ancient_bark_colossus"
		]
		var expected_enemy_id: StringName = expected_enemy_ids[
			floori(enemy_index / 2.0)
		]
		expect(
			enemy_id == expected_enemy_id,
			"Mixed fixture did not preserve request block order."
		)

		expect(
			enemy.get_node_or_null("HealthComponent")
			is EnemyHealthComponent,
			"Mixed fixture enemy has no HealthComponent."
		)
		expect(
			enemy.get_node_or_null("AttackComponent")
			is EnemyAttackComponent,
			"Mixed fixture enemy has no AttackComponent."
		)
		expect(
			enemy.get_node_or_null("MovementComponent")
			is EnemyMovementComponent,
			"Mixed fixture enemy has no MovementComponent."
		)

		var formation_side: float = float(
			enemy.get("formation_side")
		)
		var lane_index: int = int(
			enemy.get("lane_index")
		)
		var queue_order: int = int(
			enemy.get("queue_order")
		)

		if formation_side < 0.0:
			left_enemy_count += 1
		elif formation_side > 0.0:
			right_enemy_count += 1

		var queue_key: String = "%d:%d:%d" % [
			int(formation_side),
			lane_index,
			queue_order
		]
		expect(
			not queue_keys.has(queue_key),
			"Mixed fixture produced duplicate queue key %s."
			% queue_key
		)
		queue_keys[queue_key] = true

		expect(
			lane_registry.get_queue_column(enemy)
			== queue_order,
			"Mixed fixture queue column does not match queue order."
		)

	expect(
		bark_beetle_count == 2,
		"Mixed fixture did not spawn 2 Bark Beetles."
	)
	expect(
		bark_runner_count == 2,
		"Mixed fixture did not spawn 2 Bark Runners."
	)
	expect(
		bark_warden_count == 2,
		"Mixed fixture did not spawn 2 Bark Wardens."
	)
	expect(
		ancient_bark_colossus_count == 2,
		"Mixed fixture did not spawn 2 Ancient Bark Colossus enemies."
	)
	expect(
		left_enemy_count == 4,
		"Mixed fixture did not spawn 4 left enemies."
	)
	expect(
		right_enemy_count == 4,
		"Mixed fixture did not spawn 4 right enemies."
	)
	expect(
		queue_keys.size() == 8,
		"Mixed fixture did not produce 8 unique queue keys."
	)

	print(
		"MIXED ENEMY SPAWN TEST PASS: "
		+ "beetles=2, runners=2, wardens=2, colossus=2"
	)

	for enemy in spawned_enemies:
		if not is_instance_valid(enemy):
			continue

		if enemy.has_method("stop_combat"):
			enemy.call("stop_combat")

		enemy.remove_from_group("enemies")
		enemy.queue_free()

	await get_tree().process_frame
	await get_tree().process_frame

	expect(
		enemy_tracker.get_enemy_count() == 0,
		"EnemyTracker retained mixed fixture enemies after cleanup."
	)
	expect(
		entities.get_child_count() == 0,
		"Mixed fixture Entities retained enemies after cleanup."
	)

	fixture.queue_free()
	await get_tree().process_frame

	expect(
		get_tree().get_nodes_in_group("enemy_tracker").is_empty(),
		"Mixed fixture left an EnemyTracker group member behind."
	)
	expect(
		get_tree().get_nodes_in_group("lane_registry").is_empty(),
		"Mixed fixture left a LaneRegistry group member behind."
	)
	expect(
		get_tree().get_nodes_in_group("spawn_director").is_empty(),
		"Mixed fixture left a SpawnDirector group member behind."
	)
	expect(
		get_tree().get_nodes_in_group("tree").is_empty(),
		"Mixed fixture left a tree group member behind."
	)
	expect(
		get_tree().get_nodes_in_group("enemies").is_empty(),
		"Mixed fixture left an enemies group member behind."
	)


func _always_continue() -> bool:
	return true


func _on_health_depleted(
	_damage_source: Node
) -> void:
	depleted_signal_count += 1


func _on_attack_requested() -> void:
	attack_request_count += 1


func _on_enemies_cleared() -> void:
	enemies_cleared_count += 1


func finish_test() -> void:
	if failures.is_empty():
		print("ENEMY RUNTIME SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print(
		"ENEMY RUNTIME SMOKE TEST FAIL: %d failure(s)"
		% failures.size()
	)

	for failure in failures:
		print("- %s" % failure)

	get_tree().quit(1)
