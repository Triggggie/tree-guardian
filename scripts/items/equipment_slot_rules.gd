class_name EquipmentSlotRules
extends RefCounted


const BARK_SLOT_ID: StringName = &"bark"
const ROOTS_SLOT_ID: StringName = &"roots"
const HEARTWOOD_SLOT_ID: StringName = &"heartwood"
const CANOPY_SLOT_ID: StringName = &"canopy"
const SAP_SLOT_ID: StringName = &"sap"

const SUPPORTED_SLOT_IDS: Array[StringName] = [
	BARK_SLOT_ID,
	ROOTS_SLOT_ID,
	HEARTWOOD_SLOT_ID,
	CANOPY_SLOT_ID,
	SAP_SLOT_ID
]


static func is_valid_slot_id(slot_id: StringName) -> bool:
	return slot_id in SUPPORTED_SLOT_IDS


static func get_slot_display_name(slot_id: StringName) -> String:
	match slot_id:
		BARK_SLOT_ID:
			return "Bark"
		ROOTS_SLOT_ID:
			return "Roots"
		HEARTWOOD_SLOT_ID:
			return "Heartwood"
		CANOPY_SLOT_ID:
			return "Canopy"
		SAP_SLOT_ID:
			return "Sap"

	return ""


static func get_supported_slot_ids() -> Array[StringName]:
	return SUPPORTED_SLOT_IDS.duplicate()
