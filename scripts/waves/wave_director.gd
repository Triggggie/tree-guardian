class_name WaveDirector
extends Node


signal wave_changed(
	new_wave: int,
	enemies_per_side: int
)

signal wave_message_changed(
	message: String
)

signal new_highest_wave_completed(
	global_wave: int
)


const ACTIVE_STAGE_ID: StringName = &"guardian_grove"


var spawn_director: SpawnDirector
var enemy_tracker: EnemyTracker
var stage_definition: StageDefinition
var enemy_definitions_by_id: Dictionary = {}
var _initialized: bool = false

var current_wave: int = 0
var highest_completed_wave: int = 0

var _wave_cycle_id: int = 0
var _cycle_running: bool = false


func _ready() -> void:
	add_to_group("wave_director")

	spawn_director = (
		get_tree().get_first_node_in_group(
			"spawn_director"
		)
		as SpawnDirector
	)

	enemy_tracker = (
		get_tree().get_first_node_in_group(
			"enemy_tracker"
		)
		as EnemyTracker
	)

	stage_definition = GameContent.get_stage(
		ACTIVE_STAGE_ID
	)

	if not is_instance_valid(spawn_director):
		push_error(
			"WaveDirector could not find SpawnDirector."
		)
		return

	if not spawn_director.is_ready_to_spawn():
		push_error(
			"WaveDirector found SpawnDirector without valid "
			+ "scene references."
		)
		return

	if not is_instance_valid(enemy_tracker):
		push_error(
			"WaveDirector could not find EnemyTracker."
		)
		return

	if not is_instance_valid(stage_definition):
		push_error(
			"WaveDirector could not load active Stage '%s'."
			% ACTIVE_STAGE_ID
		)
		return

	if stage_definition.waves.is_empty():
		push_error(
			"WaveDirector active Stage '%s' has no Wave templates."
			% ACTIVE_STAGE_ID
		)
		return

	if not stage_definition.is_valid_definition():
		push_error(
			"WaveDirector loaded an invalid active Stage '%s'."
			% ACTIVE_STAGE_ID
		)
		return

	if not _load_enemy_definitions():
		return

	_initialized = true


func _load_enemy_definitions() -> bool:
	enemy_definitions_by_id.clear()

	for wave_definition in stage_definition.waves:
		if (
			not is_instance_valid(wave_definition)
			or not wave_definition.is_valid_definition()
		):
			push_error(
				(
					"WaveDirector active Stage '%s' contains an "
					+ "invalid WaveDefinition."
				)
				% ACTIVE_STAGE_ID
			)
			return false

		for enemy_id in wave_definition.enemy_ids:
			if enemy_definitions_by_id.has(enemy_id):
				continue

			var loaded_enemy_definition: EnemyDefinition = (
				GameContent.get_enemy(enemy_id)
			)

			if not is_instance_valid(loaded_enemy_definition):
				push_error(
					(
						"WaveDirector Wave '%s' references missing "
						+ "EnemyDefinition '%s'."
					)
					% [
						wave_definition.wave_id,
						enemy_id
					]
				)
				return false

			if not loaded_enemy_definition.is_valid_definition():
				push_error(
					(
						"WaveDirector Wave '%s' references invalid "
						+ "EnemyDefinition '%s'."
					)
					% [
						wave_definition.wave_id,
						enemy_id
					]
				)
				return false

			if not is_instance_valid(
				loaded_enemy_definition.enemy_scene
			):
				push_error(
					(
						"WaveDirector EnemyDefinition '%s' has no "
						+ "valid enemy scene."
					)
					% enemy_id
				)
				return false

			enemy_definitions_by_id[enemy_id] = (
				loaded_enemy_definition
			)

	if enemy_definitions_by_id.is_empty():
		push_error(
			"WaveDirector active Stage '%s' has no enemies."
			% ACTIVE_STAGE_ID
		)
		return false

	return true


func _exit_tree() -> void:
	_wave_cycle_id += 1
	_cycle_running = false


func is_ready_to_run() -> bool:
	return (
		_initialized
		and is_inside_tree()
		and is_instance_valid(spawn_director)
		and spawn_director.is_ready_to_spawn()
		and is_instance_valid(enemy_tracker)
		and is_instance_valid(stage_definition)
		and stage_definition.is_valid_definition()
		and not enemy_definitions_by_id.is_empty()
	)


func start_cycle(
	retry_current_wave: bool = false
) -> bool:
	if not is_ready_to_run():
		push_error(
			"WaveDirector is not ready to start a wave cycle."
		)
		return false

	_wave_cycle_id += 1
	_cycle_running = true

	var new_cycle_id: int = _wave_cycle_id

	_run_wave_loop(
		new_cycle_id,
		retry_current_wave
	)

	return true


func cancel_cycle(
	clear_message: bool = true
) -> void:
	_wave_cycle_id += 1
	_cycle_running = false

	if clear_message:
		wave_message_changed.emit("")


func restart_current_stage() -> bool:
	var stage_start_wave: int = (
		get_current_stage_start_wave()
	)

	cancel_cycle(true)
	current_wave = stage_start_wave - 1

	return start_cycle(false)


func is_cycle_active(
	cycle_id: int
) -> bool:
	return (
		is_inside_tree()
		and _initialized
		and _cycle_running
		and cycle_id == _wave_cycle_id
	)


func get_current_wave() -> int:
	return current_wave


func get_highest_completed_wave() -> int:
	return highest_completed_wave


func get_current_stage_definition() -> StageDefinition:
	return stage_definition


func has_wave_for_global_wave(
	global_wave: int
) -> bool:
	if (
		not is_instance_valid(stage_definition)
		or not stage_definition.is_valid_definition()
	):
		return false

	var safe_global_wave: int = max(
		global_wave,
		1
	)
	var stage_wave_count: int = (
		stage_definition.get_wave_count()
	)

	if (
		not stage_definition.repeat_indefinitely
		and safe_global_wave > stage_wave_count
	):
		return false

	var wave_index_in_stage: int = (
		safe_global_wave - 1
	)

	if stage_definition.repeat_indefinitely:
		wave_index_in_stage %= stage_wave_count

	return is_instance_valid(
		stage_definition.get_wave_for_stage_index(
			wave_index_in_stage
		)
	)


func get_current_wave_definition() -> WaveDefinition:
	if not has_wave_for_global_wave(current_wave):
		return null

	var safe_current_wave: int = max(
		current_wave,
		1
	)
	var wave_index_in_stage: int = (
		safe_current_wave - 1
	)

	if stage_definition.repeat_indefinitely:
		wave_index_in_stage %= (
			stage_definition.get_wave_count()
		)

	return stage_definition.get_wave_for_stage_index(
		wave_index_in_stage
	)


func get_safe_waves_per_stage() -> int:
	if not is_instance_valid(stage_definition):
		return 1

	return stage_definition.get_wave_count()


func get_current_stage_number() -> int:
	var safe_current_wave: int = max(
		current_wave,
		1
	)

	return int(
		floor(
			float(safe_current_wave - 1)
			/ float(get_safe_waves_per_stage())
		)
	) + 1


func get_current_wave_in_stage() -> int:
	var safe_current_wave: int = max(
		current_wave,
		1
	)

	return (
		(safe_current_wave - 1)
		% get_safe_waves_per_stage()
	) + 1


func get_current_stage_start_wave() -> int:
	var current_stage: int = (
		get_current_stage_number()
	)

	return (
		(current_stage - 1)
		* get_safe_waves_per_stage()
		+ 1
	)


func get_enemy_definition(
	enemy_id: StringName
) -> EnemyDefinition:
	return enemy_definitions_by_id.get(
		enemy_id
	) as EnemyDefinition


func get_current_enemies_per_side() -> int:
	var wave_definition: WaveDefinition = (
		get_current_wave_definition()
	)

	if (
		not is_instance_valid(stage_definition)
		or not is_instance_valid(wave_definition)
	):
		return 0

	var total_enemy_count: int = 0

	for enemy_id in wave_definition.enemy_ids:
		total_enemy_count += (
			stage_definition.get_enemy_count_for_global_wave(
				wave_definition,
				enemy_id,
				current_wave
			)
		)

	return max(
		total_enemy_count,
		0
	)


func get_current_enemy_health() -> float:
	var wave_definition: WaveDefinition = (
		get_current_wave_definition()
	)

	if (
		not is_instance_valid(wave_definition)
		or wave_definition.enemy_ids.is_empty()
	):
		return 1.0

	return get_current_enemy_health_for_id(
		wave_definition.enemy_ids[0]
	)


func get_current_enemy_health_for_id(
	enemy_id: StringName
) -> float:
	var wave_definition: WaveDefinition = (
		get_current_wave_definition()
	)
	var loaded_enemy_definition: EnemyDefinition = (
		get_enemy_definition(enemy_id)
	)

	if (
		not is_instance_valid(stage_definition)
		or not is_instance_valid(wave_definition)
		or not wave_definition.enemy_ids.has(enemy_id)
		or not is_instance_valid(loaded_enemy_definition)
	):
		return 1.0

	return stage_definition.get_enemy_health_for_global_wave(
		wave_definition,
		loaded_enemy_definition,
		current_wave
	)


func is_cycle_running() -> bool:
	return _cycle_running


func _run_wave_loop(
	cycle_id: int,
	retry_current_wave: bool
) -> void:
	var repeat_wave: bool = retry_current_wave

	while is_cycle_active(cycle_id):
		if not repeat_wave:
			current_wave += 1

		repeat_wave = false

		var wave_definition: WaveDefinition = (
			get_current_wave_definition()
		)

		if not is_instance_valid(wave_definition):
			_cycle_running = false

			if (
				is_instance_valid(stage_definition)
				and not stage_definition.repeat_indefinitely
				and current_wave
				> stage_definition.get_wave_count()
			):
				return

			push_error(
				(
					"WaveDirector could not resolve a "
					+ "WaveDefinition for global Wave %d."
				)
				% current_wave
			)
			return

		var enemy_count: int = (
			get_current_enemies_per_side()
		)
		var displayed_enemy_health: float = (
			get_current_enemy_health()
		)

		wave_changed.emit(
			current_wave,
			enemy_count
		)

		print(
			"Začíná Stage ",
			get_current_stage_number(),
			" | Wave ",
			get_current_wave_in_stage(),
			"/",
			get_safe_waves_per_stage(),
			" | globální vlna ",
			current_wave,
			" | nepřátel na každé straně: ",
			enemy_count,
			" | HP nepřítele: ",
			displayed_enemy_health
		)

		var spawn_requests: Array[EnemySpawnRequest] = []

		for enemy_id in wave_definition.enemy_ids:
			if not is_cycle_active(cycle_id):
				return

			var loaded_enemy_definition: EnemyDefinition = (
				get_enemy_definition(enemy_id)
			)

			if not is_instance_valid(loaded_enemy_definition):
				push_error(
					(
						"WaveDirector could not resolve EnemyDefinition "
						+ "'%s' for Wave '%s'."
					)
					% [
						enemy_id,
						wave_definition.wave_id
					]
				)

				if cycle_id == _wave_cycle_id:
					_cycle_running = false

				return

			var enemy_count_for_type: int = (
				stage_definition.get_enemy_count_for_global_wave(
					wave_definition,
					enemy_id,
					current_wave
				)
			)

			if enemy_count_for_type < 1:
				continue

			var enemy_health: float = (
				stage_definition.get_enemy_health_for_global_wave(
					wave_definition,
					loaded_enemy_definition,
					current_wave
				)
			)

			spawn_requests.append(
				EnemySpawnRequest.new(
					loaded_enemy_definition,
					enemy_count_for_type,
					enemy_health,
					wave_definition.damage_multiplier
				)
			)

		if spawn_requests.is_empty():
			push_error(
				(
					"WaveDirector Wave '%s' produced no valid "
					+ "spawn requests."
				)
				% wave_definition.wave_id
			)

			if cycle_id == _wave_cycle_id:
				_cycle_running = false

			return

		var spawn_completed: bool = await (
			spawn_director.spawn_wave(
				spawn_requests,
				wave_definition.spawn_interval,
				is_cycle_active.bind(cycle_id)
			)
		)

		if not spawn_completed:
			if cycle_id == _wave_cycle_id:
				_cycle_running = false

			return

		if not is_cycle_active(cycle_id):
			return

		await _wait_until_all_enemies_are_dead(
			cycle_id
		)

		if not is_cycle_active(cycle_id):
			return

		_complete_wave()

		await _show_wave_complete_message(
			cycle_id,
			wave_definition
		)

		if not is_cycle_active(cycle_id):
			return

		var safe_time_after_wave: float = max(
			wave_definition.time_after_wave,
			0.0
		)

		if safe_time_after_wave > 0.0:
			await get_tree().create_timer(
				safe_time_after_wave
			).timeout

		if not is_cycle_active(cycle_id):
			return


func _wait_until_all_enemies_are_dead(
	cycle_id: int
) -> void:
	if not is_instance_valid(enemy_tracker):
		await _wait_until_all_enemies_are_dead_fallback(
			cycle_id
		)
		return

	if not enemy_tracker.has_enemies():
		return

	await enemy_tracker.enemies_cleared

	if not is_cycle_active(cycle_id):
		return


func _wait_until_all_enemies_are_dead_fallback(
	cycle_id: int
) -> void:
	while is_cycle_active(cycle_id):
		if get_tree().get_nodes_in_group(
			"enemies"
		).is_empty():
			return

		await get_tree().process_frame


func _complete_wave() -> void:
	print(
		"Stage ",
		get_current_stage_number(),
		" | Wave ",
		get_current_wave_in_stage(),
		" dokončena"
	)

	if current_wave <= highest_completed_wave:
		return

	highest_completed_wave = current_wave

	new_highest_wave_completed.emit(
		current_wave
	)


func _show_wave_complete_message(
	cycle_id: int,
	wave_definition: WaveDefinition
) -> void:
	if not is_cycle_active(cycle_id):
		return

	wave_message_changed.emit(
		"WAVE %d COMPLETE"
		% get_current_wave_in_stage()
	)

	var safe_message_duration: float = max(
		wave_definition.completion_message_duration,
		0.0
	)

	if safe_message_duration > 0.0:
		await get_tree().create_timer(
			safe_message_duration
		).timeout

	if not is_cycle_active(cycle_id):
		return

	wave_message_changed.emit("")
