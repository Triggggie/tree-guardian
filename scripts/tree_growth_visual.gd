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
	Vector2(2.0, -124.0),
	Vector2(2.775, -127.65),
	Vector2(0.8, -150.4),
	Vector2(1.575, -159.075)
]

const STAGE_SCALES: Array[Vector2] = [
	Vector2(2.0, 2.0),
	Vector2(1.85, 1.85),
	Vector2(1.6, 1.6),
	Vector2(1.575, 1.575)
]

# Presentation-only marker positions tuned to the authored branch junctions
# in each Tree sprite. BranchMount child offsets remain stable, so equipped
# runtime Branch instances follow their existing parent without recreation.
const STAGE_ATTACHMENT_POSITIONS: Array[Dictionary] = [
	{
		&"LeftLower": Vector2(-12.0, 106.0),
		&"RightLower": Vector2(12.0, 106.0),
		&"LeftUpper": Vector2(-9.0, 64.0),
		&"RightUpper": Vector2(9.0, 64.0),
		&"Apex": Vector2(0.0, 0.0)
	},
	{
		&"LeftLower": Vector2(-26.0, 100.0),
		&"RightLower": Vector2(26.0, 100.0),
		&"LeftUpper": Vector2(-25.0, 24.0),
		&"RightUpper": Vector2(25.0, 24.0),
		&"Apex": Vector2(0.0, -76.0)
	},
	{
		&"LeftLower": Vector2(-18.0, 60.0),
		&"RightLower": Vector2(18.0, 60.0),
		&"LeftUpper": Vector2(-21.0, -9.0),
		&"RightUpper": Vector2(21.0, -9.0),
		&"Apex": Vector2(0.0, -99.0)
	},
	{
		&"LeftLower": Vector2(-28.0, 57.0),
		&"RightLower": Vector2(28.0, 57.0),
		&"LeftUpper": Vector2(-24.0, -27.0),
		&"RightUpper": Vector2(24.0, -27.0),
		&"Apex": Vector2(0.0, -93.0)
	}
]


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
	base_tree_sprite.scale = STAGE_SCALES[stage_index]
	apply_attachment_layout(stage_index)


func apply_attachment_layout(stage_index: int) -> void:
	var attachment_points: Node = get_parent().get_node_or_null(
		"AttachmentPoints"
	)

	if attachment_points == null:
		return

	var stage_layout: Dictionary = (
		STAGE_ATTACHMENT_POSITIONS[stage_index]
	)

	for attachment_name: StringName in stage_layout:
		var attachment_point: Node2D = attachment_points.get_node_or_null(
			NodePath(String(attachment_name))
		) as Node2D

		if attachment_point == null:
			continue

		attachment_point.position = stage_layout[attachment_name]


func get_current_stage() -> int:
	return current_stage


func _on_tree_age_changed(new_age: int) -> void:
	refresh_for_age(new_age)
