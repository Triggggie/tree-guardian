extends "res://scripts/bark_beetle.gd"


const RUN_VELOCITY_EPSILON: float = 0.1
const RUN_REFERENCE_SPEED: float = 185.0
const MIN_RUN_SPEED_SCALE: float = 0.25
const MAX_RUN_SPEED_SCALE: float = 2.0
const ATTACK_DASH_DISTANCE: float = 16.0
const ATTACK_DASH_FORWARD_DURATION: float = 0.14
const ATTACK_DASH_PEAK_DURATION: float = 0.02
const ATTACK_DASH_RECOIL_DURATION: float = 0.15


@onready var runner_sprite: AnimatedSprite2D = $Visual/BarkRunnerSprite


func update_walk_animation() -> void:
	if not is_instance_valid(runner_sprite):
		return
	if attack_visual_active:
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
	runner_sprite.animation = &"run"
	runner_sprite.pause()


func play_attack_visual() -> void:
	if (
		not is_instance_valid(visual)
		or not is_instance_valid(runner_sprite)
		or not runner_sprite.sprite_frames.has_animation(&"attack")
	):
		return

	cancel_attack_visual()
	attack_visual_active = true
	visual.position = resting_visual_position
	runner_sprite.speed_scale = 1.0
	runner_sprite.animation = &"attack"
	runner_sprite.set_frame_and_progress(0, 0.0)
	runner_sprite.play()

	var dash_offset: Vector2 = Vector2(
		-formation_side * ATTACK_DASH_DISTANCE,
		0.0
	)
	attack_visual_tween = create_tween()
	attack_visual_tween.tween_property(
		visual,
		"position",
		resting_visual_position + dash_offset,
		ATTACK_DASH_FORWARD_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	attack_visual_tween.tween_interval(
		ATTACK_DASH_PEAK_DURATION
	)
	attack_visual_tween.tween_property(
		visual,
		"position",
		resting_visual_position,
		ATTACK_DASH_RECOIL_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	attack_visual_tween.tween_callback(finish_attack_visual)


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
