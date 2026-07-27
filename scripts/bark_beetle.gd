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
@export var attack_damage: float = 20.0
@export var attack_cooldown: float = 0.5

@onready var attack_timer: Timer = $AttackTimer

var current_health: float
var target_tree: Node
var has_reached_tree: bool = false
var combat_enabled: bool = true


func _ready() -> void:
	add_to_group("enemies")

	current_health = max_health
	target_tree = get_tree().get_first_node_in_group("tree")

	attack_timer.wait_time = attack_cooldown
	attack_timer.timeout.connect(_on_attack_timer_timeout)


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
	current_health -= amount

	print(
		name,
		" dostal zásah: ",
		amount,
		" | zbývá HP: ",
		current_health
	)

	if current_health <= 0.0:
		die(damage_source)


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
func stop_combat() -> void:
	combat_enabled = false
	velocity = Vector2.ZERO
	stop_attacking()
