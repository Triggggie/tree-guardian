class_name EnemyAttackComponent
extends Node


signal attack_requested


@onready var attack_timer: Timer = $AttackTimer


var _attack_damage: float = 0.0
var _attack_interval: float = 1.0
var _initialized: bool = false
var _enabled: bool = true


func _ready() -> void:
	attack_timer.timeout.connect(
		_on_attack_timer_timeout
	)


func initialize(
	attack_damage: float,
	attack_interval: float
) -> void:
	_attack_damage = max(
		attack_damage,
		0.0
	)
	_attack_interval = max(
		attack_interval,
		0.01
	)

	attack_timer.wait_time = _attack_interval
	attack_timer.stop()
	_initialized = true


func start_attacking() -> void:
	if not _initialized:
		return

	if not _enabled:
		return

	if not attack_timer.is_stopped():
		return

	attack_timer.start()


func stop_attacking() -> void:
	attack_timer.stop()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled

	if not _enabled:
		attack_timer.stop()


func _on_attack_timer_timeout() -> void:
	if (
		not _initialized
		or not _enabled
	):
		attack_timer.stop()
		return

	attack_requested.emit()


func is_initialized() -> bool:
	return _initialized


func is_enabled() -> bool:
	return _enabled


func is_attacking() -> bool:
	return not attack_timer.is_stopped()


func get_attack_damage() -> float:
	return _attack_damage


func get_attack_interval() -> float:
	return _attack_interval
