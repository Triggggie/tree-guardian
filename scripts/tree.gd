extends Node2D


signal forest_essence_changed(new_amount: int)
signal age_changed(new_age: int)

signal health_changed(
	current_health: float,
	maximum_health: float
)

signal died


@export_category("Health")
@export var max_health: float = 100.0

@export_category("Idle Animation")
@export_range(0.0, 0.1, 0.001)
var idle_scale_amount: float = 0.015

@export_range(0.1, 5.0, 0.1)
var idle_speed: float = 1.2

@export_category("Damage Feedback")
@export var damage_flash_duration: float = 0.08
@export var damage_shake_distance: float = 12.0
@export var damage_shake_duration: float = 0.05


var forest_essence: int = 0
var age: int = 1

var idle_time: float = 0.0
var current_health: float
var is_dead: bool = false

var resting_position: Vector2
var damage_tween: Tween


func _ready() -> void:
	add_to_group("tree")

	resting_position = position

	current_health = max_health
	health_changed.emit(
		current_health,
		max_health
	)


func _process(delta: float) -> void:
	idle_time += delta * idle_speed

	var breath: float = (
		sin(idle_time) * idle_scale_amount
	)

	scale = Vector2(
		1.0 + breath,
		1.0 - breath * 0.35
	)

	queue_redraw()


func _draw() -> void:
	draw_rect(
		Rect2(-45, -180, 90, 180),
		Color("70452d")
	)

	draw_circle(
		Vector2(0, -230),
		130,
		Color("3f8f4f")
	)


func add_forest_essence(amount: int) -> void:
	if amount <= 0:
		return

	forest_essence += amount
	forest_essence_changed.emit(forest_essence)


func add_age(amount: int) -> void:
	if amount <= 0:
		return

	age += amount
	age_changed.emit(age)

	print("Strom dosáhl věku ", age)


func take_damage(amount: float) -> void:
	if is_dead:
		return

	if amount <= 0.0:
		return

	current_health = max(
		current_health - amount,
		0.0
	)

	health_changed.emit(
		current_health,
		max_health
	)

	play_damage_feedback()

	print(
		"Strom dostal ",
		amount,
		" poškození | HP: ",
		current_health,
		"/",
		max_health
	)

	if current_health <= 0.0:
		die()


func play_damage_feedback() -> void:
	if is_instance_valid(damage_tween):
		damage_tween.kill()

	position = resting_position
	modulate = Color.WHITE

	damage_tween = create_tween()

	damage_tween.set_parallel(true)

	damage_tween.tween_property(
		self,
		"modulate",
		Color(1.0, 0.35, 0.35, 1.0),
		damage_flash_duration
	)

	damage_tween.tween_property(
		self,
		"position",
		resting_position + Vector2(
			damage_shake_distance,
			0.0
		),
		damage_shake_duration
	)

	damage_tween.set_parallel(false)

	damage_tween.tween_property(
		self,
		"position",
		resting_position - Vector2(
			damage_shake_distance,
			0.0
		),
		damage_shake_duration
	)

	damage_tween.tween_property(
		self,
		"position",
		resting_position,
		damage_shake_duration
	)

	damage_tween.tween_property(
		self,
		"modulate",
		Color.WHITE,
		damage_flash_duration
	)


func die() -> void:
	if is_dead:
		return

	is_dead = true
	died.emit()

	print("Strom zemřel")
