class_name ContentService
extends Node


const DEFAULT_REGISTRY: ContentRegistry = preload(
	"res://resources/content_registry.tres"
)


var registry: ContentRegistry


func _ready() -> void:
	registry = DEFAULT_REGISTRY

	registry.rebuild_indexes()

	var validation_errors: Array[String] = (
		ContentValidator.validate_registry(
			registry
		)
	)

	for validation_error in validation_errors:
		push_error(
			validation_error
		)


func get_tree_souls() -> Array[TreeSoulDefinition]:
	if registry == null:
		return []

	return registry.tree_souls


func get_tree_soul(
	tree_soul_id: StringName
) -> TreeSoulDefinition:
	if registry == null:
		return null

	return registry.get_tree_soul_definition(
		tree_soul_id
	)
