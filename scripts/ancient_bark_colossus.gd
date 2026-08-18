extends "res://scripts/bark_beetle.gd"


const COLOSSUS_WALK_VELOCITY_EPSILON: float = 0.1
const MIN_COLOSSUS_WALK_SPEED_SCALE: float = 0.5
const MAX_COLOSSUS_WALK_SPEED_SCALE: float = 1.35
const COLOSSUS_QUAKE_IMPACT_FRAME: int = 5


var quake_visual_active: bool = false


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
	colossus_sprite.set_frame_and_progress(0, 0.0)


func play_attack_visual() -> void:
	if quake_visual_active:
		return
	if (
		not is_instance_valid(visual)
		or not is_instance_valid(colossus_sprite)
		or not colossus_sprite.sprite_frames.has_animation(&"attack")
	):
		return

	cancel_attack_visual()
	attack_visual_active = true
	visual.position = resting_visual_position
	colossus_sprite.speed_scale = 1.0
	colossus_sprite.animation = &"attack"
	colossus_sprite.set_frame_and_progress(0, 0.0)
	colossus_sprite.play()

	var attack_frame_count: int = colossus_sprite.sprite_frames.get_frame_count(
		&"attack"
	)
	var attack_fps: float = max(
		colossus_sprite.sprite_frames.get_animation_speed(&"attack"), 0.01
	)
	attack_visual_tween = create_tween()
	attack_visual_tween.tween_interval(float(attack_frame_count) / attack_fps)
	attack_visual_tween.tween_callback(finish_attack_visual)


func configure_boss_ability_runtime(
	ability_definition: BossAbilityDefinition
) -> void:
	super.configure_boss_ability_runtime(ability_definition)
	if not is_instance_valid(boss_ability_runtime):
		return
	boss_ability_runtime.telegraph_started.connect(_on_quake_telegraph_started)


func _on_quake_telegraph_started(
	ability_id: StringName,
	phase: int
) -> void:
	if (
		ability_id != &"colossal_quake"
		or not is_instance_valid(visual)
		or not is_instance_valid(colossus_sprite)
		or not colossus_sprite.sprite_frames.has_animation(&"quake")
		or not is_instance_valid(boss_ability_runtime)
	):
		return

	cancel_attack_visual()
	quake_visual_active = true
	attack_visual_active = true
	visual.position = resting_visual_position
	colossus_sprite.animation = &"quake"
	colossus_sprite.set_frame_and_progress(0, 0.0)

	var quake_fps: float = max(
		colossus_sprite.sprite_frames.get_animation_speed(&"quake"), 0.01
	)
	var telegraph_duration: float = max(
		boss_ability_runtime.get_telegraph_duration_for_phase(phase), 0.01
	)
	colossus_sprite.speed_scale = 1.0
	colossus_sprite.pause()

	var quake_frame_count: int = colossus_sprite.sprite_frames.get_frame_count(
		&"quake"
	)
	var quake_start_delay: float = get_quake_start_delay(
		telegraph_duration,
		quake_fps
	)
	attack_visual_tween = create_tween()
	attack_visual_tween.tween_interval(quake_start_delay)
	attack_visual_tween.tween_callback(_start_quake_playback)
	attack_visual_tween.tween_interval(float(quake_frame_count) / quake_fps)
	attack_visual_tween.tween_callback(_finish_quake_visual)


func get_quake_start_delay(
	telegraph_duration: float,
	quake_fps: float
) -> float:
	return max(
		telegraph_duration
		- float(COLOSSUS_QUAKE_IMPACT_FRAME) / max(quake_fps, 0.01),
		0.0
	)


func _start_quake_playback() -> void:
	if not quake_visual_active or not is_instance_valid(colossus_sprite):
		return
	colossus_sprite.play(&"quake")


func _finish_quake_visual() -> void:
	quake_visual_active = false
	finish_attack_visual()


func cancel_attack_visual() -> void:
	quake_visual_active = false
	super.cancel_attack_visual()


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
