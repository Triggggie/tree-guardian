extends CharacterBody2D


@export var move_speed: float = 120.0
@export var target_x: float = 960.0
@export var stopping_distance: float = 130.0
@export var max_health: float = 30.0

var current_health: float


func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health


func _physics_process(_delta: float) -> void:
	var distance_to_target: float = target_x - global_position.x

	if abs(distance_to_target) <= stopping_distance:
		velocity = Vector2.ZERO
		return

	var direction: float = sign(distance_to_target)
	velocity = Vector2(direction * move_speed, 0.0)

	move_and_slide()


func take_damage(amount: float) -> void:
	current_health -= amount

	print(
		name,
		" dostal zásah: ",
		amount,
		" | zbývá HP: ",
		current_health
	)

	if current_health <= 0.0:
		die()


func die() -> void:
	remove_from_group("enemies")
	queue_free()


func _draw() -> void:
	draw_circle(
		Vector2.ZERO,
		32.0,
		Color("3a2118")
	)

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
