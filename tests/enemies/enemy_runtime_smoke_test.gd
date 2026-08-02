extends Node


var failures: Array[String] = []
var depleted_signal_count: int = 0
var attack_request_count: int = 0
var enemies_cleared_count: int = 0


func _ready() -> void:
	print("ENEMY RUNTIME SMOKE TEST START")

	test_enemy_definition()
	test_stage_and_wave_definition()
	test_enemy_spawn_request()
	test_health_component()
	await test_attack_component()
	await test_movement_component()
	await test_enemy_tracker()
	await test_lane_registry()
	await test_spawn_director_multi_request_batch()

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
			30.0
		),
		"Bark Beetle maximum health is not 30.0."
	)
	expect(
		is_equal_approx(
			definition.attack_damage,
			5.0
		),
		"Bark Beetle attack damage is not 5.0."
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
		stage.get_wave_count() == 100,
		"Guardian Grove does not expose 100 wave slots."
	)
	expect(
		stage.get_wave_pattern_count() == 1,
		"Guardian Grove does not have one Wave template."
	)
	expect(
		stage.repeat_indefinitely,
		"Guardian Grove is not configured to repeat indefinitely."
	)

	var first_wave: WaveDefinition = (
		stage.get_wave_for_stage_index(0)
	)
	var last_wave: WaveDefinition = (
		stage.get_wave_for_stage_index(99)
	)

	expect(
		is_instance_valid(first_wave),
		"Guardian Grove first Wave template is missing."
	)
	expect(
		is_instance_valid(last_wave),
		"Guardian Grove last Wave slot is missing."
	)
	expect(
		first_wave == last_wave,
		"Guardian Grove wave slots do not reuse the same template."
	)
	expect(
		stage.get_wave_for_stage_index(100) == null,
		"Guardian Grove accepted Wave index 100."
	)
	expect(
		stage.get_wave_for_stage_index(-1) == null,
		"Guardian Grove accepted a negative Wave index."
	)

	if not is_instance_valid(first_wave):
		return

	expect(
		first_wave.wave_id == &"standard_bark_beetle",
		"Standard Bark Beetle Wave ID is incorrect."
	)
	expect(
		first_wave.is_valid_definition(),
		"Standard Bark Beetle WaveDefinition is invalid."
	)
	expect(
		first_wave.enemy_ids.has(&"bark_beetle"),
		"Standard Wave does not contain Bark Beetle."
	)
	expect(
		first_wave.get_enemy_count_for_id(&"bark_beetle") == 2,
		"Standard Wave Bark Beetle base count is not 2."
	)
	expect(
		is_equal_approx(
			first_wave.spawn_interval,
			0.25
		),
		"Standard Wave spawn interval is not 0.25."
	)
	expect(
		is_equal_approx(
			first_wave.health_multiplier,
			1.0
		),
		"Standard Wave health multiplier is not 1.0."
	)
	expect(
		is_equal_approx(
			first_wave.damage_multiplier,
			1.0
		),
		"Standard Wave damage multiplier is not 1.0."
	)
	expect(
		is_equal_approx(
			first_wave.completion_message_duration,
			0.7
		),
		"Standard Wave completion message duration is not 0.7."
	)
	expect(
		is_equal_approx(
			first_wave.time_after_wave,
			0.5
		),
		"Standard Wave time after Wave is not 0.5."
	)

	var bark_beetle_definition: EnemyDefinition = (
		GameContent.get_enemy(&"bark_beetle")
	)
	expect(
		is_instance_valid(bark_beetle_definition),
		"Stage test could not load Bark Beetle EnemyDefinition."
	)

	expect(
		stage.get_enemy_count_for_global_wave(
			first_wave,
			&"bark_beetle",
			1
		) == 2,
		"Global Wave 1 Bark Beetle count is not 2."
	)
	expect(
		stage.get_enemy_count_for_global_wave(
			first_wave,
			&"bark_beetle",
			3
		) == 2,
		"Global Wave 3 Bark Beetle count is not 2."
	)
	expect(
		stage.get_enemy_count_for_global_wave(
			first_wave,
			&"bark_beetle",
			4
		) == 3,
		"Global Wave 4 Bark Beetle count is not 3."
	)
	expect(
		stage.get_enemy_count_for_global_wave(
			first_wave,
			&"bark_beetle",
			100
		) == 30,
		"Global Wave 100 Bark Beetle count is not 30."
	)
	expect(
		stage.get_enemy_count_for_global_wave(
			first_wave,
			&"bark_beetle",
			101
		) == 30,
		"Global Wave 101 Bark Beetle count is not 30."
	)

	if is_instance_valid(bark_beetle_definition):
		expect(
			is_equal_approx(
				stage.get_enemy_health_for_global_wave(
					first_wave,
					bark_beetle_definition,
					1
				),
				30.0
			),
			"Global Wave 1 Bark Beetle health is not 30.0."
		)
		expect(
			is_equal_approx(
				stage.get_enemy_health_for_global_wave(
					first_wave,
					bark_beetle_definition,
					2
				),
				33.0
			),
			"Global Wave 2 Bark Beetle health is not 33.0."
		)
		expect(
			is_equal_approx(
				stage.get_enemy_health_for_global_wave(
					first_wave,
					bark_beetle_definition,
					3
				),
				36.0
			),
			"Global Wave 3 Bark Beetle health is not 36.0."
		)
		expect(
			is_equal_approx(
				stage.get_enemy_health_for_global_wave(
					first_wave,
					bark_beetle_definition,
					4
				),
				39.0
			),
			"Global Wave 4 Bark Beetle health is not 39.0."
		)

	var indexed_wave: WaveDefinition = GameContent.get_wave(
		&"guardian_grove",
		&"standard_bark_beetle"
	)
	expect(
		indexed_wave == first_wave,
		"Scoped Guardian Grove Wave lookup returned the wrong Resource."
	)


func test_enemy_spawn_request() -> void:
	var definition: EnemyDefinition = (
		GameContent.get_enemy(&"bark_beetle")
	)

	expect(
		is_instance_valid(definition),
		"Spawn request test could not load Bark Beetle definition."
	)

	if not is_instance_valid(definition):
		return

	var valid_request := EnemySpawnRequest.new(
		definition,
		2,
		30.0,
		1.0
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
			30.0
		),
		"EnemySpawnRequest did not retain maximum health 30.0."
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
		30.0,
		1.0
	)
	var zero_count_request := EnemySpawnRequest.new(
		definition,
		0,
		30.0,
		1.0
	)
	var zero_health_request := EnemySpawnRequest.new(
		definition,
		2,
		0.0,
		1.0
	)
	var zero_damage_request := EnemySpawnRequest.new(
		definition,
		2,
		30.0,
		0.0
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

	expect(
		is_instance_valid(definition),
		"Multi-request fixture could not load Bark Beetle definition."
	)

	if not is_instance_valid(definition):
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
			1.0
		),
		EnemySpawnRequest.new(
			definition,
			4,
			30.0,
			1.0
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
