class_name EnemyTracker
extends Node


signal enemy_registered(enemy: Node)
signal enemy_unregistered(enemy: Node)
signal enemy_count_changed(enemy_count: int)
signal enemies_cleared


var _enemies_by_instance_id: Dictionary = {}


func _ready() -> void:
	add_to_group("enemy_tracker")


func register_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return

	var instance_id: int = enemy.get_instance_id()

	if _enemies_by_instance_id.has(instance_id):
		return

	_enemies_by_instance_id[instance_id] = enemy

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

	_enemies_by_instance_id.erase(instance_id)

	if is_instance_valid(enemy):
		enemy_unregistered.emit(enemy)

	enemy_count_changed.emit(
		_enemies_by_instance_id.size()
	)

	if _enemies_by_instance_id.is_empty():
		enemies_cleared.emit()
