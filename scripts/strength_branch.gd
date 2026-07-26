extends Node2D


@export var attack_angle_degrees: float = 18.0
@export var attack_duration: float = 0.12

var resting_rotation: float


func _ready() -> void:
	resting_rotation = rotation

	var cooldown_timer := $CooldownTimer
	cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)


func _draw() -> void:
	draw_line(
		Vector2.ZERO,
		Vector2(-150, 0),
		Color("6b4423"),
		24.0,
		true
	)


func _on_cooldown_timer_timeout() -> void:
	perform_attack_animation()


func perform_attack_animation() -> void:
	var attack_rotation := resting_rotation + deg_to_rad(attack_angle_degrees)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"rotation",
		attack_rotation,
		attack_duration
	)

	tween.tween_property(
		self,
		"rotation",
		resting_rotation,
		attack_duration
	)
