extends "res://scripts/bark_beetle.gd"


const RUN_VELOCITY_EPSILON: float = 0.1
const RUN_REFERENCE_SPEED: float = 185.0
const MIN_RUN_SPEED_SCALE: float = 0.25
const MAX_RUN_SPEED_SCALE: float = 2.0


@onready var runner_sprite: AnimatedSprite2D = $Visual/BarkRunnerSprite


func update_walk_animation() -> void:
	if not is_instance_valid(runner_sprite):
		return

	var horizontal_speed: float = abs(velocity.x)
	if horizontal_speed > RUN_VELOCITY_EPSILON:
		runner_sprite.speed_scale = clamp(
			horizontal_speed / RUN_REFERENCE_SPEED,
			MIN_RUN_SPEED_SCALE,
			MAX_RUN_SPEED_SCALE
		)
		if (
			runner_sprite.animation != &"run"
			or not runner_sprite.is_playing()
		):
			runner_sprite.play(&"run")
		return

	runner_sprite.speed_scale = 1.0
	runner_sprite.pause()


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
