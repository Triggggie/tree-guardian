extends Node2D


signal level_changed(new_level: int)


@export_category("Combat")
@export var attack_range: float = 260.0
@export var base_damage: float = 10.0
@export var damage_per_level: float = 2.0
@export var attack_angle_degrees: float = 18.0
@export var attack_duration: float = 0.12

@export var base_attack_cooldown: float = 1.5
@export var cooldown_reduction_per_level: float = 0.15
@export var minimum_attack_cooldown: float = 0.45

@export_category("Progression")
@export var xp_required_per_level: int = 2

@export_category("Visual Growth")
@export var base_length: float = 150.0
@export var length_per_level: float = 20.0
@export var base_thickness: float = 24.0
@export var thickness_per_level: float = 3.0

@export_category("Milestone Evolution")
@export var evolved_level: int = 3
@export var evolved_attack_angle_degrees: float = 30.0
@export var thorn_length: float = 20.0
@export var thorn_spacing: float = 38.0

@onready var cooldown_timer: Timer = $CooldownTimer

var branch_level: int = 1
var current_xp: int = 0
var resting_rotation: float
var current_target: Node2D


func _ready() -> void:
	add_to_group("strength_branch")

	resting_rotation = rotation
	cooldown_timer.timeout.connect(_on_cooldown_timer_timeout)

	update_attack_cooldown()

	if cooldown_timer.is_stopped():
		cooldown_timer.start()


func get_current_attack_cooldown() -> float:
	var calculated_cooldown: float = (
		base_attack_cooldown
		- cooldown_reduction_per_level * (branch_level - 1)
	)

	return max(
		calculated_cooldown,
		minimum_attack_cooldown
	)


func update_attack_cooldown() -> void:
	cooldown_timer.wait_time = get_current_attack_cooldown()


func _draw() -> void:
	var current_length: float = (
		base_length + length_per_level * (branch_level - 1)
	)

	var current_thickness: float = (
		base_thickness + thickness_per_level * (branch_level - 1)
	)

	var branch_color := Color("6b4423")

	draw_line(
		Vector2.ZERO,
		Vector2(-current_length, 0),
		branch_color,
		current_thickness,
		true
	)

	if branch_level >= evolved_level:
		draw_thorns(current_length, branch_color)
		
func draw_thorns(current_length: float, branch_color: Color) -> void:
	var distance_from_trunk: float = thorn_spacing
	var thorn_points_up: bool = true

	while distance_from_trunk < current_length - 15.0:
		var thorn_base := Vector2(-distance_from_trunk, 0.0)

		var thorn_tip_y: float = (
			-thorn_length if thorn_points_up else thorn_length
		)

		var thorn_tip := Vector2(
			-distance_from_trunk - thorn_length * 0.45,
			thorn_tip_y
		)

		draw_line(
			thorn_base,
			thorn_tip,
			branch_color,
			6.0,
			true
		)

		thorn_points_up = not thorn_points_up
		distance_from_trunk += thorn_spacing		


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
		resting_rotation
		+ deg_to_rad(get_current_attack_angle_degrees())
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
				target_at_attack.take_damage(
					get_current_damage(),
					self
				)
	)

	tween.tween_property(
		self,
		"rotation",
		resting_rotation,
		attack_duration
	)

func get_current_damage() -> float:
	return base_damage + damage_per_level * (branch_level - 1)

func get_current_attack_angle_degrees() -> float:
	if branch_level >= evolved_level:
		return evolved_attack_angle_degrees

	return attack_angle_degrees

func add_xp(amount: int) -> void:
	if amount <= 0:
		return

	current_xp += amount

	print(
		"Strength Branch získala ",
		amount,
		" XP | XP: ",
		current_xp,
		"/",
		xp_required_per_level
	)

	while current_xp >= xp_required_per_level:
		current_xp -= xp_required_per_level
		level_up()


func level_up() -> void:
	branch_level += 1

	update_attack_cooldown()
	queue_redraw()
	level_changed.emit(branch_level)

	print(
		"Strength Branch dosáhla levelu ",
		branch_level,
		" | Damage: ",
		get_current_damage(),
		" | Cooldown: ",
		get_current_attack_cooldown(),
		" s"
	)
