extends Node


signal wave_changed(
	new_wave: int,
	enemies_per_side: int
)

signal wave_message_changed(
	message: String
)


const BARK_BEETLE_SCENE: PackedScene = preload(
	"res://scenes/enemies/bark_beetle.tscn"
)


@export_category("Wave")
@export var base_enemies_per_side: int = 2
@export var waves_per_enemy_increase: int = 3
@export var maximum_enemies_per_side: int = 30
@export var time_between_spawns: float = 0.25

# Jak dlouho zůstane viditelný text WAVE COMPLETE.
@export var wave_complete_message_duration: float = 0.7

# Krátká pauza po zmizení textu před další vlnou.
@export var time_between_waves: float = 0.5

@export var spawn_spacing: float = 75.0


@export_category("Crowd Formation")
@export_range(1, 9, 1)
var lane_count: int = 5

@export var lane_spacing: float = 8.0
@export var lane_center_y_offset: float = 16.0
@export var lane_y_jitter: float = 2.5

@export var minimum_speed_multiplier: float = 0.85
@export var maximum_speed_multiplier: float = 1.15

@export var maximum_depth_jitter: float = 10.0
@export var lane_scale_step: float = 0.025


@export_category("Enemy Scaling")
@export var base_enemy_health: float = 30.0
@export var health_increase_per_wave: float = 3.0
@export var maximum_enemy_health: float = 1000000.0


@onready var entities: Node2D = $"../Entities"

@onready var left_spawn_point: Marker2D = (
	$"../World/LeftSpawnPoint"
)

@onready var right_spawn_point: Marker2D = (
	$"../World/RightSpawnPoint"
)

@onready var tree_node: Node = (
	get_tree().get_first_node_in_group("tree")
)


var current_wave: int = 0
var game_over: bool = false


func _ready() -> void:
	add_to_group("wave_manager")

	randomize()

	if (
		is_instance_valid(tree_node)
		and tree_node.has_signal("died")
	):
		tree_node.died.connect(_on_tree_died)

	run_wave_loop()


func run_wave_loop() -> void:
	while true:
		if game_over:
			return

		current_wave += 1

		var enemy_count: int = (
			get_current_enemies_per_side()
		)

		wave_changed.emit(
			current_wave,
			enemy_count
		)

		print(
			"Začíná vlna ",
			current_wave,
			" | nepřátel na každé straně: ",
			enemy_count,
			" | HP nepřítele: ",
			get_current_enemy_health()
		)

		await spawn_wave(enemy_count)

		if game_over:
			return

		await wait_until_all_enemies_are_dead()

		if game_over:
			return

		complete_wave()

		await show_wave_complete_message()

		if game_over:
			return

		await get_tree().create_timer(
			time_between_waves
		).timeout


func get_current_enemies_per_side() -> int:
	var safe_interval: int = max(
		waves_per_enemy_increase,
		1
	)

	var additional_enemies: int = int(
		(current_wave - 1)
		/ safe_interval
	)

	return min(
		base_enemies_per_side
		+ additional_enemies,
		maximum_enemies_per_side
	)


func get_current_enemy_health() -> float:
	var calculated_health: float = (
		base_enemy_health
		+ health_increase_per_wave
		* (current_wave - 1)
	)

	return min(
		calculated_health,
		maximum_enemy_health
	)


func spawn_wave(enemy_count: int) -> void:
	var enemy_health: float = (
		get_current_enemy_health()
	)

	var safe_lane_count: int = max(
		lane_count,
		1
	)

	var left_lane_counts: Array[int] = []
	var right_lane_counts: Array[int] = []

	for lane in range(safe_lane_count):
		left_lane_counts.append(0)
		right_lane_counts.append(0)

	for index in range(enemy_count):
		if game_over:
			return

		var left_lane: int = randi_range(
			0,
			safe_lane_count - 1
		)

		var right_lane: int = randi_range(
			0,
			safe_lane_count - 1
		)

		var left_queue_order: int = (
			left_lane_counts[left_lane]
		)

		var right_queue_order: int = (
			right_lane_counts[right_lane]
		)

		left_lane_counts[left_lane] += 1
		right_lane_counts[right_lane] += 1

		var left_lane_y: float = get_lane_y(
			left_spawn_point.global_position.y,
			left_lane,
			safe_lane_count
		)

		var right_lane_y: float = get_lane_y(
			right_spawn_point.global_position.y,
			right_lane,
			safe_lane_count
		)

		var left_spawn_position := Vector2(
			left_spawn_point.global_position.x
			- left_queue_order * spawn_spacing,
			left_lane_y
		)

		var right_spawn_position := Vector2(
			right_spawn_point.global_position.x
			+ right_queue_order * spawn_spacing,
			right_lane_y
		)

		spawn_enemy(
			left_spawn_position,
			enemy_health,
			-1.0,
			left_lane,
			left_lane_y,
			left_queue_order,
			safe_lane_count
		)

		spawn_enemy(
			right_spawn_position,
			enemy_health,
			1.0,
			right_lane,
			right_lane_y,
			right_queue_order,
			safe_lane_count
		)

		if index < enemy_count - 1:
			await get_tree().create_timer(
				time_between_spawns
			).timeout


func get_lane_y(
	base_y: float,
	selected_lane: int,
	total_lanes: int
) -> float:
	var centered_lane: float = (
		selected_lane
		- (total_lanes - 1) / 2.0
	)

	return (
		base_y
		+ lane_center_y_offset
		+ centered_lane * lane_spacing
		+ randf_range(
			-lane_y_jitter,
			lane_y_jitter
		)
	)


func get_lane_scale(
	selected_lane: int,
	total_lanes: int
) -> float:
	var centered_lane: float = (
		selected_lane
		- (total_lanes - 1) / 2.0
	)

	return max(
		1.0
		+ centered_lane * lane_scale_step,
		0.75
	)


func spawn_enemy(
	spawn_position: Vector2,
	enemy_health: float,
	formation_side: float,
	selected_lane: int,
	selected_lane_y: float,
	queue_order: int,
	total_lanes: int
) -> void:
	if game_over:
		return

	var enemy: Node2D = (
		BARK_BEETLE_SCENE.instantiate()
		as Node2D
	)

	enemy.set(
		"max_health",
		enemy_health
	)

	entities.add_child(enemy)
	enemy.global_position = spawn_position

	enemy.call(
		"setup_crowd_formation",
		formation_side,
		selected_lane,
		selected_lane_y,
		queue_order,
		randf_range(
			minimum_speed_multiplier,
			maximum_speed_multiplier
		),
		randf_range(
			-maximum_depth_jitter,
			maximum_depth_jitter
		),
		get_lane_scale(
			selected_lane,
			total_lanes
		)
	)


func wait_until_all_enemies_are_dead() -> void:
	while not get_tree().get_nodes_in_group(
		"enemies"
	).is_empty():
		if game_over:
			return

		await get_tree().process_frame


func complete_wave() -> void:
	if game_over:
		return

	print(
		"Vlna ",
		current_wave,
		" dokončena"
	)

	if (
		is_instance_valid(tree_node)
		and tree_node.has_method("add_age")
	):
		tree_node.add_age(1)


func show_wave_complete_message() -> void:
	if game_over:
		return

	wave_message_changed.emit(
		"WAVE %d COMPLETE"
		% current_wave
	)

	await get_tree().create_timer(
		wave_complete_message_duration
	).timeout

	wave_message_changed.emit("")


func _on_tree_died() -> void:
	if game_over:
		return

	game_over = true

	wave_message_changed.emit("")

	get_tree().call_group(
		"strength_branch",
		"stop_combat"
	)

	get_tree().call_group(
		"enemies",
		"stop_combat"
	)

	print(
		"WaveManager zastaven – strom zemřel"
	)
