class_name ItemDefinition
extends Resource


@export_category("Identity")

@export var item_id: StringName = &""

@export var display_name: String = "Item"

@export_multiline
var description: String = ""


@export_category("Classification")

@export var equipment_slot_id: StringName = &""


@export_category("Presentation")

@export var icon: Texture2D


func is_valid_definition() -> bool:
	return (
		item_id != &""
		and not display_name.strip_edges().is_empty()
		and EquipmentSlotRules.is_valid_slot_id(equipment_slot_id)
	)
