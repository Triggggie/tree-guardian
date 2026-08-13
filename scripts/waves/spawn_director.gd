class_name SpawnDirector
extends Node


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


@onready var entities: Node2D = $"../Entities"

@onready var left_spawn_point: Marker2D = (
	$"../World/LeftSpawnPoint"
)

@onready var right_spawn_point: Marker2D = (
	$"../World/RightSpawnPoint"
)


func _ready() -> void:
	add_to_group("spawn_director")
	randomize()


func is_ready_to_spawn() -> bool:
	return (
		is_instance_valid(entities)
		and is_instance_valid(left_spawn_point)
		and is_instance_valid(right_spawn_point)
	)


func spawn_wave(
	spawn_requests: Array[EnemySpawnRequest],
	spawn_interval: float,
	should_continue: Callable
) -> bool:
	if not is_ready_to_spawn():
		push_error(
			"SpawnDirector does not have valid scene references."
		)
		return false

	if not should_continue.is_valid():
		push_error(
			"SpawnDirector received an invalid cancellation callback."
		)
		return false

	if spawn_requests.is_empty():
		return _should_continue(should_continue)

	var total_spawn_pairs: int = 0

	for request_index in range(spawn_requests.size()):
		var request: EnemySpawnRequest = (
			spawn_requests[request_index]
		)
		var enemy_id: StringName = &""

		if is_instance_valid(request):
			enemy_id = request.get_enemy_id()

		if (
			not is_instance_valid(request)
			or not request.is_valid_request()
		):
			push_error(
				(
					"SpawnDirector received invalid spawn request "
					+ "%d for enemy '%s'."
				)
				% [
					request_index,
					enemy_id
				]
			)
			return false

		total_spawn_pairs += request.enemies_per_side

	if total_spawn_pairs <= 0:
		return _should_continue(should_continue)

	var safe_spawn_interval: float = max(
		spawn_interval,
		0.0
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

	var global_spawn_index: int = 0

	for request in spawn_requests:
		for _request_spawn_index in range(
			request.enemies_per_side
		):
			if not _should_continue(should_continue):
				return false

			# Každá nová společná řada znovu náhodně
			# promíchá lane, ale v rámci jedné řady
			# použije každou lane jen jednou.
			if (
				global_spawn_index > 0
				and global_spawn_index % safe_lane_count == 0
			):
				left_lane_order.shuffle()
				right_lane_order.shuffle()

			var lane_order_index: int = (
				global_spawn_index % safe_lane_count
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

			var left_spawned: bool = _spawn_enemy(
				request,
				left_spawn_position,
				-1.0,
				left_lane,
				left_lane_y,
				left_queue_order,
				safe_lane_count
			)

			if not left_spawned:
				return false

			var right_spawned: bool = _spawn_enemy(
				request,
				right_spawn_position,
				1.0,
				right_lane,
				right_lane_y,
				right_queue_order,
				safe_lane_count
			)

			if not right_spawned:
				return false

			global_spawn_index += 1

			if global_spawn_index < total_spawn_pairs:
				if safe_spawn_interval > 0.0:
					await get_tree().create_timer(
						safe_spawn_interval
					).timeout

				if not _should_continue(should_continue):
					return false

	return _should_continue(should_continue)


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


func _spawn_enemy(
	request: EnemySpawnRequest,
	spawn_position: Vector2,
	formation_side: float,
	selected_lane: int,
	selected_lane_y: float,
	queue_order: int,
	total_lanes: int
) -> bool:
	var enemy_instance: Node = (
		request.enemy_definition.enemy_scene.instantiate()
	)

	if (
		not is_instance_valid(enemy_instance)
		or not (enemy_instance is Node2D)
	):
		push_error(
			"EnemyDefinition did not instantiate a valid Node2D."
		)

		if is_instance_valid(enemy_instance):
			enemy_instance.free()

		return false

	var enemy: Node2D = enemy_instance as Node2D

	if not enemy.has_method("configure_from_definition"):
		push_error(
			"Enemy scene has no configure_from_definition() method."
		)
		enemy.free()
		return false

	var configured_successfully: bool = bool(
		enemy.call(
			"configure_from_definition",
			request.enemy_definition,
			request.maximum_health,
			request.attack_damage_multiplier
		)
	)

	if not configured_successfully:
		push_error(
			"Enemy scene rejected its EnemyDefinition."
		)
		enemy.free()
		return false

	if not enemy.has_method("configure_stage_context"):
		push_error(
			"Enemy scene has no configure_stage_context() method."
		)
		enemy.free()
		return false

	var stage_configured: bool = bool(
		enemy.call(
			"configure_stage_context",
			request.stage_definition,
			request.global_wave
		)
	)
	if not stage_configured:
		push_error("Enemy scene rejected its StageDefinition.")
		enemy.free()
		return false

	entities.add_child(enemy)
	enemy.global_position = spawn_position

	if not enemy.has_method("setup_crowd_formation"):
		push_error(
			"Enemy scene has no setup_crowd_formation() method."
		)
		enemy.queue_free()
		return false

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

	return true


func _should_continue(
	callback: Callable
) -> bool:
	if not is_inside_tree():
		return false

	if not callback.is_valid():
		return false

	return bool(callback.call())
