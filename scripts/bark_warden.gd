extends "res://scripts/bark_beetle.gd"


const WARDEN_WALK_VELOCITY_EPSILON: float = 0.1
const MIN_WARDEN_WALK_SPEED_SCALE: float = 0.25
const MAX_WARDEN_WALK_SPEED_SCALE: float = 2.0
const ATTACK_IMPACT_DISTANCE: Vector2 = Vector2(5.0, 3.0)
const ATTACK_IMPACT_DELAY: float = 0.56
const ATTACK_IMPACT_DURATION: float = 0.04
const ATTACK_RECOIL_DURATION: float = 0.08
const ATTACK_RECOVERY_HOLD_DURATION: float = 0.0343


@onready var warden_sprite: AnimatedSprite2D = $Visual/BarkWardenSprite


func update_walk_animation() -> void:
	if not is_instance_valid(warden_sprite):
		return
	if attack_visual_active:
		return

	var horizontal_speed: float = abs(velocity.x)
	if horizontal_speed > WARDEN_WALK_VELOCITY_EPSILON:
		var reference_speed: float = max(move_speed, WARDEN_WALK_VELOCITY_EPSILON)
		warden_sprite.speed_scale = clamp(
			horizontal_speed / reference_speed,
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


func play_attack_visual() -> void:
	if (
		not is_instance_valid(visual)
		or not is_instance_valid(warden_sprite)
		or not warden_sprite.sprite_frames.has_animation(&"attack")
	):
		return

	cancel_attack_visual()
	attack_visual_active = true
	visual.position = resting_visual_position
	warden_sprite.speed_scale = 1.0
	warden_sprite.animation = &"attack"
	warden_sprite.set_frame_and_progress(0, 0.0)
	warden_sprite.play()

	var impact_offset: Vector2 = Vector2(
		-formation_side * ATTACK_IMPACT_DISTANCE.x,
		ATTACK_IMPACT_DISTANCE.y
	)
	attack_visual_tween = create_tween()
	attack_visual_tween.tween_interval(
		ATTACK_IMPACT_DELAY
	)
	attack_visual_tween.tween_property(
		visual,
		"position",
		resting_visual_position + impact_offset,
		ATTACK_IMPACT_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	attack_visual_tween.tween_property(
		visual,
		"position",
		resting_visual_position,
		ATTACK_RECOIL_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	attack_visual_tween.tween_interval(
		ATTACK_RECOVERY_HOLD_DURATION
	)
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
	warden_sprite.flip_h = new_formation_side > 0.0
