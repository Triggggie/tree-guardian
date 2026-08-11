class_name ThornBurstVisual
extends Node2D


@export_range(0.05, 1.0, 0.01) var lifetime: float = 0.20
@export_range(3, 16, 1) var spike_count: int = 8

var burst_radius: float = 90.0
var elapsed_time: float = 0.0


func setup(radius: float) -> void:
	burst_radius = max(radius, 1.0)
	elapsed_time = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	elapsed_time += max(delta, 0.0)
	if elapsed_time >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clamp(elapsed_time / max(lifetime, 0.001), 0.0, 1.0)
	var current_radius: float = burst_radius * lerp(0.25, 1.0, progress)
	var alpha: float = 1.0 - progress
	var burst_color := Color(0.66, 0.82, 0.30, alpha)

	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 32, burst_color, 4.0, true)
	for spike_index in range(spike_count):
		var angle: float = TAU * float(spike_index) / float(spike_count)
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(
			direction * current_radius * 0.62,
			direction * current_radius * 1.12,
			burst_color,
			3.0,
			true
		)
