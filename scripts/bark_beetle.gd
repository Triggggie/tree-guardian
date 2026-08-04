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

@onready var health_component: EnemyHealthComponent = (
	$HealthComponent
)
@onready var attack_component: EnemyAttackComponent = (
	$AttackComponent
)
@onready var movement_component: EnemyMovementComponent = (
	$MovementComponent
)
@onready var health_bar: ProgressBar = $HealthBar

var enemy_definition: EnemyDefinition
var stage_definition: StageDefinition
var target_tree: Node2D
var enemy_tracker: EnemyTracker
var lane_registry: LaneRegistry
var branch_seed_service: BranchSeedService

var formation_side: float = 1.0
var lane_index: int = 0
var queue_order: int = 0

var combat_enabled: bool = true
var is_dying: bool = false
var has_warned_missing_branch_seed_service: bool = false

var resting_rotation: float
var resting_scale: Vector2

var hit_tween: Tween
var death_tween: Tween


func configure_from_definition(
	definition: EnemyDefinition,
	maximum_health_override: float = -1.0,
	attack_damage_multiplier: float = 1.0
) -> bool:
	if (
		not is_instance_valid(definition)
		or not definition.is_valid_definition()
	):
		push_error(
			"Bark Beetle cannot configure from an invalid "
			+ "EnemyDefinition."
		)
		return false

	enemy_definition = definition
	move_speed = definition.movement_speed
	attack_damage = max(
		definition.attack_damage
		* max(
			attack_damage_multiplier,
			0.0
		),
		0.0
	)
	attack_cooldown = definition.attack_interval
	stopping_distance = definition.attack_range
	forest_essence_reward = definition.essence_reward
	xp_reward = definition.experience_reward

	var configured_maximum_health: float = (
		maximum_health_override
		if maximum_health_override > 0.0
		else definition.maximum_health
	)

	max_health = max(
		configured_maximum_health,
		1.0
	)

	return true


func configure_stage_context(
	new_stage_definition: StageDefinition
) -> bool:
	if (
		not is_instance_valid(new_stage_definition)
		or not new_stage_definition.is_valid_definition()
	):
		return false

	stage_definition = new_stage_definition
	return true


func _ready() -> void:
	add_to_group("enemies")

	if not is_instance_valid(enemy_definition):
		push_warning(
			"Bark Beetle started without EnemyDefinition; "
			+ "using scene/script fallback values."
		)

	if not is_instance_valid(branch_seed_service):
		branch_seed_service = (
			get_node_or_null("/root/BranchSeeds")
			as BranchSeedService
		)

	enemy_tracker = (
		get_tree().get_first_node_in_group(
			"enemy_tracker"
		)
		as EnemyTracker
	)

	if is_instance_valid(enemy_tracker):
		enemy_tracker.register_enemy(self)
	else:
		push_warning(
			"Bark Beetle could not find EnemyTracker; "
			+ "continuing with the enemies group."
		)

	lane_registry = (
		get_tree().get_first_node_in_group(
			"lane_registry"
		)
		as LaneRegistry
	)

	if not is_instance_valid(lane_registry):
		push_warning(
			"Bark Beetle could not find LaneRegistry; "
			+ "using enemies group queue fallback."
		)

	target_tree = (
		get_tree().get_first_node_in_group("tree")
		as Node2D
	)

	resting_rotation = rotation
	resting_scale = scale

	attack_component.attack_requested.connect(
		_on_attack_requested
	)
	attack_component.initialize(
		attack_damage,
		attack_cooldown
	)

	health_component.health_changed.connect(
		_on_health_changed
	)
	health_component.initialize(max_health)

	var movement_initialized: bool = (
		movement_component.initialize(
			self,
			target_tree,
			move_speed,
			stopping_distance,
			arrival_distance,
			lane_change_speed,
			column_spacing
		)
	)

	if not movement_initialized:
		combat_enabled = false
		attack_component.set_enabled(false)
		movement_component.set_enabled(false)


func _exit_tree() -> void:
	unregister_from_enemy_tracker()
	unregister_from_lane_registry()


func unregister_from_enemy_tracker() -> void:
	if not is_instance_valid(enemy_tracker):
		return

	enemy_tracker.unregister_enemy(self)


func unregister_from_lane_registry() -> void:
	if not is_instance_valid(lane_registry):
		return

	lane_registry.unregister_enemy(self)


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
	queue_order = new_queue_order

	var formation_success: bool = (
		movement_component.configure_formation(
			new_formation_side,
			new_lane_y,
			new_speed_multiplier,
			new_depth_jitter,
			new_scale_multiplier
		)
	)

	if not formation_success:
		push_error(
			"Bark Beetle could not configure its movement formation."
		)
		return

	resting_scale = scale
	register_with_lane_registry()


func register_with_lane_registry() -> void:
	if not is_instance_valid(lane_registry):
		return

	lane_registry.register_enemy(
		self,
		formation_side,
		lane_index,
		queue_order
	)

func is_targetable() -> bool:
	return (
		is_inside_tree()
		and not is_queued_for_deletion()
		and is_instance_valid(movement_component)
		and movement_component.is_formation_configured()
		and combat_enabled
		and not is_dying
		and is_instance_valid(health_component)
		and health_component.is_initialized()
		and not health_component.is_depleted()
		and is_in_group("enemies")
	)


func get_lane_index() -> int:
	return lane_index

func _physics_process(delta: float) -> void:
	if is_dying:
		movement_component.stop()
		return

	if not combat_enabled:
		movement_component.stop()
		stop_attacking()
		return

	if not movement_component.is_formation_configured():
		movement_component.stop()
		stop_attacking()
		return

	if not is_instance_valid(target_tree):
		movement_component.stop()
		stop_attacking()
		return

	var current_column: int = get_current_queue_column()
	var reached_queue_position: bool = (
		movement_component.physics_step(
			delta,
			current_column
		)
	)

	if not reached_queue_position:
		stop_attacking()
		return

	if current_column == 0:
		start_attacking()
	else:
		stop_attacking()


func get_current_queue_column() -> int:
	if (
		is_instance_valid(lane_registry)
		and lane_registry.is_enemy_registered(self)
	):
		var queue_column: int = (
			lane_registry.get_queue_column(self)
		)

		if queue_column >= 0:
			return queue_column

	return get_current_queue_column_fallback()


func get_current_queue_column_fallback() -> int:
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


func start_attacking() -> void:
	if is_dying:
		return

	if not combat_enabled:
		return

	attack_component.start_attacking()


func stop_attacking() -> void:
	if not is_instance_valid(attack_component):
		return

	attack_component.stop_attacking()


func _on_attack_requested() -> void:
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
		target_tree.take_damage(
			attack_component.get_attack_damage()
		)


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

	var damage_applied: bool = (
		health_component.apply_damage(
			amount,
			damage_source
		)
	)

	if not damage_applied:
		return

	var remaining_health: float = (
		health_component.get_current_health()
	)

	print(
		name,
		" dostal zásah: ",
		amount,
		" | zbývá HP: ",
		remaining_health
	)

	if health_component.is_depleted():
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
	movement_component.stop()

	global_position.x += (
		formation_side
		* actual_distance
	)

func _on_health_changed(
	current_health: float,
	maximum_health: float
) -> void:
	health_bar.min_value = 0.0
	health_bar.max_value = maximum_health
	health_bar.value = current_health

	if (
		current_health < maximum_health
		and current_health > 0.0
	):
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

	attack_component.set_enabled(false)
	stop_attacking()
	movement_component.set_enabled(false)
	movement_component.stop()
	health_bar.hide()
	remove_from_group("enemies")
	unregister_from_enemy_tracker()
	unregister_from_lane_registry()

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
	process_branch_seed_loot()

	play_death_feedback()


func process_branch_seed_loot() -> void:
	if not is_instance_valid(enemy_definition):
		return

	if not enemy_definition.is_valid_definition():
		return

	if enemy_definition.is_normal_enemy():
		return

	if (
		not is_instance_valid(stage_definition)
		or not stage_definition.is_valid_definition()
	):
		return

	var loot_pool: BranchSeedLootPoolDefinition = (
		stage_definition.get_branch_seed_loot_pool()
	)
	if not is_instance_valid(loot_pool) or loot_pool.entries.is_empty():
		return

	if not is_instance_valid(branch_seed_service):
		if not has_warned_missing_branch_seed_service:
			has_warned_missing_branch_seed_service = true
			push_warning(
				"Enemy '%s' has eligible Stage Branch Seed loot but BranchSeeds is unavailable."
				% enemy_definition.enemy_id
			)

		return

	branch_seed_service.process_enemy_defeat(
		enemy_definition,
		stage_definition,
		global_position
	)


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
	attack_component.set_enabled(false)
	stop_attacking()
	movement_component.set_enabled(false)
	movement_component.stop()

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
