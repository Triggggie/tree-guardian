extends Node2D


@export var attack_range: float = 260.0
@export var attack_angle_degrees: float = 18.0
@export var attack_duration: float = 0.12
@export var damage: float = 10.0

@onready var cooldown_timer: Timer = $CooldownTimer

var resting_rotation: float
var current_target: Node2D


func _ready() -> void:
	resting_rotation = rotation
	cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)

	if cooldown_timer.is_stopped():
		cooldown_timer.start()


func _draw() -> void:
	draw_line(
		Vector2.ZERO,
		Vector2(-150, 0),
		Color("6b4423"),
		24.0,
		true
	)


func _on_cooldown_timer_timeout() -> void:
	current_target = find_nearest_enemy()

	if current_target == null:
		return

	perform_attack_animation()


func find_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_distance: float = attack_range

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue

		if enemy is not Node2D:
			continue

		var distance: float = global_position.distance_to(
			enemy.global_position
		)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest_enemy = enemy

	return nearest_enemy

func perform_attack_animation() -> void:
	if not is_instance_valid(current_target):
		return

	var target_at_attack: Node2D = current_target
	var attack_rotation: float = (
		resting_rotation + deg_to_rad(attack_angle_degrees)
	)

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"rotation",
		attack_rotation,
		attack_duration
	)

	tween.tween_callback(
		func() -> void:
			if (
				is_instance_valid(target_at_attack)
				and target_at_attack.has_method("take_damage")
			):
				target_at_attack.take_damage(damage)
	)

	tween.tween_property(
		self,
		"rotation",
		resting_rotation,
		attack_duration
	)
