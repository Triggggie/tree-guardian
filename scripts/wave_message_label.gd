extends Label


@onready var wave_manager: Node = $"../../WaveManager"


func _ready() -> void:
	hide()

	if not is_instance_valid(wave_manager):
		return

	if wave_manager.has_signal("wave_message_changed"):
		wave_manager.wave_message_changed.connect(
			_on_wave_message_changed
		)


func _on_wave_message_changed(
	message: String
) -> void:
	if message.is_empty():
		hide()
		return

	text = message
	show()
