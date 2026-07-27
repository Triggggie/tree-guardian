extends Node2D

signal forest_essence_changed(new_amount: int)
signal age_changed(new_age: int)

var forest_essence: int = 0
var age: int = 1

@export_range(0.0, 0.1, 0.001)
var idle_scale_amount: float = 0.015

@export_range(0.1, 5.0, 0.1)
var idle_speed: float = 1.2

var idle_time: float = 0.0

func _ready() -> void:
	add_to_group("tree")

func add_forest_essence(amount: int) -> void:
	forest_essence += amount
	forest_essence_changed.emit(forest_essence)

func _process(delta: float) -> void:
	idle_time += delta * idle_speed

	var breath: float = sin(idle_time) * idle_scale_amount

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
func add_age(amount: int) -> void:
	if amount <= 0:
		return

	age += amount
	age_changed.emit(age)

	print("Strom dosáhl věku ", age)
