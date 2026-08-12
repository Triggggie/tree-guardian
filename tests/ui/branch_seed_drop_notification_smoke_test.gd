extends Node


const MAIN_WORLD_SCENE: PackedScene = preload("res://scenes/main_world.tscn")
const THORN_CROWN: BranchDefinition = preload(
	"res://resources/branches/thorn_crown_branch_definition.tres"
)
const GUARDIAN_GROVE_STAGE: StageDefinition = preload(
	"res://resources/stages/guardian_grove_stage.tres"
)
const BARK_WARDEN: EnemyDefinition = preload(
	"res://resources/enemies/bark_warden_definition.tres"
)


var failures: Array[String] = []
var storage_path: String


func _ready() -> void:
	storage_path = "user://branch_seed_notification_%d_%d.cfg" % [
		OS.get_process_id(),
		Time.get_ticks_usec()
	]
	remove_storage_file()
	await run_test()
	remove_storage_file()

	if failures.is_empty():
		print("BRANCH SEED DROP NOTIFICATION SMOKE TEST PASS")
		get_tree().quit(0)
		return

	print(
		"BRANCH SEED DROP NOTIFICATION SMOKE TEST FAIL: %d failure(s)"
		% failures.size()
	)
	get_tree().quit(1)


func run_test() -> void:
	var service: BranchSeedService = create_service(storage_path)
	var world: Node = MAIN_WORLD_SCENE.instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame

	var notification := world.get_node_or_null(
		"UI/BranchSeedDropNotification"
	) as BranchSeedDropNotification
	var tree_screen := world.get_node("UI/TreeScreen") as Control
	var wave_manager: Node = world.get_node("WaveManager")
	expect(
		is_instance_valid(notification),
		"MainWorld lacks UI/BranchSeedDropNotification."
	)
	if not is_instance_valid(notification):
		world.queue_free()
		service.queue_free()
		await get_tree().process_frame
		return

	notification.display_duration = 0.08
	notification.bind_branch_seed_service(service)
	var notification_panel := notification.get_node(
		"NotificationPanel"
	) as PanelContainer
	var labels_root: String = "NotificationPanel/Content/Labels/"
	var title_label := notification.get_node(labels_root + "TitleLabel") as Label
	var branch_name_label := notification.get_node(
		labels_root + "BranchNameLabel"
	) as Label
	var tier_label := notification.get_node(labels_root + "TierLabel") as Label
	var source_label := notification.get_node(labels_root + "SourceLabel") as Label
	var hint_label := notification.get_node(labels_root + "HintLabel") as Label

	expect(not notification.visible, "Notification starts visible.")
	expect(
		not get_tree().paused,
		"Game tree starts paused."
	)
	expect(
		wave_manager.call("is_preparation_active")
		and tree_screen.visible,
		"Initial Preparation or TREE is not active."
	)
	expect(
		notification.z_index > tree_screen.z_index,
		"Branch Seed notification is not ordered above TREE."
	)
	expect(
		notification.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and notification_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Notification root or panel blocks mouse input."
	)

	var drop_events: Array[Dictionary] = []
	service.branch_seed_dropped.connect(
		func(branch_id: StringName, enemy_id: StringName, position: Vector2) -> void:
			drop_events.append({
				"branch_id": branch_id,
				"enemy_id": enemy_id,
				"position": position
			})
	)
	var forced_warden: EnemyDefinition = BARK_WARDEN.duplicate(true)
	forced_warden.branch_seed_roll_chance = 1.0
	var drop_position := Vector2(321.0, 654.0)
	var dropped_id: StringName = service.process_enemy_defeat(
		forced_warden,
		GUARDIAN_GROVE_STAGE,
		drop_position
	)
	expect(dropped_id == &"thorn_crown", "Production flow did not drop Thorn Crown.")
	expect(
		service.is_branch_seed_unlocked(&"thorn_crown"),
		"Production flow did not persist the Thorn Crown unlock."
	)
	expect(
		drop_events == [{
			"branch_id": &"thorn_crown",
			"enemy_id": &"bark_warden",
			"position": drop_position
		}],
		"Production branch_seed_dropped data differs."
	)
	expect(notification.visible, "Natural drop did not show the notification.")
	expect(notification_panel.visible, "Notification panel is hidden.")
	expect(title_label.text == "LEGENDARY BRANCH SEED UNLOCKED", "Title differs.")
	expect(branch_name_label.text == THORN_CROWN.display_name, "Branch name differs.")
	expect(
		tier_label.text == THORN_CROWN.get_legendary_tier_display_name()
		and tier_label.text == "Tier I",
		"Tier text differs from BranchDefinition."
	)
	expect(source_label.text == "Dropped by Bark Warden", "Source text differs.")
	expect(
		hint_label.text == "Available in TREE during Preparation",
		"Preparation hint differs."
	)
	expect(
		tree_screen.visible
		and notification.visible
		and wave_manager.call("is_preparation_active"),
		"Drop changed Initial Preparation or failed to overlay TREE."
	)
	expect(not get_tree().paused, "Notification paused gameplay.")

	var first_tween: Tween = notification.presentation_tween
	service.branch_seed_dropped.emit(
		&"thorn_crown",
		&"ancient_bark_colossus",
		Vector2.ZERO
	)
	expect(
		notification.visible
		and notification.presentation_tween != first_tween
		and source_label.text == "Dropped by Ancient Bark Colossus",
		"A second acquisition did not replace and restart the presentation."
	)

	await get_tree().create_timer(0.75).timeout
	expect(not notification.visible, "Notification did not auto-hide.")

	var reloaded: BranchSeedService = create_service(storage_path)
	notification.bind_branch_seed_service(reloaded)
	await get_tree().process_frame
	expect(
		reloaded.is_branch_seed_unlocked(&"thorn_crown")
		and not notification.visible,
		"Disk reload replayed the acquisition notification."
	)

	reloaded.branch_seed_dropped.emit(
		&"missing_branch",
		&"bark_warden",
		Vector2.ZERO
	)
	expect(
		not notification.visible,
		"Unknown Branch showed stale acquisition content."
	)

	reloaded.branch_seed_dropped.emit(
		&"thorn_crown",
		&"missing_enemy",
		Vector2.ZERO
	)
	expect(notification.visible, "Unknown enemy suppressed a valid Branch acquisition.")
	expect(branch_name_label.text == "Thorn Crown", "Unknown enemy changed Branch text.")
	expect(tier_label.text == "Tier I", "Unknown enemy changed Tier text.")
	expect(
		not source_label.visible
		and source_label.text.is_empty()
		and not source_label.text.contains("missing_enemy"),
		"Unknown enemy exposed an internal ID or stale source."
	)
	expect(not get_tree().paused, "Fallback presentation paused gameplay.")
	await get_tree().create_timer(0.75).timeout
	expect(not notification.visible, "Fallback presentation did not auto-hide.")

	world.queue_free()
	service.queue_free()
	reloaded.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func create_service(path: String) -> BranchSeedService:
	var service := BranchSeedService.new()
	service.initialize(path)
	add_child(service)
	return service


func remove_storage_file() -> void:
	if FileAccess.file_exists(storage_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(storage_path))


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
