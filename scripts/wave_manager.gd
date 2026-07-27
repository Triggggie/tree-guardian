extends Node


const BARK_BEETLE_SCENE: PackedScene = preload(
	"res://scenes/enemies/bark_beetle.tscn"
)


@export_category("Wave")
@export var enemies_per_side: int = 2
@export var time_between_spawns: float = 0.35
@export var time_between_waves: float = 2.0

@onready var entities: Node2D = $"../Entities"
@onready var left_spawn_point: Marker2D = $"../World/LeftSpawnPoint"
@onready var right_spawn_point: Marker2D = $"../World/RightSpawnPoint"
@onready var tree_node: Node = get_tree().get_first_node_in_group("tree")

var current_wave: int = 0
var wave_running: bool = false


func _ready() -> void:
	start_next_wave()


func start_next_wave() -> void:
	if wave_running:
		return

	wave_running = true
	current_wave += 1

	print("Začíná vlna ", current_wave)

	await spawn_wave()
	await wait_until_all_enemies_are_dead()

	complete_wave()


func spawn_wave() -> void:
	for index in range(enemies_per_side):
		spawn_enemy(left_spawn_point.global_position)
		spawn_enemy(right_spawn_point.global_position)

		if index < enemies_per_side - 1:
			await get_tree().create_timer(
				time_between_spawns
			).timeout


func spawn_enemy(spawn_position: Vector2) -> void:
	var enemy: Node2D = BARK_BEETLE_SCENE.instantiate() as Node2D

	entities.add_child(enemy)
	enemy.global_position = spawn_position


func wait_until_all_enemies_are_dead() -> void:
	while not get_tree().get_nodes_in_group("enemies").is_empty():
		await get_tree().process_frame


func complete_wave() -> void:
	wave_running = false

	print("Vlna ", current_wave, " dokončena")

	if (
		is_instance_valid(tree_node)
		and tree_node.has_method("add_age")
	):
		tree_node.add_age(1)

	await get_tree().create_timer(time_between_waves).timeout
	start_next_wave()
