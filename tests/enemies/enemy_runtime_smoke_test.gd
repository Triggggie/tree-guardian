extends Node


var failures: Array[String] = []
var depleted_signal_count: int = 0
var attack_request_count: int = 0
var enemies_cleared_count: int = 0


func _ready() -> void:
	print("ENEMY RUNTIME SMOKE TEST START")

	test_enemy_definition()
	test_wave_enemy_entry_definition()
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
			substage.get_wave_pattern_count() == 1,
			"Guardian Grove Substage %d does not have one pattern."
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
		expect(
			stage.get_wave_for_stage_index(
				stage_wave_index
			) == standard_wave,
			"Stage Wave index %d did not resolve the standard Wave."
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
		unique_waves.size() == 1,
		"Guardian Grove does not expose one unique WaveDefinition."
	)
	if unique_waves.size() == 1:
		expect(
			unique_waves[0] == standard_wave,
			"Guardian Grove unique Wave list returned the wrong Resource."
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
			bark_beetle_entry.base_count_per_side == 2,
			"Standard Wave entry base count is not 2."
		)
		expect(
			bark_beetle_entry.count_scaling_start_stage_wave == 1,
			"Standard Wave entry scaling start is not 1."
		)
		expect(
			bark_beetle_entry.count_increase_interval == 3,
			"Standard Wave entry count interval is not 3."
		)
		expect(
			bark_beetle_entry.count_increase_amount == 1,
			"Standard Wave entry count amount is not 1."
		)
		expect(
			bark_beetle_entry.maximum_count_per_side == 30,
			"Standard Wave entry maximum count is not 30."
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
		) == 2,
		"Standard Wave Stage Wave 1 count is not 2."
	)
	expect(
		standard_wave.get_enemy_count_for_id(
			&"bark_beetle",
			3
		) == 2,
		"Standard Wave Stage Wave 3 count is not 2."
	)
	expect(
		standard_wave.get_enemy_count_for_id(
			&"bark_beetle",
			4
		) == 3,
		"Standard Wave Stage Wave 4 count is not 3."
	)
	expect(
		standard_wave.get_enemy_count_for_id(
			&"bark_beetle",
			100
		) == 30,
		"Standard Wave Stage Wave 100 count is not 30."
	)
	expect(
		standard_wave.get_enemy_count_for_id(
			&"missing_enemy",
			1
		) == 0,
		"Standard Wave unknown enemy count is not 0."
	)
	expect(
		standard_wave.get_total_enemies_per_side(1) == 2,
		"Standard Wave Stage Wave 1 total count is not 2."
	)
	expect(
		standard_wave.get_total_enemies_per_side(4) == 3,
		"Standard Wave Stage Wave 4 total count is not 3."
	)
	expect(
		standard_wave.get_total_enemies_per_side(100) == 30,
		"Standard Wave Stage Wave 100 total count is not 30."
	)
	expect(
		is_equal_approx(
			standard_wave.spawn_interval,
			0.25
		),
		"Standard Wave spawn interval is not 0.25."
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
			0.7
		),
		"Standard Wave completion message duration is not 0.7."
	)
	expect(
		is_equal_approx(
			standard_wave.time_after_wave,
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

	var stage_wave_counts: Array[int] = [2, 2, 2, 3]

	for stage_wave_index in range(stage_wave_counts.size()):
		var stage_wave: int = stage_wave_index + 1
		expect(
			stage.get_enemy_count_for_stage_wave(
				standard_wave,
				&"bark_beetle",
				stage_wave
			) == stage_wave_counts[stage_wave_index],
			"Stage Wave %d Bark Beetle count is incorrect."
			% stage_wave
		)

	expect(
		stage.get_enemy_count_for_stage_wave(
			standard_wave,
			&"bark_beetle",
			100
		) == 30,
		"Stage Wave 100 Bark Beetle count is not 30."
	)
	expect(
		is_equal_approx(
			stage.get_enemy_damage_multiplier(
				standard_wave,
				&"bark_beetle"
			),
			1.0
		),
		"Stage Bark Beetle damage multiplier is not 1.0."
	)

	if is_instance_valid(bark_beetle_definition):
		var stage_wave_health: Array[float] = [
			30.0,
			33.0,
			36.0,
			39.0
		]

		for stage_wave_index in range(stage_wave_health.size()):
			var stage_wave: int = stage_wave_index + 1
			expect(
				is_equal_approx(
					stage.get_enemy_health_for_stage_wave(
						standard_wave,
						bark_beetle_definition,
						stage_wave
					),
					stage_wave_health[stage_wave_index]
				),
				"Stage Wave %d Bark Beetle health is incorrect."
				% stage_wave
			)

		expect(
			is_equal_approx(
				stage.get_enemy_health_for_stage_wave(
					standard_wave,
					bark_beetle_definition,
					100
				),
				327.0
			),
			"Stage Wave 100 Bark Beetle health is not 327.0."
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

	var empty_patterns_substage: SubstageDefinition = (
		_create_test_substage(standard_wave)
	)
	empty_patterns_substage.wave_patterns = []
	expect(
		not empty_patterns_substage.is_valid_definition(),
		"SubstageDefinition accepted empty Wave patterns."
	)

	var null_pattern_substage: SubstageDefinition = (
		_create_test_substage(standard_wave)
	)
	var null_patterns: Array[WaveDefinition] = [null]
	null_pattern_substage.wave_patterns = null_patterns
	expect(
		not null_pattern_substage.is_valid_definition(),
		"SubstageDefinition accepted a null Wave pattern."
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

	var repeated_wave_substage: SubstageDefinition = (
		_create_test_substage(standard_wave)
	)
	var repeated_patterns: Array[WaveDefinition] = [
		standard_wave,
		standard_wave
	]
	repeated_wave_substage.wave_patterns = repeated_patterns
	expect(
		repeated_wave_substage.is_valid_definition(),
		"SubstageDefinition rejected a repeated identical Wave Resource."
	)
	expect(
		repeated_wave_substage.get_unique_wave_definitions().size() == 1,
		"SubstageDefinition did not deduplicate an identical Wave Resource."
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

	var conflicting_wave_substage: SubstageDefinition = (
		_create_test_substage(standard_wave)
	)
	var conflicting_patterns: Array[WaveDefinition] = [
		standard_wave,
		conflicting_wave
	]
	conflicting_wave_substage.wave_patterns = conflicting_patterns
	expect(
		not conflicting_wave_substage.is_valid_definition(),
		(
			"SubstageDefinition accepted different Wave Resources "
			+ "with the same ID."
		)
	)


func _create_test_substage(
	wave_definition: WaveDefinition
) -> SubstageDefinition:
	var substage := SubstageDefinition.new()
	substage.substage_id = &"test_substage"
	substage.display_name = "Test Substage"
	var patterns: Array[WaveDefinition] = [wave_definition]
	substage.wave_patterns = patterns
	return substage


func test_wave_director_substage_queries() -> void:
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
			director.get_current_wave_definition()
			== standard_wave,
			"Global Wave %d resolved the wrong WaveDefinition."
			% global_wave
		)

	director.current_wave = 1001
	expect(
		director.get_current_wave_in_stage() == 1,
		"Global Wave 1001 did not reset balance to Stage Wave 1."
	)
	expect(
		director.get_current_enemies_per_side() == 2,
		"Global Wave 1001 did not reset Bark Beetle count to 2."
	)
	expect(
		is_equal_approx(
			director.get_current_enemy_health(),
			30.0
		),
		"Global Wave 1001 did not reset Bark Beetle health to 30."
	)

	print(
		"WAVE DIRECTOR PROGRESS TEST PASS: "
		+ "1-1-1 through 2-1-47 boundaries verified"
	)

	director.free()


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
