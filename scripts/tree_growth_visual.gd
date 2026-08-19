class_name TreeGrowthVisual
extends Node2D


const STAGE_1: int = 1
const STAGE_2: int = 2
const STAGE_3: int = 3
const STAGE_4: int = 4

const STAGE_2_AGE: int = 40
const STAGE_3_AGE: int = 80
const STAGE_4_AGE: int = 200

const TREE_TEXTURES: Array[Texture2D] = [
	preload("res://resources/tree/growth/guardian_tree_stage_1.png"),
	preload("res://resources/tree/growth/guardian_tree_stage_2.png"),
	preload("res://resources/tree/growth/guardian_tree_stage_3.png"),
	preload("res://resources/tree/growth/guardian_tree_stage_4.png")
]

# Each authored sprite uses a 256x256 canvas. These offsets center the
# opaque artwork and place its lowest root pixel on the Tree origin.
const STAGE_POSITIONS: Array[Vector2] = [
	Vector2(0.75, -93.0),
	Vector2(2.25, -103.5),
	Vector2(-0.75, -141.0),
	Vector2(0.0, -151.5)
]

const TREE_VISUAL_SCALE: Vector2 = Vector2(1.5, 1.5)


@onready var base_tree_sprite: Sprite2D = $BaseTreeSprite


var current_stage: int = STAGE_1


func _ready() -> void:
	var tree_node: Node = get_parent()

	if tree_node.has_signal("age_changed"):
		tree_node.age_changed.connect(
			_on_tree_age_changed
		)

	refresh_for_age(
		int(tree_node.get("age"))
	)


static func resolve_stage_for_age(tree_age: int) -> int:
	if tree_age >= STAGE_4_AGE:
		return STAGE_4

	if tree_age >= STAGE_3_AGE:
		return STAGE_3

	if tree_age >= STAGE_2_AGE:
		return STAGE_2

	return STAGE_1


func refresh_for_age(tree_age: int) -> void:
	current_stage = resolve_stage_for_age(tree_age)

	var stage_index: int = current_stage - 1
	base_tree_sprite.texture = TREE_TEXTURES[stage_index]
	base_tree_sprite.position = STAGE_POSITIONS[stage_index]
	base_tree_sprite.scale = TREE_VISUAL_SCALE


func get_current_stage() -> int:
	return current_stage


func _on_tree_age_changed(new_age: int) -> void:
	refresh_for_age(new_age)
