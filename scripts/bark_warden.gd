extends "res://scripts/bark_beetle.gd"


func _draw() -> void:
	var body_color := Color("34482f")
	var outline_color := Color("1d281b")
	var accent_color := Color("78905f")
	var body_points := PackedVector2Array([
		Vector2(-42.0, -35.0),
		Vector2(42.0, -35.0),
		Vector2(50.0, 24.0),
		Vector2(28.0, 48.0),
		Vector2(-28.0, 48.0),
		Vector2(-50.0, 24.0)
	])
	var outline_points := PackedVector2Array(body_points)
	outline_points.append(body_points[0])
	draw_colored_polygon(body_points, body_color)
	draw_polyline(outline_points, outline_color, 5.0, true)
	draw_circle(Vector2.ZERO, 18.0, accent_color)
	draw_line(Vector2(-28.0, -34.0), Vector2(-42.0, -55.0), outline_color, 7.0)
	draw_line(Vector2(28.0, -34.0), Vector2(42.0, -55.0), outline_color, 7.0)
