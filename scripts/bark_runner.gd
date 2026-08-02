extends "res://scripts/bark_beetle.gd"


func _draw() -> void:
	var outline_color := Color("6a341d")
	var accent_color := Color("c97936")
	var highlight_color := Color("e2a05c")
	var body_points := PackedVector2Array([
		Vector2(-11.0, -18.0),
		Vector2(11.0, -18.0),
		Vector2(15.0, 8.0),
		Vector2(8.0, 22.0),
		Vector2(-8.0, 22.0),
		Vector2(-15.0, 8.0),
	])
	var outline_points := PackedVector2Array(body_points)
	outline_points.append(body_points[0])

	draw_colored_polygon(
		body_points,
		accent_color
	)
	draw_polyline(
		outline_points,
		outline_color,
		3.0,
		true
	)
	draw_circle(
		Vector2(0.0, -17.0),
		9.0,
		highlight_color
	)
	draw_line(
		Vector2(-6.0, -22.0),
		Vector2(-13.0, -32.0),
		outline_color,
		3.0
	)
	draw_line(
		Vector2(6.0, -22.0),
		Vector2(13.0, -32.0),
		outline_color,
		3.0
	)
	draw_line(
		Vector2(-12.0, -3.0),
		Vector2(-21.0, -8.0),
		outline_color,
		3.0
	)
	draw_line(
		Vector2(12.0, -3.0),
		Vector2(21.0, -8.0),
		outline_color,
		3.0
	)
	draw_line(
		Vector2(-12.0, 10.0),
		Vector2(-20.0, 17.0),
		outline_color,
		3.0
	)
	draw_line(
		Vector2(12.0, 10.0),
		Vector2(20.0, 17.0),
		outline_color,
		3.0
	)
