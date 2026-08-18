extends "res://scripts/bark_beetle.gd"


const COLOSSUS_WALK_VELOCITY_EPSILON: float = 0.1
const MIN_COLOSSUS_WALK_SPEED_SCALE: float = 0.25
const MAX_COLOSSUS_WALK_SPEED_SCALE: float = 1.75


@onready var colossus_sprite: AnimatedSprite2D = (
	$Visual/AncientBarkColossusSprite
)


func update_walk_animation() -> void:
	if not is_instance_valid(colossus_sprite):
		return
	if attack_visual_active:
		return

	var horizontal_speed: float = abs(velocity.x)
	if horizontal_speed > COLOSSUS_WALK_VELOCITY_EPSILON:
		var reference_speed: float = max(move_speed, COLOSSUS_WALK_VELOCITY_EPSILON)
		colossus_sprite.speed_scale = clamp(
			horizontal_speed / reference_speed,
			MIN_COLOSSUS_WALK_SPEED_SCALE,
			MAX_COLOSSUS_WALK_SPEED_SCALE
		)
		if (
			colossus_sprite.animation != &"walk"
			or not colossus_sprite.is_playing()
		):
			colossus_sprite.play(&"walk")
		return

	colossus_sprite.speed_scale = 1.0
	colossus_sprite.animation = &"walk"
	colossus_sprite.pause()


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
	colossus_sprite.flip_h = new_formation_side > 0.0
