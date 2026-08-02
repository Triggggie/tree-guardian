class_name EnemyHealthComponent
extends Node


signal health_changed(
	current_health: float,
	maximum_health: float
)

signal depleted(
	damage_source: Node
)


var _maximum_health: float = 1.0
var _current_health: float = 1.0
var _initialized: bool = false


func initialize(
	maximum_health: float
) -> void:
	_maximum_health = max(
		maximum_health,
		1.0
	)
	_current_health = _maximum_health
	_initialized = true

	health_changed.emit(
		_current_health,
		_maximum_health
	)


func apply_damage(
	amount: float,
	damage_source: Node = null
) -> bool:
	if not _initialized:
		return false

	if amount <= 0.0:
		return false

	if _current_health <= 0.0:
		return false

	_current_health = max(
		_current_health - amount,
		0.0
	)

	health_changed.emit(
		_current_health,
		_maximum_health
	)

	if _current_health <= 0.0:
		depleted.emit(damage_source)

	return true


func is_initialized() -> bool:
	return _initialized


func is_depleted() -> bool:
	return (
		_initialized
		and _current_health <= 0.0
	)


func get_current_health() -> float:
	return _current_health


func get_maximum_health() -> float:
	return _maximum_health


func get_health_ratio() -> float:
	if not _initialized:
		return 0.0

	return clamp(
		_current_health / _maximum_health,
		0.0,
		1.0
	)
