extends Button


var talent_id: StringName = &""


func setup(
	new_talent_id: StringName,
	display_name: String
) -> void:
	talent_id = new_talent_id
	text = display_name


func get_talent_id() -> StringName:
	return talent_id
