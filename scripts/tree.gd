extends Node2D


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
