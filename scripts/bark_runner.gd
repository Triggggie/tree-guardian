extends "res://scripts/bark_beetle.gd"


@onready var runner_sprite: Sprite2D = $Visual/BarkRunnerSprite


func setup_crowd_formation(
	new_formation_side: float,
	new_lane_index: int,
	new_lane_y: float,
	new_queue_order: int,
	new_speed_multiplier: float,
	new_depth_jitter: float,
	new_scale_multiplier: float
) -> void:
	super.setup_crowd_formation(
		new_formation_side,
		new_lane_index,
		new_lane_y,
		new_queue_order,
		new_speed_multiplier,
		new_depth_jitter,
		new_scale_multiplier
	)
	runner_sprite.flip_h = new_formation_side > 0.0
