class_name LaneRegistry
extends Node


signal lane_queue_changed(
	formation_side: int,
	lane_index: int
)


const RECORD_ENEMY: StringName = &"enemy"
const RECORD_FORMATION_SIDE: StringName = &"formation_side"
const RECORD_LANE_INDEX: StringName = &"lane_index"
const RECORD_QUEUE_ORDER: StringName = &"queue_order"
const RECORD_LANE_KEY: StringName = &"lane_key"


var _enemy_records_by_instance_id: Dictionary = {}
var _lane_instance_ids_by_key: Dictionary = {}
var _queue_columns_by_instance_id: Dictionary = {}


func _ready() -> void:
	add_to_group("lane_registry")


func register_enemy(
	enemy: Node,
	formation_side: float,
	lane_index: int,
	queue_order: int
) -> void:
	if not is_instance_valid(enemy):
		return

	var normalized_side: int = (
		_normalize_formation_side(formation_side)
	)

	if (
		normalized_side == 0
		or lane_index < 0
		or queue_order < 0
	):
		push_warning(
			"LaneRegistry rejected enemy '%s': "
			% enemy.name
			+ "formation side must be non-zero, and "
			+ "lane index and queue order must be non-negative."
		)
		return

	var instance_id: int = enemy.get_instance_id()
	var lane_key := Vector2i(
		normalized_side,
		lane_index
	)

	if _enemy_records_by_instance_id.has(instance_id):
		var previous_record: Dictionary = (
			_enemy_records_by_instance_id[instance_id]
		)

		if _record_matches_registration(
			previous_record,
			normalized_side,
			lane_index,
			queue_order
		):
			return

		var previous_lane_key: Vector2i = (
			previous_record.get(
				RECORD_LANE_KEY,
				Vector2i.ZERO
			)
		)

		_remove_instance_id_from_lane(
			previous_lane_key,
			instance_id
		)
		_queue_columns_by_instance_id.erase(
			instance_id
		)
		_enemy_records_by_instance_id.erase(
			instance_id
		)

		if previous_lane_key != lane_key:
			_recalculate_lane(previous_lane_key)
			_emit_lane_queue_changed(
				previous_lane_key
			)

	var exit_callback: Callable = (
		_on_enemy_tree_exiting.bind(instance_id)
	)

	if not enemy.tree_exiting.is_connected(
		exit_callback
	):
		enemy.tree_exiting.connect(
			exit_callback,
			CONNECT_ONE_SHOT
		)

	_enemy_records_by_instance_id[instance_id] = {
		RECORD_ENEMY: enemy,
		RECORD_FORMATION_SIDE: normalized_side,
		RECORD_LANE_INDEX: lane_index,
		RECORD_QUEUE_ORDER: queue_order,
		RECORD_LANE_KEY: lane_key,
	}

	_add_instance_id_to_lane(
		lane_key,
		instance_id
	)
	_recalculate_lane(lane_key)
	_emit_lane_queue_changed(lane_key)


func unregister_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return

	_unregister_enemy_by_instance_id(
		enemy.get_instance_id()
	)


func is_enemy_registered(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false

	return _enemy_records_by_instance_id.has(
		enemy.get_instance_id()
	)


func get_queue_column(enemy: Node) -> int:
	if not is_enemy_registered(enemy):
		return -1

	return int(
		_queue_columns_by_instance_id.get(
			enemy.get_instance_id(),
			-1
		)
	)


func is_front_enemy(enemy: Node) -> bool:
	return get_queue_column(enemy) == 0


func get_lane_enemy_count(
	formation_side: float,
	lane_index: int
) -> int:
	return get_lane_enemies(
		formation_side,
		lane_index
	).size()


func get_lane_enemies(
	formation_side: float,
	lane_index: int
) -> Array[Node]:
	var enemies: Array[Node] = []
	var normalized_side: int = (
		_normalize_formation_side(formation_side)
	)

	if normalized_side == 0 or lane_index < 0:
		return enemies

	var lane_key := Vector2i(
		normalized_side,
		lane_index
	)

	if not _lane_instance_ids_by_key.has(lane_key):
		return enemies

	var lane_instance_ids: Array[int] = (
		_lane_instance_ids_by_key[lane_key]
	)

	for instance_id in lane_instance_ids:
		if not _enemy_records_by_instance_id.has(
			instance_id
		):
			continue

		var enemy_record: Dictionary = (
			_enemy_records_by_instance_id[instance_id]
		)
		var enemy: Node = (
			enemy_record.get(RECORD_ENEMY)
			as Node
		)

		if is_instance_valid(enemy):
			enemies.append(enemy)

	return enemies


func _on_enemy_tree_exiting(
	instance_id: int
) -> void:
	_unregister_enemy_by_instance_id(instance_id)


func _unregister_enemy_by_instance_id(
	instance_id: int
) -> void:
	if not _enemy_records_by_instance_id.has(
		instance_id
	):
		return

	var enemy_record: Dictionary = (
		_enemy_records_by_instance_id[instance_id]
	)
	var lane_key: Vector2i = enemy_record.get(
		RECORD_LANE_KEY,
		Vector2i.ZERO
	)

	_enemy_records_by_instance_id.erase(instance_id)
	_queue_columns_by_instance_id.erase(instance_id)
	_remove_instance_id_from_lane(
		lane_key,
		instance_id
	)
	_recalculate_lane(lane_key)
	_emit_lane_queue_changed(lane_key)


func _add_instance_id_to_lane(
	lane_key: Vector2i,
	instance_id: int
) -> void:
	var lane_instance_ids: Array[int] = []

	if _lane_instance_ids_by_key.has(lane_key):
		lane_instance_ids = (
			_lane_instance_ids_by_key[lane_key]
		)

	if not lane_instance_ids.has(instance_id):
		lane_instance_ids.append(instance_id)

	_lane_instance_ids_by_key[lane_key] = (
		lane_instance_ids
	)


func _remove_instance_id_from_lane(
	lane_key: Vector2i,
	instance_id: int
) -> void:
	if not _lane_instance_ids_by_key.has(lane_key):
		return

	var lane_instance_ids: Array[int] = (
		_lane_instance_ids_by_key[lane_key]
	)

	lane_instance_ids.erase(instance_id)

	if lane_instance_ids.is_empty():
		_lane_instance_ids_by_key.erase(lane_key)
		return

	_lane_instance_ids_by_key[lane_key] = (
		lane_instance_ids
	)


func _recalculate_lane(lane_key: Vector2i) -> void:
	if not _lane_instance_ids_by_key.has(lane_key):
		return

	var lane_instance_ids: Array[int] = (
		_lane_instance_ids_by_key[lane_key]
	)
	var valid_instance_ids: Array[int] = []

	for instance_id in lane_instance_ids:
		_queue_columns_by_instance_id.erase(instance_id)

		if not _enemy_records_by_instance_id.has(
			instance_id
		):
			continue

		var enemy_record: Dictionary = (
			_enemy_records_by_instance_id[instance_id]
		)
		var enemy: Node = (
			enemy_record.get(RECORD_ENEMY)
			as Node
		)

		if not is_instance_valid(enemy):
			_enemy_records_by_instance_id.erase(
				instance_id
			)
			continue

		if enemy_record.get(
			RECORD_LANE_KEY,
			Vector2i.ZERO
		) != lane_key:
			continue

		valid_instance_ids.append(instance_id)

	if valid_instance_ids.is_empty():
		_lane_instance_ids_by_key.erase(lane_key)
		return

	valid_instance_ids.sort_custom(
		_is_instance_id_before
	)

	_lane_instance_ids_by_key[lane_key] = (
		valid_instance_ids
	)

	for column in range(valid_instance_ids.size()):
		_queue_columns_by_instance_id[
			valid_instance_ids[column]
		] = column


func _is_instance_id_before(
	first_instance_id: int,
	second_instance_id: int
) -> bool:
	var first_record: Dictionary = (
		_enemy_records_by_instance_id.get(
			first_instance_id,
			{}
		)
	)
	var second_record: Dictionary = (
		_enemy_records_by_instance_id.get(
			second_instance_id,
			{}
		)
	)
	var first_queue_order: int = int(
		first_record.get(RECORD_QUEUE_ORDER, 0)
	)
	var second_queue_order: int = int(
		second_record.get(RECORD_QUEUE_ORDER, 0)
	)

	if first_queue_order != second_queue_order:
		return first_queue_order < second_queue_order

	return first_instance_id < second_instance_id


func _record_matches_registration(
	enemy_record: Dictionary,
	normalized_side: int,
	lane_index: int,
	queue_order: int
) -> bool:
	return (
		int(
			enemy_record.get(
				RECORD_FORMATION_SIDE,
				0
			)
		) == normalized_side
		and int(
			enemy_record.get(RECORD_LANE_INDEX, -1)
		) == lane_index
		and int(
			enemy_record.get(RECORD_QUEUE_ORDER, -1)
		) == queue_order
	)


func _emit_lane_queue_changed(
	lane_key: Vector2i
) -> void:
	lane_queue_changed.emit(
		lane_key.x,
		lane_key.y
	)


func _normalize_formation_side(
	formation_side: float
) -> int:
	return int(sign(formation_side))
