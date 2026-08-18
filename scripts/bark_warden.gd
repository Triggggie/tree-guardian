extends "res://scripts/bark_beetle.gd"


const WARDEN_WALK_VELOCITY_EPSILON: float = 0.1
const WARDEN_WALK_REFERENCE_SPEED: float = 85.0
const MIN_WARDEN_WALK_SPEED_SCALE: float = 0.25
const MAX_WARDEN_WALK_SPEED_SCALE: float = 2.0


@onready var warden_sprite: AnimatedSprite2D = $Visual/BarkWardenSprite


func update_walk_animation() -> void:
	if not is_instance_valid(warden_sprite):
		return
	if attack_visual_active:
		return

	var horizontal_speed: float = abs(velocity.x)
	if horizontal_speed > WARDEN_WALK_VELOCITY_EPSILON:
		warden_sprite.speed_scale = clamp(
			horizontal_speed / WARDEN_WALK_REFERENCE_SPEED,
			MIN_WARDEN_WALK_SPEED_SCALE,
			MAX_WARDEN_WALK_SPEED_SCALE
		)
		if (
			warden_sprite.animation != &"walk"
			or not warden_sprite.is_playing()
		):
			warden_sprite.play(&"walk")
		return

	warden_sprite.speed_scale = 1.0
	warden_sprite.animation = &"walk"
	warden_sprite.pause()


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
	warden_sprite.flip_h = new_formation_side > 0.0
