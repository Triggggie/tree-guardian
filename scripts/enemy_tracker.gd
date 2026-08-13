class_name EnemyTracker
extends Node


signal enemy_registered(enemy: Node)
signal enemy_unregistered(enemy: Node)
signal enemy_count_changed(enemy_count: int)
signal enemies_cleared


var _enemies_by_instance_id: Dictionary = {}
var _global_wave_by_instance_id: Dictionary = {}
var _active_enemy_count_by_global_wave: Dictionary = {}


func _ready() -> void:
	add_to_group("enemy_tracker")


func register_enemy(enemy: Node, origin_global_wave: int = 0) -> void:
	if not is_instance_valid(enemy):
		return

	var instance_id: int = enemy.get_instance_id()

	if _enemies_by_instance_id.has(instance_id):
		return

	_enemies_by_instance_id[instance_id] = enemy
	if origin_global_wave > 0:
		_global_wave_by_instance_id[instance_id] = origin_global_wave
		_active_enemy_count_by_global_wave[origin_global_wave] = (
			get_active_enemy_count_for_wave(origin_global_wave) + 1
		)

	enemy.tree_exiting.connect(
		_on_enemy_tree_exiting.bind(instance_id),
		CONNECT_ONE_SHOT
	)

	enemy_registered.emit(enemy)
	enemy_count_changed.emit(
		_enemies_by_instance_id.size()
	)


func unregister_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return

	var instance_id: int = enemy.get_instance_id()

	if not _enemies_by_instance_id.has(instance_id):
		return

	_unregister_enemy_by_instance_id(instance_id)


func get_enemy_count() -> int:
	_remove_stale_enemies()

	return _enemies_by_instance_id.size()


func get_total_active_enemy_count() -> int:
	return get_enemy_count()


func get_active_enemy_count_for_wave(global_wave: int) -> int:
	if global_wave < 1:
		return 0
	return int(_active_enemy_count_by_global_wave.get(global_wave, 0))


func has_active_enemies_for_wave(global_wave: int) -> bool:
	return get_active_enemy_count_for_wave(global_wave) > 0


func get_tracked_global_waves() -> Array[int]:
	var global_waves: Array[int] = []
	for global_wave_value in _active_enemy_count_by_global_wave:
		var global_wave: int = int(global_wave_value)
		if get_active_enemy_count_for_wave(global_wave) > 0:
			global_waves.append(global_wave)
	global_waves.sort()
	return global_waves


func has_enemies() -> bool:
	return get_enemy_count() > 0


func get_enemies() -> Array[Node]:
	_remove_stale_enemies()

	var enemies: Array[Node] = []

	for enemy_value in _enemies_by_instance_id.values():
		var enemy: Node = enemy_value as Node

		if is_instance_valid(enemy):
			enemies.append(enemy)

	return enemies


func _on_enemy_tree_exiting(
	instance_id: int
) -> void:
	_unregister_enemy_by_instance_id(instance_id)


func _remove_stale_enemies() -> void:
	var stale_instance_ids: Array[int] = []

	for instance_id_value in _enemies_by_instance_id.keys():
		var instance_id: int = int(instance_id_value)
		var enemy: Node = (
			_enemies_by_instance_id.get(instance_id)
			as Node
		)

		if not is_instance_valid(enemy):
			stale_instance_ids.append(instance_id)

	for instance_id in stale_instance_ids:
		_unregister_enemy_by_instance_id(instance_id)


func _unregister_enemy_by_instance_id(
	instance_id: int
) -> void:
	if not _enemies_by_instance_id.has(instance_id):
		return

	var enemy: Node = (
		_enemies_by_instance_id.get(instance_id)
		as Node
	)
	var global_wave: int = int(
		_global_wave_by_instance_id.get(instance_id, 0)
	)

	_enemies_by_instance_id.erase(instance_id)
	_global_wave_by_instance_id.erase(instance_id)
	if global_wave > 0:
		var remaining_count: int = max(
			get_active_enemy_count_for_wave(global_wave) - 1,
			0
		)
		if remaining_count == 0:
			_active_enemy_count_by_global_wave.erase(global_wave)
		else:
			_active_enemy_count_by_global_wave[global_wave] = remaining_count

	if is_instance_valid(enemy):
		enemy_unregistered.emit(enemy)

	enemy_count_changed.emit(
		_enemies_by_instance_id.size()
	)

	if _enemies_by_instance_id.is_empty():
		enemies_cleared.emit()
