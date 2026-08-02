extends Label


@onready var wave_manager: Node = $"../../WaveManager"


func _ready() -> void:
	if wave_manager == null:
		text = "Wave: ?"
		return

	wave_manager.wave_changed.connect(_on_wave_changed)

	_on_wave_changed(
		wave_manager.current_wave,
		wave_manager.get_current_enemies_per_side()
	)


func _on_wave_changed(
	_new_global_wave: int,
	enemies_per_side: int
) -> void:
	text = (
		"%s\n"
		+ "Enemies per side: %d"
	) % [
		wave_manager.get_current_progress_code(),
		enemies_per_side
	]
