class_name ItemAffixRoll
extends RefCounted


var stat_id: StringName = &""
var value: float = 0.0


func _init(
	initial_stat_id: StringName = &"",
	initial_value: float = 0.0
) -> void:
	stat_id = initial_stat_id
	value = initial_value


func is_valid_data() -> bool:
	return stat_id != &""
