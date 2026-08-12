class_name BossAbilityDefinition
extends Resource


@export_category("Identity")
@export var ability_id: StringName = &""
@export var display_name: String = "Boss Ability"

@export_category("Phase 1")
@export_range(0.01, 3600.0, 0.01)
var initial_delay: float = 3.0
@export_range(0.01, 3600.0, 0.01)
var cooldown: float = 7.0
@export_range(0.01, 30.0, 0.01)
var telegraph_duration: float = 0.9
@export_range(0.0, 1000000000.0, 0.1)
var damage: float = 8.0

@export_category("Phase 2")
@export_range(0.0, 1.0, 0.01)
var phase_two_health_ratio: float = 0.0
@export_range(0.01, 3600.0, 0.01)
var phase_two_cooldown: float = 6.0
@export_range(0.01, 30.0, 0.01)
var phase_two_telegraph_duration: float = 1.0
@export_range(0.0, 1000000000.0, 0.1)
var phase_two_pulse_damage: float = 10.0
@export_range(1, 10, 1)
var phase_two_pulse_count: int = 1
@export_range(0.01, 30.0, 0.01)
var phase_two_pulse_delay: float = 0.35

@export_category("Telegraph")
@export_range(1, 4, 1)
var telegraph_ring_count: int = 1
@export_range(8.0, 500.0, 1.0)
var telegraph_radius: float = 72.0
@export var telegraph_color: Color = Color(0.85, 0.28, 0.08, 0.72)


func has_phase_two() -> bool:
	return phase_two_health_ratio > 0.0


func is_valid_definition() -> bool:
	if ability_id == &"" or display_name.strip_edges().is_empty():
		return false
	if initial_delay <= 0.0 or cooldown <= 0.0:
		return false
	if telegraph_duration <= 0.0 or damage <= 0.0:
		return false
	if telegraph_ring_count < 1 or telegraph_radius <= 0.0:
		return false
	if phase_two_health_ratio < 0.0 or phase_two_health_ratio > 1.0:
		return false
	if not has_phase_two():
		return true
	return (
		phase_two_cooldown > 0.0
		and phase_two_telegraph_duration > 0.0
		and phase_two_pulse_damage > 0.0
		and phase_two_pulse_count >= 1
		and phase_two_pulse_delay > 0.0
	)
