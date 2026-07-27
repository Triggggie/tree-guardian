extends CharacterBody2D


const FOREST_ESSENCE_SCENE: PackedScene = preload(
	"res://scenes/drops/forest_essence.tscn"
)


@export_category("Movement")
@export var move_speed: float = 120.0
@export var target_x: float = 960.0
@export var stopping_distance: float = 130.0

@export_category("Health")
@export var max_health: float = 30.0
@export var xp_reward: int = 1

@export_category("Attack")
@export var attack_damage: float = 5.0
@export var attack_cooldown: float = 1.5

@export_category("Damage Feedback")
@export var hit_flash_duration: float = 0.08
@export var hit_shake_angle_degrees: float = 8.0
@export var hit_shake_duration: float = 0.04

@onready var attack_timer: Timer = $AttackTimer
@onready var health_bar: ProgressBar = $HealthBar

var current_health: float
var target_tree: Node
var has_reached_tree: bool = false
var combat_enabled: bool = true

var resting_rotation: float
var hit_tween: Tween


func _ready() -> void:
	add_to_group("enemies")

	current_health = max_health
	target_tree = get_tree().get_first_node_in_group("tree")

	resting_rotation = rotation

	attack_timer.wait_time = attack_cooldown
	attack_timer.timeout.connect(_on_attack_timer_timeout)

	health_bar.min_value = 0.0
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.hide()


func _physics_process(_delta: float) -> void:
	if not combat_enabled:
		velocity = Vector2.ZERO
		stop_attacking()
		return

	if not is_instance_valid(target_tree):
		velocity = Vector2.ZERO
		stop_attacking()
		return

	var distance_to_target: float = (
		target_tree.global_position.x - global_position.x
	)

	if abs(distance_to_target) <= stopping_distance:
		velocity = Vector2.ZERO
		start_attacking()
		return

	stop_attacking()

	var direction: float = sign(distance_to_target)
	velocity = Vector2(direction * move_speed, 0.0)

	move_and_slide()


func start_attacking() -> void:
	if has_reached_tree:
		return

	has_reached_tree = true

	if attack_timer.is_stopped():
		attack_timer.start()


func stop_attacking() -> void:
	if not has_reached_tree:
		return

	has_reached_tree = false
	attack_timer.stop()


func _on_attack_timer_timeout() -> void:
	if not combat_enabled:
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
	if is_instance_valid(killer) and killer.has_method("add_xp"):
		killer.add_xp(xp_reward)

	drop_forest_essence()
	remove_from_group("enemies")
	queue_free()


func drop_forest_essence() -> void:
	var essence: Node2D = (
		FOREST_ESSENCE_SCENE.instantiate() as Node2D
	)

	get_parent().add_child(essence)
	essence.global_position = global_position


func stop_combat() -> void:
	combat_enabled = false
	velocity = Vector2.ZERO
	stop_attacking()

	if is_instance_valid(hit_tween):
		hit_tween.kill()

	rotation = resting_rotation
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
