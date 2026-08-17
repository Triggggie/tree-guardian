class_name TalentGraphCanvas
extends Control


var prerequisite_connections: Array[Dictionary] = []


func set_prerequisite_connections(connections: Array[Dictionary]) -> void:
	prerequisite_connections = connections
	queue_redraw()


func clear_prerequisite_connections() -> void:
	prerequisite_connections.clear()
	queue_redraw()


func _draw() -> void:
	for connection in prerequisite_connections:
		var start: Vector2 = connection.get("start", Vector2.ZERO)
		var finish: Vector2 = connection.get("finish", Vector2.ZERO)
		var active: bool = bool(connection.get("active", false))
		var color := (
			Color(0.45, 0.92, 0.52, 0.95)
			if active
			else Color(0.34, 0.39, 0.36, 0.85)
		)
		var middle_y: float = (start.y + finish.y) * 0.5
		var points := PackedVector2Array([
			start,
			Vector2(start.x, middle_y),
			Vector2(finish.x, middle_y),
			finish
		])
		draw_polyline(points, color, 4.0 if active else 3.0, true)
