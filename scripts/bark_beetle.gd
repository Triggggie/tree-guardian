extends CharacterBody2D


const FOREST_ESSENCE_SCENE: PackedScene = preload(
	"res://scenes/drops/forest_essence.tscn"
)


@export_category("Movement")
@export var move_speed: float = 120.0
@export var stopping_distance: float = 130.0
@export var arrival_distance: float = 5.0
@export var lane_change_speed: float = 240.0

@export_category("Control Effects")

@export_range(0.0, 1.0, 0.05)
var knockback_resistance: float = 0.0

@export_category("Crowd Formation")
@export var column_spacing: float = 70.0

@export_category("Health")
@export var max_health: float = 30.0
@export var xp_reward: int = 1
@export var forest_essence_reward: int = 1

@export_category("Attack")
@export var attack_damage: float = 5.0
@export var attack_cooldown: float = 1.5

@export_category("Damage Feedback")
@export var hit_flash_duration: float = 0.08
@export var hit_shake_angle_degrees: float = 8.0
@export var hit_shake_duration: float = 0.04

@export_category("Death Feedback")
@export var death_duration: float = 0.22
@export var death_scale_multiplier: float = 0.15

@onready var attack_timer: Timer = $AttackTimer
@onready var health_bar: ProgressBar = $HealthBar

var current_health: float
var target_tree: Node2D

var formation_side: float = 1.0
var lane_index: int = 0
var lane_y: float = 818.0
var queue_order: int = 0

var speed_multiplier: float = 1.0
var depth_jitter: float = 0.0
var crowd_scale_multiplier: float = 1.0

var formation_initialized: bool = false
var combat_enabled: bool = true
var is_dying: bool = false

var resting_rotation: float
var resting_scale: Vector2

var hit_tween: Tween
var death_tween: Tween


func _ready() -> void:
	add_to_group("enemies")

	current_health = max_health

	target_tree = (
		get_tree().get_first_node_in_group("tree")
		as Node2D
	)

	resting_rotation = rotation
	resting_scale = scale

	attack_timer.wait_time = attack_cooldown
	attack_timer.timeout.connect(
		_on_attack_timer_timeout
	)

	health_bar.min_value = 0.0
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.hide()


func setup_crowd_formation(
	new_formation_side: float,
	new_lane_index: int,
	new_lane_y: float,
	new_queue_order: int,
	new_speed_multiplier: float,
	new_depth_jitter: float,
	new_scale_multiplier: float
) -> void:
	formation_side = new_formation_side
	lane_index = new_lane_index
	lane_y = new_lane_y
	queue_order = new_queue_order

	speed_multiplier = new_speed_multiplier
	depth_jitter = new_depth_jitter
	crowd_scale_multiplier = new_scale_multiplier

	formation_initialized = true

	apply_crowd_depth()

func is_targetable() -> bool:
	return (
		is_inside_tree()
		and not is_queued_for_deletion()
		and formation_initialized
		and combat_enabled
		and not is_dying
		and current_health > 0.0
		and is_in_group("enemies")
	)


func get_lane_index() -> int:
	return lane_index

func apply_crowd_depth() -> void:
	scale = Vector2.ONE * crowd_scale_multiplier
	resting_scale = scale

	z_index = int(lane_y)


func _physics_process(delta: float) -> void:
	if is_dying:
		velocity = Vector2.ZERO
		return

	if not combat_enabled:
		velocity = Vector2.ZERO
		stop_attacking()
		return

	if not formation_initialized:
		velocity = Vector2.ZERO
		return

	if not is_instance_valid(target_tree):
		velocity = Vector2.ZERO
		stop_attacking()
		return

	global_position.y = move_toward(
		global_position.y,
		lane_y,
		lane_change_speed * delta
	)

	z_index = int(global_position.y)

	var current_column: int = get_current_queue_column()
	var target_x: float = get_target_x(current_column)

	var horizontal_distance: float = (
		target_x - global_position.x
	)

	if abs(horizontal_distance) <= arrival_distance:
		global_position.x = target_x
		velocity = Vector2.ZERO

		if current_column == 0:
			start_attacking()
		else:
			stop_attacking()

		return

	stop_attacking()

	var movement_direction: float = sign(
		horizontal_distance
	)

	velocity = Vector2(
		movement_direction
		* move_speed
		* speed_multiplier,
		0.0
	)

	move_and_slide()


func get_current_queue_column() -> int:
	var current_column: int = 0

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == self:
			continue

		if not is_instance_valid(enemy):
			continue

		if not enemy.has_method("is_ahead_in_crowd_queue"):
			continue

		if enemy.is_ahead_in_crowd_queue(
			formation_side,
			lane_index,
			queue_order
		):
			current_column += 1

	return current_column


func is_ahead_in_crowd_queue(
	checked_side: float,
	checked_lane: int,
	checked_order: int
) -> bool:
	if is_dying:
		return false

	return (
		formation_side == checked_side
		and lane_index == checked_lane
		and queue_order < checked_order
	)


func get_target_x(
	current_column: int
) -> float:
	var distance_from_tree: float = (
		stopping_distance
		+ current_column * column_spacing
		+ depth_jitter
	)

	distance_from_tree = max(
		distance_from_tree,
		stopping_distance - 15.0
	)

	return (
		target_tree.global_position.x
		+ formation_side * distance_from_tree
	)


func start_attacking() -> void:
	if is_dying:
		return

	if not combat_enabled:
		return

	if not attack_timer.is_stopped():
		return

	attack_timer.start()


func stop_attacking() -> void:
	attack_timer.stop()


func _on_attack_timer_timeout() -> void:
	if is_dying:
		return

	if not combat_enabled:
		return

	if get_current_queue_column() != 0:
		stop_attacking()
		return

	if not is_instance_valid(target_tree):
		stop_attacking()
		return

	if target_tree.has_method("take_damage"):
		target_tree.take_damage(attack_damage)


func take_damage(
	amount: float,
	damage_source: Node = null
) -> void:
	if is_dying:
		return

	if not combat_enabled:
		return

	if amount <= 0.0:
		return

	current_health = max(
		current_health - amount,
		0.0
	)

	update_health_bar()

	print(
		name,
		" dostal zásah: ",
		amount,
		" | zbývá HP: ",
		current_health
	)

	if current_health <= 0.0:
		die(damage_source)
		return

	play_hit_feedback()

func apply_knockback(
	distance: float
) -> void:
	if is_dying:
		return

	if not combat_enabled:
		return

	if distance <= 0.0:
		return

	var resistance: float = clamp(
		knockback_resistance,
		0.0,
		1.0
	)

	var actual_distance: float = (
		distance
		* (1.0 - resistance)
	)

	if actual_distance <= 0.0:
		return

	stop_attacking()
	velocity = Vector2.ZERO

	global_position.x += (
		formation_side
		* actual_distance
	)

func update_health_bar() -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health

	if current_health < max_health:
		health_bar.show()
	else:
		health_bar.hide()


func play_hit_feedback() -> void:
	if is_instance_valid(hit_tween):
		hit_tween.kill()

	rotation = resting_rotation
	modulate = Color.WHITE

	var shake_angle: float = deg_to_rad(
		hit_shake_angle_degrees
	)

	hit_tween = create_tween()
	hit_tween.set_parallel(true)

	hit_tween.tween_property(
		self,
		"modulate",
		Color(1.0, 0.3, 0.3, 1.0),
		hit_flash_duration
	)

	hit_tween.tween_property(
		self,
		"rotation",
		resting_rotation + shake_angle,
		hit_shake_duration
	)

	hit_tween.set_parallel(false)

	hit_tween.tween_property(
		self,
		"rotation",
		resting_rotation - shake_angle,
		hit_shake_duration
	)

	hit_tween.tween_property(
		self,
		"rotation",
		resting_rotation,
		hit_shake_duration
	)

	hit_tween.tween_property(
		self,
		"modulate",
		Color.WHITE,
		hit_flash_duration
	)


func die(killer: Node = null) -> void:
	if is_dying:
		return

	is_dying = true
	combat_enabled = false
	velocity = Vector2.ZERO

	stop_attacking()
	health_bar.hide()
	remove_from_group("enemies")

	if is_instance_valid(hit_tween):
		hit_tween.kill()

	if (
		is_instance_valid(killer)
		and killer.has_method("add_xp")
	):
		killer.add_xp(xp_reward)

	var actual_essence_reward: int = (
		get_actual_essence_reward()
	)

	drop_forest_essence(
		actual_essence_reward
	)

	play_death_feedback()


func play_death_feedback() -> void:
	rotation = resting_rotation
	modulate = Color.WHITE
	scale = resting_scale

	death_tween = create_tween()
	death_tween.set_parallel(true)

	death_tween.tween_property(
		self,
		"scale",
		resting_scale * death_scale_multiplier,
		death_duration
	)

	death_tween.tween_property(
		self,
		"modulate",
		Color(1.0, 1.0, 1.0, 0.0),
		death_duration
	)

	death_tween.set_parallel(false)
	death_tween.tween_callback(queue_free)


func get_actual_essence_reward() -> int:
	if not is_instance_valid(target_tree):
		return max(
			forest_essence_reward,
			1
		)

	if target_tree.has_method(
		"calculate_forest_essence_reward"
	):
		return target_tree.calculate_forest_essence_reward(
			forest_essence_reward
		)

	return max(
		forest_essence_reward,
		1
	)


func drop_forest_essence(
	drop_count: int
) -> void:
	if drop_count <= 0:
		return

	for drop_index in range(drop_count):
		var essence: Node2D = (
			FOREST_ESSENCE_SCENE.instantiate()
			as Node2D
		)

		get_parent().add_child(essence)

		var drop_offset := Vector2(
			randf_range(-28.0, 28.0),
			randf_range(-24.0, 8.0)
		)

		essence.global_position = (
			global_position
			+ drop_offset
		)

func stop_combat() -> void:
	if is_dying:
		return

	combat_enabled = false
	velocity = Vector2.ZERO
	stop_attacking()

	if is_instance_valid(hit_tween):
		hit_tween.kill()

	rotation = resting_rotation
	scale = resting_scale
	modulate = Color.WHITE


func _draw() -> void:
	draw_circle(
		Vector2.ZERO,
		32.0,
		Color("3a2118")
	)

	draw_line(
		Vector2(-12, -22),
		Vector2(-25, -38),
		Color("3a2118"),
		5.0
	)

	draw_line(
		Vector2(12, -22),
		Vector2(25, -38),
		Color("3a2118"),
		5.0
	)
