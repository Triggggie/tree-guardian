extends Node2D


@export_category("Ground Area")
@export var ground_top_y: float = 780.0
@export var screen_width: float = 1920.0
@export var screen_height: float = 1080.0

@export_category("Perspective")
@export var perspective_line_count: int = 6
@export var first_line_spacing: float = 22.0
@export var spacing_growth: float = 9.0

@export_category("Colors")
@export var far_ground_color: Color = Color("465940")
@export var near_ground_color: Color = Color("293a27")
@export var horizon_color: Color = Color("5d7055")
@export var perspective_line_color: Color = Color(
	0.12,
	0.18,
	0.11,
	0.32
)


func _draw() -> void:
	draw_ground_layers()
	draw_perspective_lines()


func draw_ground_layers() -> void:
	var ground_height: float = (
		screen_height - ground_top_y
	)

	# Vzdálenější světlejší zem.
	draw_rect(
		Rect2(
			0.0,
			ground_top_y,
			screen_width,
			ground_height * 0.42
		),
		far_ground_color
	)

	# Bližší tmavší zem.
	draw_rect(
		Rect2(
			0.0,
			ground_top_y + ground_height * 0.42,
			screen_width,
			ground_height * 0.58
		),
		near_ground_color
	)

	# Hrana mezi pozadím a bojovou plochou.
	draw_rect(
		Rect2(
			0.0,
			ground_top_y,
			screen_width,
			7.0
		),
		horizon_color
	)


func draw_perspective_lines() -> void:
	var current_y: float = (
		ground_top_y + first_line_spacing
	)

	var current_spacing: float = first_line_spacing

	for line_index in range(
		perspective_line_count
	):
		if current_y >= screen_height:
			break

		draw_line(
			Vector2(0.0, current_y),
			Vector2(screen_width, current_y),
			perspective_line_color,
			3.0
		)

		current_spacing += spacing_growth
		current_y += current_spacing
