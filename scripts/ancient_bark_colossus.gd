extends "res://scripts/bark_beetle.gd"


func _draw() -> void:
	var body_color := Color("25251d")
	var outline_color := Color("11110d")
	var accent_color := Color("6c5940")
	var body_points := PackedVector2Array([
		Vector2(-68.0, -58.0),
		Vector2(68.0, -58.0),
		Vector2(82.0, 38.0),
		Vector2(48.0, 75.0),
		Vector2(-48.0, 75.0),
		Vector2(-82.0, 38.0)
	])
	var outline_points := PackedVector2Array(body_points)
	outline_points.append(body_points[0])
	draw_colored_polygon(body_points, body_color)
	draw_polyline(outline_points, outline_color, 8.0, true)
	draw_circle(Vector2.ZERO, 27.0, accent_color)
	draw_line(Vector2(-45.0, -55.0), Vector2(-66.0, -88.0), outline_color, 10.0)
	draw_line(Vector2(45.0, -55.0), Vector2(66.0, -88.0), outline_color, 10.0)
