class_name EnemyMovementComponent
extends Node


var _body: CharacterBody2D
var _target: Node2D
var _move_speed: float = 0.0
var _stopping_distance: float = 0.0
var _arrival_distance: float = 0.0
var _lane_change_speed: float = 0.0
var _column_spacing: float = 0.0
var _formation_side: float = 1.0
var _lane_y: float = 0.0
var _speed_multiplier: float = 1.0
var _depth_jitter: float = 0.0
var _crowd_scale_multiplier: float = 1.0
var _initialized: bool = false
var _formation_configured: bool = false
var _enabled: bool = true


func initialize(
	body: CharacterBody2D,
	target: Node2D,
	move_speed: float,
	stopping_distance: float,
	arrival_distance: float,
	lane_change_speed: float,
	column_spacing: float
) -> bool:
	if (
		not is_instance_valid(body)
		or not is_instance_valid(target)
	):
		push_error(
			"EnemyMovementComponent requires a valid body "
			+ "and target."
		)
		return false

	_body = body
	_target = target
	_move_speed = max(move_speed, 0.0)
	_stopping_distance = max(stopping_distance, 0.0)
	_arrival_distance = max(arrival_distance, 0.0)
	_lane_change_speed = max(lane_change_speed, 0.0)
	_column_spacing = max(column_spacing, 0.0)
	_initialized = true

	stop()
	return true


func configure_formation(
	formation_side: float,
	lane_y: float,
	speed_multiplier: float,
	depth_jitter: float,
	crowd_scale_multiplier: float
) -> bool:
	if not _initialized:
		push_error(
			"EnemyMovementComponent cannot configure formation "
			+ "before initialization."
		)
		return false

	if formation_side == 0.0:
		push_error(
			"EnemyMovementComponent formation side cannot be zero."
		)
		return false

	_formation_side = sign(formation_side)
	_lane_y = lane_y
	_speed_multiplier = max(speed_multiplier, 0.0)
	_depth_jitter = depth_jitter
	_crowd_scale_multiplier = max(
		crowd_scale_multiplier,
		0.01
	)
	_formation_configured = true

	_body.scale = (
		Vector2.ONE
		* _crowd_scale_multiplier
	)
	_body.z_index = int(_lane_y)

	return true


func physics_step(
	delta: float,
	queue_column: int
) -> bool:
	if (
		not _initialized
		or not _formation_configured
		or not _enabled
		or not is_instance_valid(_body)
		or not is_instance_valid(_target)
	):
		stop()
		return false

	var safe_queue_column: int = max(
		queue_column,
		0
	)

	_body.global_position.y = move_toward(
		_body.global_position.y,
		_lane_y,
		_lane_change_speed * max(delta, 0.0)
	)

	_body.z_index = int(
		_body.global_position.y
	)

	var target_x: float = get_target_x(
		safe_queue_column
	)
	var horizontal_distance: float = (
		target_x - _body.global_position.x
	)

	if abs(horizontal_distance) <= _arrival_distance:
		_body.global_position.x = target_x
		_body.velocity = Vector2.ZERO
		return true

	var movement_direction: float = sign(
		horizontal_distance
	)

	_body.velocity = Vector2(
		movement_direction
		* _move_speed
		* _speed_multiplier,
		0.0
	)

	_body.move_and_slide()
	return false


func stop() -> void:
	if not is_instance_valid(_body):
		return

	_body.velocity = Vector2.ZERO


func set_enabled(enabled: bool) -> void:
	_enabled = enabled

	if not _enabled:
		stop()


func is_initialized() -> bool:
	return _initialized


func is_formation_configured() -> bool:
	return _formation_configured


func is_enabled() -> bool:
	return _enabled


func get_formation_side() -> float:
	return _formation_side


func get_lane_y() -> float:
	return _lane_y


func get_target_x(
	queue_column: int
) -> float:
	if (
		not _initialized
		or not _formation_configured
		or not is_instance_valid(_target)
	):
		return 0.0

	var safe_queue_column: int = max(
		queue_column,
		0
	)
	var distance_from_tree: float = (
		_stopping_distance
		+ safe_queue_column * _column_spacing
		+ _depth_jitter
	)

	distance_from_tree = max(
		distance_from_tree,
		_stopping_distance - 15.0
	)

	return (
		_target.global_position.x
		+ _formation_side * distance_from_tree
	)
