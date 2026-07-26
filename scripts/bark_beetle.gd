extends CharacterBody2D


@export var move_speed: float = 120.0
@export var target_x: float = 960.0
@export var stopping_distance: float = 130.0


func _physics_process(_delta: float) -> void:
	var distance_to_target: float = target_x - global_position.x

	if abs(distance_to_target) <= stopping_distance:
		velocity = Vector2.ZERO
		return

	var direction: float = sign(distance_to_target)
	velocity = Vector2(direction * move_speed, 0.0)

	move_and_slide()


func _draw() -> void:
	# Dočasné tělo brouka.
	draw_circle(
		Vector2.ZERO,
		32.0,
		Color("3a2118")
	)

	# Dočasná tykadla.
	draw_line(
		Vector2(-12, -22),
		Vector2(-25, -38),
		Color("3a2118"),
		5.0
	)

	draw_line(
		Vector2(12, -22),
		Vector2(25, -38),
		Color("3a2118"),
		5.0
	)
