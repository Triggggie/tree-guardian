extends Node


signal wave_changed(
	new_wave: int,
	enemies_per_side: int
)


const BARK_BEETLE_SCENE: PackedScene = preload(
	"res://scenes/enemies/bark_beetle.tscn"
)


@export_category("Wave")
@export var base_enemies_per_side: int = 2
@export var waves_per_enemy_increase: int = 3
@export var maximum_enemies_per_side: int = 10

@export var time_between_spawns: float = 0.35
@export var time_between_waves: float = 2.0
@export var spawn_spacing: float = 90.0

@onready var entities: Node2D = $"../Entities"
@onready var left_spawn_point: Marker2D = $"../World/LeftSpawnPoint"
@onready var right_spawn_point: Marker2D = $"../World/RightSpawnPoint"
@onready var tree_node: Node = get_tree().get_first_node_in_group("tree")

var current_wave: int = 0


func _ready() -> void:
	add_to_group("wave_manager")
	run_wave_loop()


func run_wave_loop() -> void:
	while true:
		current_wave += 1

		var enemy_count: int = get_current_enemies_per_side()

		wave_changed.emit(
			current_wave,
			enemy_count
		)

		print(
			"Začíná vlna ",
			current_wave,
			" | nepřátel na každé straně: ",
			enemy_count
		)

		await spawn_wave(enemy_count)
		await wait_until_all_enemies_are_dead()

		complete_wave()

		await get_tree().create_timer(
			time_between_waves
		).timeout


func get_current_enemies_per_side() -> int:
	var safe_interval: int = max(
		waves_per_enemy_increase,
		1
	)

	var additional_enemies: int = (
		(current_wave - 1) / safe_interval
	)

	return min(
		base_enemies_per_side + additional_enemies,
		maximum_enemies_per_side
	)


func spawn_wave(enemy_count: int) -> void:
	for index in range(enemy_count):
		var offset: float = index * spawn_spacing

		var left_position: Vector2 = (
			left_spawn_point.global_position
			+ Vector2(-offset, 0.0)
		)

		var right_position: Vector2 = (
			right_spawn_point.global_position
			+ Vector2(offset, 0.0)
		)

		spawn_enemy(left_position)
		spawn_enemy(right_position)

		if index < enemy_count - 1:
			await get_tree().create_timer(
				time_between_spawns
			).timeout


func spawn_enemy(spawn_position: Vector2) -> void:
	var enemy: Node2D = (
		BARK_BEETLE_SCENE.instantiate() as Node2D
	)

	entities.add_child(enemy)
	enemy.global_position = spawn_position


func wait_until_all_enemies_are_dead() -> void:
	while not get_tree().get_nodes_in_group("enemies").is_empty():
		await get_tree().process_frame


func complete_wave() -> void:
	print("Vlna ", current_wave, " dokončena")

	if (
		is_instance_valid(tree_node)
		and tree_node.has_method("add_age")
	):
		tree_node.add_age(1)
