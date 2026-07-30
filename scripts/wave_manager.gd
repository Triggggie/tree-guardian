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
@export_range(1, 1000, 1)
var waves_per_stage: int = 100

@export var base_enemies_per_side: int = 2
@export var waves_per_enemy_increase: int = 3
@export var maximum_enemies_per_side: int = 30
@export var time_between_spawns: float = 0.25

@export var wave_complete_message_duration: float = 0.7
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

@onready var game_over_panel: Panel = (
	$"../UI/GameOverPanel"
)


var tree_node: Node2D

# Interní celkové číslo vlny.
# Například:
# Stage 1 = 1–100
# Stage 2 = 101–200
# Stage 3 = 201–300
var current_wave: int = 0

var tree_defeated: bool = false

# Každý nový běh vln dostane jiné ID.
# Staré asynchronní čekání se tím bezpečně zneplatní.
var wave_cycle_id: int = 0


func _ready() -> void:
	add_to_group("wave_manager")

	randomize()

	tree_node = (
		get_tree().get_first_node_in_group("tree")
		as Node2D
	)

	if (
		is_instance_valid(tree_node)
		and tree_node.has_signal("died")
	):
		tree_node.died.connect(
			_on_tree_died
		)

	if (
		is_instance_valid(game_over_panel)
		and game_over_panel.has_signal(
			"retry_requested"
		)
	):
		game_over_panel.retry_requested.connect(
			_on_retry_requested
		)

	start_wave_cycle(false)


func start_wave_cycle(
	retry_current_wave: bool
) -> void:
	wave_cycle_id += 1

	var new_cycle_id: int = wave_cycle_id

	run_wave_loop(
		new_cycle_id,
		retry_current_wave
	)


func run_wave_loop(
	cycle_id: int,
	retry_current_wave: bool
) -> void:
	var repeat_wave: bool = retry_current_wave

	while cycle_id == wave_cycle_id:
		if tree_defeated:
			return

		if not repeat_wave:
			current_wave += 1

		repeat_wave = false

		var enemy_count: int = (
			get_current_enemies_per_side()
		)

		wave_changed.emit(
			current_wave,
			enemy_count
		)

		print(
			"Začíná Stage ",
			get_current_stage_number(),
			" | Wave ",
			get_current_wave_in_stage(),
			"/",
			get_safe_waves_per_stage(),
			" | globální vlna ",
			current_wave,
			" | nepřátel na každé straně: ",
			enemy_count,
			" | HP nepřítele: ",
			get_current_enemy_health()
		)

		await spawn_wave(
			enemy_count,
			cycle_id
		)

		if not is_cycle_active(cycle_id):
			return

		await wait_until_all_enemies_are_dead(
			cycle_id
		)

		if not is_cycle_active(cycle_id):
			return

		complete_wave()

		await show_wave_complete_message(
			cycle_id
		)

		if not is_cycle_active(cycle_id):
			return

		await get_tree().create_timer(
			time_between_waves
		).timeout

		if not is_cycle_active(cycle_id):
			return


func is_cycle_active(cycle_id: int) -> bool:
	return (
		cycle_id == wave_cycle_id
		and not tree_defeated
	)


func get_safe_waves_per_stage() -> int:
	return max(
		waves_per_stage,
		1
	)


func get_current_stage_number() -> int:
	var safe_current_wave: int = max(
		current_wave,
		1
	)

	return int(
		floor(
			float(safe_current_wave - 1)
			/ float(get_safe_waves_per_stage())
		)
	) + 1


func get_current_wave_in_stage() -> int:
	var safe_current_wave: int = max(
		current_wave,
		1
	)

	return (
		(safe_current_wave - 1)
		% get_safe_waves_per_stage()
	) + 1


func get_current_stage_start_wave() -> int:
	var current_stage: int = (
		get_current_stage_number()
	)

	return (
		(current_stage - 1)
		* get_safe_waves_per_stage()
		+ 1
	)


func get_current_enemies_per_side() -> int:
	var safe_interval: int = max(
		waves_per_enemy_increase,
		1
	)

	var additional_enemies: int = int(
		floor(
			float(current_wave - 1)
			/ float(safe_interval)
		)
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


func spawn_wave(
	enemy_count: int,
	cycle_id: int
) -> void:
	var enemy_health: float = (
		get_current_enemy_health()
	)

	var safe_lane_count: int = max(
		lane_count,
		1
	)

	var left_lane_counts: Array[int] = []
	var right_lane_counts: Array[int] = []

	var left_lane_order: Array[int] = []
	var right_lane_order: Array[int] = []

	for lane in range(safe_lane_count):
		left_lane_counts.append(0)
		right_lane_counts.append(0)

		left_lane_order.append(lane)
		right_lane_order.append(lane)

	left_lane_order.shuffle()
	right_lane_order.shuffle()

	for index in range(enemy_count):
		if not is_cycle_active(cycle_id):
			return

		# Každá nová řada znovu náhodně promíchá lane,
		# ale v rámci jedné řady použije každou lane jen jednou.
		if (
			index > 0
			and index % safe_lane_count == 0
		):
			left_lane_order.shuffle()
			right_lane_order.shuffle()

		var lane_order_index: int = (
			index % safe_lane_count
		)

		var left_lane: int = (
			left_lane_order[lane_order_index]
		)

		var right_lane: int = (
			right_lane_order[lane_order_index]
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
	if tree_defeated:
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


func wait_until_all_enemies_are_dead(
	cycle_id: int
) -> void:
	while not get_tree().get_nodes_in_group(
		"enemies"
	).is_empty():
		if not is_cycle_active(cycle_id):
			return

		await get_tree().process_frame


func complete_wave() -> void:
	if tree_defeated:
		return

	print(
		"Stage ",
		get_current_stage_number(),
		" | Wave ",
		get_current_wave_in_stage(),
		" dokončena"
	)

	if (
		is_instance_valid(tree_node)
		and tree_node.has_method("add_age")
	):
		tree_node.add_age(1)


func show_wave_complete_message(
	cycle_id: int
) -> void:
	if not is_cycle_active(cycle_id):
		return

	wave_message_changed.emit(
		"WAVE %d COMPLETE"
		% get_current_wave_in_stage()
	)

	await get_tree().create_timer(
		wave_complete_message_duration
	).timeout

	if cycle_id != wave_cycle_id:
		return

	wave_message_changed.emit("")


func _on_tree_died() -> void:
	if tree_defeated:
		return

	tree_defeated = true

	# Okamžitě zneplatníme aktuální vlnový cyklus.
	wave_cycle_id += 1

	wave_message_changed.emit("")

	get_tree().call_group(
		"combat_branch",
		"stop_combat"
	)

	get_tree().call_group(
		"enemies",
		"stop_combat"
	)

	remove_remaining_enemies()

	print(
		"Strom zemřel ve Stage ",
		get_current_stage_number(),
		" | Wave ",
		get_current_wave_in_stage(),
		" – po oživení začne Stage znovu"
	)


func remove_remaining_enemies() -> void:
	var enemies: Array[Node] = (
		get_tree().get_nodes_in_group("enemies")
	)

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		enemy.remove_from_group("enemies")
		enemy.queue_free()


func _on_retry_requested() -> void:
	if not tree_defeated:
		return

	var failed_stage: int = (
		get_current_stage_number()
	)

	var failed_wave_in_stage: int = (
		get_current_wave_in_stage()
	)

	var stage_start_wave: int = (
		get_current_stage_start_wave()
	)

	remove_remaining_enemies()

	if (
		is_instance_valid(tree_node)
		and tree_node.has_method("revive")
	):
		tree_node.revive()

	get_tree().call_group(
		"combat_branch",
		"resume_combat"
	)

	# Cyklus při spuštění automaticky přičte +1.
	# Proto nastavíme globální vlnu na číslo
	# těsně před začátkem aktuální Stage.
	current_wave = stage_start_wave - 1

	tree_defeated = false

	print(
		"Strom byl oživen | selhání ve Stage ",
		failed_stage,
		" | Wave ",
		failed_wave_in_stage,
		" | Stage ",
		failed_stage,
		" začíná znovu od Wave 1"
	)

	start_wave_cycle(false)
