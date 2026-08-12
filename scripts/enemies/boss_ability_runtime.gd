class_name BossAbilityRuntime
extends Node


signal telegraph_started(ability_id: StringName, phase: int)
signal pulse_executed(ability_id: StringName, phase: int, pulse_index: int)
signal ability_finished(ability_id: StringName, phase: int)
signal phase_changed(new_phase: int)


class TelegraphVisual:
	extends Node2D

	var ring_count: int = 1
	var radius: float = 72.0
	var ring_color: Color = Color(0.85, 0.28, 0.08, 0.72)

	func configure(
		new_ring_count: int,
		new_radius: float,
		new_color: Color
	) -> void:
		ring_count = max(new_ring_count, 1)
		radius = max(new_radius, 8.0)
		ring_color = new_color
		queue_redraw()

	func _draw() -> void:
		var ground_center := Vector2(0.0, 32.0)
		draw_circle(
			ground_center,
			radius,
			Color(ring_color.r, ring_color.g, ring_color.b, ring_color.a * 0.16)
		)
		for ring_index in range(ring_count):
			var ring_radius: float = radius * (
				1.0 - float(ring_index) * 0.22
			)
			draw_arc(
				ground_center,
				ring_radius,
				0.0,
				TAU,
				64,
				ring_color,
				4.0,
				true
			)


const CAST_RETRY_DELAY: float = 0.10
const PHASE_TRANSITION_DURATION: float = 0.40


var ability_definition: BossAbilityDefinition
var enemy: CharacterBody2D
var health_component: EnemyHealthComponent
var attack_component: EnemyAttackComponent
var movement_component: EnemyMovementComponent
var cooldown_timer: Timer
var telegraph_timer: Timer
var pulse_timer: Timer
var current_phase: int = 1
var cast_phase: int = 1
var ability_running: bool = false
var cancelled: bool = false
var executed_pulse_count: int = 0
var pending_pulse_count: int = 0
var telegraph_visual: TelegraphVisual
var telegraph_tween: Tween
var phase_visual: TelegraphVisual
var phase_tween: Tween


func configure(definition: BossAbilityDefinition) -> bool:
	if (
		not is_instance_valid(definition)
		or not definition.is_valid_definition()
	):
		return false
	ability_definition = definition
	return true


func _ready() -> void:
	cooldown_timer = create_runtime_timer("CooldownTimer", _on_cooldown_timeout)
	telegraph_timer = create_runtime_timer("TelegraphTimer", _on_telegraph_timeout)
	pulse_timer = create_runtime_timer("PulseTimer", _on_pulse_timeout)
	call_deferred("_initialize_runtime")


func _exit_tree() -> void:
	cancel_runtime()


func create_runtime_timer(timer_name: String, callback: Callable) -> Timer:
	var timer := Timer.new()
	timer.name = timer_name
	timer.one_shot = true
	timer.timeout.connect(callback)
	add_child(timer)
	return timer


func _initialize_runtime() -> void:
	if cancelled or not is_instance_valid(ability_definition):
		return
	enemy = get_parent() as CharacterBody2D
	if not is_instance_valid(enemy):
		cancel_runtime()
		return
	health_component = enemy.get_node_or_null("HealthComponent") as EnemyHealthComponent
	attack_component = enemy.get_node_or_null("AttackComponent") as EnemyAttackComponent
	movement_component = enemy.get_node_or_null("MovementComponent") as EnemyMovementComponent
	if (
		not is_instance_valid(health_component)
		or not is_instance_valid(attack_component)
		or not is_instance_valid(movement_component)
	):
		cancel_runtime()
		return
	if not health_component.health_changed.is_connected(_on_health_changed):
		health_component.health_changed.connect(_on_health_changed)
	cooldown_timer.start(ability_definition.initial_delay)


func _on_cooldown_timeout() -> void:
	if cancelled:
		return
	if not can_start_ability():
		cooldown_timer.start(CAST_RETRY_DELAY)
		return
	start_ability()


func can_start_ability() -> bool:
	if ability_running or not is_instance_valid(enemy):
		return false
	if bool(enemy.get("is_dying")) or not bool(enemy.get("combat_enabled")):
		return false
	if not is_instance_valid(health_component) or health_component.is_depleted():
		return false
	var target_tree: Node2D = enemy.get("target_tree") as Node2D
	if not is_instance_valid(target_tree) or not target_tree.has_method("take_damage"):
		return false
	if not movement_component.is_formation_configured():
		return false
	if int(enemy.call("get_current_queue_column")) != 0:
		return false
	var maximum_range: float = (
		float(enemy.get("stopping_distance"))
		+ float(enemy.get("arrival_distance"))
		+ 2.0
	)
	return abs(enemy.global_position.x - target_tree.global_position.x) <= maximum_range


func start_ability() -> void:
	ability_running = true
	cast_phase = current_phase
	executed_pulse_count = 0
	pending_pulse_count = get_pulse_count_for_phase(cast_phase)
	attack_component.set_enabled(false)
	attack_component.stop_attacking()
	create_telegraph_visual()
	telegraph_timer.start(get_telegraph_duration_for_phase(cast_phase))
	telegraph_started.emit(ability_definition.ability_id, cast_phase)


func create_telegraph_visual() -> void:
	destroy_telegraph_visual()
	telegraph_visual = TelegraphVisual.new()
	telegraph_visual.name = "TelegraphVisual"
	telegraph_visual.configure(
		ability_definition.telegraph_ring_count,
		ability_definition.telegraph_radius,
		ability_definition.telegraph_color
	)
	enemy.add_child(telegraph_visual)
	telegraph_visual.scale = Vector2(0.72, 0.72)
	telegraph_visual.modulate.a = 0.25
	telegraph_tween = create_tween()
	telegraph_tween.set_parallel(true)
	telegraph_tween.set_trans(Tween.TRANS_QUAD)
	telegraph_tween.set_ease(Tween.EASE_OUT)
	telegraph_tween.tween_property(
		telegraph_visual,
		"scale",
		Vector2.ONE,
		get_telegraph_duration_for_phase(cast_phase)
	)
	telegraph_tween.tween_property(
		telegraph_visual,
		"modulate:a",
		1.0,
		get_telegraph_duration_for_phase(cast_phase)
	)


func _on_telegraph_timeout() -> void:
	if not is_execution_valid():
		finish_ability(false)
		return
	execute_current_pulse()


func _on_pulse_timeout() -> void:
	if not is_execution_valid():
		finish_ability(false)
		return
	execute_current_pulse()


func execute_current_pulse() -> void:
	var target_tree: Node2D = enemy.get("target_tree") as Node2D
	if not is_instance_valid(target_tree):
		finish_ability(false)
		return
	executed_pulse_count += 1
	pending_pulse_count = max(pending_pulse_count - 1, 0)
	target_tree.call("take_damage", get_pulse_damage_for_phase(cast_phase))
	pulse_executed.emit(
		ability_definition.ability_id,
		cast_phase,
		executed_pulse_count
	)
	if pending_pulse_count > 0:
		pulse_timer.start(ability_definition.phase_two_pulse_delay)
		return
	finish_ability(true)


func is_execution_valid() -> bool:
	return (
		not cancelled
		and ability_running
		and is_instance_valid(enemy)
		and not bool(enemy.get("is_dying"))
		and bool(enemy.get("combat_enabled"))
		and is_instance_valid(health_component)
		and not health_component.is_depleted()
	)


func finish_ability(completed: bool) -> void:
	if not ability_running:
		return
	var finished_phase: int = cast_phase
	ability_running = false
	pending_pulse_count = 0
	telegraph_timer.stop()
	pulse_timer.stop()
	destroy_telegraph_visual()
	if completed:
		ability_finished.emit(ability_definition.ability_id, finished_phase)
	if cancelled or not is_instance_valid(enemy):
		return
	if bool(enemy.get("combat_enabled")) and not bool(enemy.get("is_dying")):
		attack_component.set_enabled(true)
		cooldown_timer.start(get_cooldown_for_phase(current_phase))


func cancel_runtime() -> void:
	if cancelled:
		return
	cancelled = true
	ability_running = false
	pending_pulse_count = 0
	if is_instance_valid(cooldown_timer):
		cooldown_timer.stop()
	if is_instance_valid(telegraph_timer):
		telegraph_timer.stop()
	if is_instance_valid(pulse_timer):
		pulse_timer.stop()
	destroy_telegraph_visual()
	destroy_phase_visual()


func destroy_telegraph_visual() -> void:
	if is_instance_valid(telegraph_tween):
		telegraph_tween.kill()
	telegraph_tween = null
	if is_instance_valid(telegraph_visual):
		telegraph_visual.queue_free()
	telegraph_visual = null


func _on_health_changed(current_health: float, maximum_health: float) -> void:
	if cancelled or current_phase >= 2:
		return
	if not ability_definition.has_phase_two() or maximum_health <= 0.0:
		return
	if current_health <= 0.0:
		return
	if current_health / maximum_health > ability_definition.phase_two_health_ratio:
		return
	current_phase = 2
	phase_changed.emit(current_phase)
	play_phase_transition()


func play_phase_transition() -> void:
	destroy_phase_visual()
	phase_visual = TelegraphVisual.new()
	phase_visual.name = "PhaseTransitionVisual"
	phase_visual.configure(
		2,
		ability_definition.telegraph_radius * 0.85,
		Color(0.95, 0.38, 0.10, 0.86)
	)
	enemy.add_child(phase_visual)
	phase_visual.scale = Vector2(0.45, 0.45)
	phase_tween = create_tween()
	phase_tween.set_parallel(true)
	phase_tween.set_trans(Tween.TRANS_QUAD)
	phase_tween.set_ease(Tween.EASE_OUT)
	phase_tween.tween_property(
		phase_visual,
		"scale",
		Vector2(1.2, 1.2),
		PHASE_TRANSITION_DURATION
	)
	phase_tween.tween_property(
		phase_visual,
		"modulate:a",
		0.0,
		PHASE_TRANSITION_DURATION
	)
	phase_tween.set_parallel(false)
	phase_tween.tween_callback(destroy_phase_visual)


func destroy_phase_visual() -> void:
	if is_instance_valid(phase_tween):
		phase_tween.kill()
	phase_tween = null
	if is_instance_valid(phase_visual):
		phase_visual.queue_free()
	phase_visual = null


func get_cooldown_for_phase(phase: int) -> float:
	if phase >= 2 and ability_definition.has_phase_two():
		return ability_definition.phase_two_cooldown
	return ability_definition.cooldown


func get_telegraph_duration_for_phase(phase: int) -> float:
	if phase >= 2 and ability_definition.has_phase_two():
		return ability_definition.phase_two_telegraph_duration
	return ability_definition.telegraph_duration


func get_pulse_damage_for_phase(phase: int) -> float:
	if phase >= 2 and ability_definition.has_phase_two():
		return ability_definition.phase_two_pulse_damage
	return ability_definition.damage


func get_pulse_count_for_phase(phase: int) -> int:
	if phase >= 2 and ability_definition.has_phase_two():
		return ability_definition.phase_two_pulse_count
	return 1


func is_ability_running() -> bool:
	return ability_running


func get_current_phase() -> int:
	return current_phase


func get_executed_pulse_count() -> int:
	return executed_pulse_count


func has_active_telegraph() -> bool:
	return is_instance_valid(telegraph_visual)
