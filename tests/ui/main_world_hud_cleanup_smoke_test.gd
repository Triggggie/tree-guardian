extends Node


const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")


func _ready() -> void:
	var world: Node = MAIN_WORLD_SCENE.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(world)
	await get_tree().process_frame
	var ui: CanvasLayer = world.get_node("UI") as CanvasLayer
	var passed: bool = (
		ui.get_node_or_null("BranchInfoLabel") == null
		and ui.get_node_or_null("HealthBar") is ProgressBar
		and ui.get_node_or_null("UpgradeTabs") is HBoxContainer
		and ui.get_node_or_null("BranchUpgradePanel") is Panel
	)
	world.queue_free()
	await get_tree().process_frame
	if passed:
		print("MAIN WORLD HUD CLEANUP SMOKE TEST PASS")
		get_tree().quit(0)
		return
	push_error("Left debug overlay remained or required HUD controls were removed.")
	get_tree().quit(1)
