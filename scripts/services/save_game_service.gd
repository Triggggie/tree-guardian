class_name SaveGameService
extends Node


const DEFAULT_STORAGE_PATH: String = "user://player_progress.cfg"
const SAVE_VERSION: int = 1
const PROGRESS_SAVE_DELAY: float = 0.75

const METADATA_SECTION: String = "metadata"
const VERSION_KEY: String = "version"
const INVENTORY_SECTION: String = "inventory"
const INVENTORY_ITEMS_KEY: String = "items"
const EQUIPMENT_SECTION: String = "equipment"
const EQUIPMENT_LOADOUT_KEY: String = "equipped_instance_ids_by_slot_id"
const BRANCH_PROGRESS_SECTION: String = "branch_progress"
const BRANCH_PROGRESS_RECORDS_KEY: String = "records"
const TALENT_LOADOUTS_KEY: String = "talent_loadouts"
const BRANCH_LOADOUT_SECTION: String = "branch_loadout"
const BRANCH_LOADOUT_KEY: String = "equipped_branch_ids_by_slot_id"


var storage_path: String = DEFAULT_STORAGE_PATH
var is_restoring: bool = false
var writes_disabled_due_to_unsupported_version: bool = false
var save_request_pending: bool = false
var autosave_connected: bool = false
var progress_save_timer: Timer

var inventory: InventoryService
var equipment: EquipmentService
var equipment_stats: EquipmentStatService
var equipment_loot: EquipmentLootService
var branch_seeds: BranchSeedService
var branch_progress: BranchProgressService
var branch_loadout: BranchLoadoutService


func _ready() -> void:
	_ensure_progress_save_timer()
	if _is_test_scene_run():
		return
	initialize()


func _exit_tree() -> void:
	_disconnect_autosave_signals()


func initialize(storage_path_override: String = "") -> bool:
	_disconnect_autosave_signals()
	storage_path = (
		storage_path_override
		if not storage_path_override.is_empty()
		else DEFAULT_STORAGE_PATH
	)
	writes_disabled_due_to_unsupported_version = false
	_resolve_services()
	_ensure_progress_save_timer()
	var loaded: bool = load_now()
	_connect_autosave_signals()
	return loaded


func save_now() -> bool:
	if is_restoring or writes_disabled_due_to_unsupported_version:
		return false
	if not _services_are_valid():
		push_warning("SaveGame could not save because required services are missing.")
		return false

	var progress_state: Dictionary = branch_progress.export_persistence_state()
	var config := ConfigFile.new()
	config.set_value(METADATA_SECTION, VERSION_KEY, SAVE_VERSION)
	config.set_value(
		INVENTORY_SECTION,
		INVENTORY_ITEMS_KEY,
		inventory.export_persistence_state()
	)
	config.set_value(
		EQUIPMENT_SECTION,
		EQUIPMENT_LOADOUT_KEY,
		equipment.export_persistence_state()
	)
	config.set_value(
		BRANCH_PROGRESS_SECTION,
		BRANCH_PROGRESS_RECORDS_KEY,
		progress_state.get("records", [])
	)
	config.set_value(
		BRANCH_PROGRESS_SECTION,
		TALENT_LOADOUTS_KEY,
		progress_state.get("talent_loadouts", [])
	)
	config.set_value(
		BRANCH_LOADOUT_SECTION,
		BRANCH_LOADOUT_KEY,
		branch_loadout.export_persistence_state()
	)
	var save_error: Error = config.save(storage_path)
	if save_error == OK:
		return true
	push_warning(
		"SaveGame could not save '%s' (error %d)."
		% [storage_path, save_error]
	)
	return false


func request_save() -> void:
	if (
		is_restoring
		or writes_disabled_due_to_unsupported_version
		or save_request_pending
	):
		return
	save_request_pending = true
	call_deferred("_flush_requested_save")


func load_now() -> bool:
	if not _services_are_valid():
		_resolve_services()
	if not _services_are_valid():
		push_warning("SaveGame could not load because required services are missing.")
		return false

	var config := ConfigFile.new()
	var load_error: Error = config.load(storage_path)
	if load_error == ERR_FILE_NOT_FOUND:
		writes_disabled_due_to_unsupported_version = false
		return _restore_parsed_state([], {}, [], [], {})
	if load_error != OK:
		writes_disabled_due_to_unsupported_version = true
		push_warning(
			"SaveGame could not load '%s' (error %d)."
			% [storage_path, load_error]
		)
		return false

	var version_value = config.get_value(METADATA_SECTION, VERSION_KEY, 0)
	if version_value is not int:
		writes_disabled_due_to_unsupported_version = true
		push_warning("SaveGame found a malformed save version in '%s'." % storage_path)
		return false
	var stored_version: int = int(version_value)
	if stored_version > SAVE_VERSION:
		writes_disabled_due_to_unsupported_version = true
		push_warning(
			"SaveGame found future save version %d in '%s'; writes are disabled."
			% [stored_version, storage_path]
		)
		return false
	if stored_version < SAVE_VERSION:
		writes_disabled_due_to_unsupported_version = true
		push_warning(
			"SaveGame found unsupported legacy save version %d in '%s'."
			% [stored_version, storage_path]
		)
		return _migrate_legacy_save(config, stored_version)

	var stored_items = config.get_value(
		INVENTORY_SECTION, INVENTORY_ITEMS_KEY, []
	)
	var stored_equipment = config.get_value(
		EQUIPMENT_SECTION, EQUIPMENT_LOADOUT_KEY, {}
	)
	var stored_progress = config.get_value(
		BRANCH_PROGRESS_SECTION, BRANCH_PROGRESS_RECORDS_KEY, []
	)
	var stored_talents = config.get_value(
		BRANCH_PROGRESS_SECTION, TALENT_LOADOUTS_KEY, []
	)
	var stored_branch_loadout = config.get_value(
		BRANCH_LOADOUT_SECTION, BRANCH_LOADOUT_KEY, {}
	)
	if (
		stored_items is not Array
		or stored_equipment is not Dictionary
		or stored_progress is not Array
		or stored_talents is not Array
		or stored_branch_loadout is not Dictionary
	):
		writes_disabled_due_to_unsupported_version = true
		push_warning("SaveGame found malformed top-level data in '%s'." % storage_path)
		return false

	writes_disabled_due_to_unsupported_version = false
	return _restore_parsed_state(
		stored_items,
		stored_equipment,
		stored_progress,
		stored_talents,
		stored_branch_loadout
	)


func reload_from_disk() -> bool:
	return load_now()


func set_storage_path_for_testing(storage_path_override: String) -> bool:
	if not OS.is_debug_build() or storage_path_override.is_empty():
		return false
	storage_path = storage_path_override
	writes_disabled_due_to_unsupported_version = false
	return true


func get_progress_save_timer_for_testing() -> Timer:
	return progress_save_timer


func _restore_parsed_state(
	stored_items: Array,
	stored_equipment: Dictionary,
	stored_progress: Array,
	stored_talents: Array,
	stored_branch_loadout: Dictionary
) -> bool:
	is_restoring = true
	save_request_pending = false
	if is_instance_valid(progress_save_timer):
		progress_save_timer.stop()
	equipment.restore_equipment_loadout({})
	var restored: bool = inventory.restore_persistence_state(stored_items)
	restored = equipment.restore_equipment_loadout(stored_equipment) and restored
	restored = branch_progress.restore_persistence_state({
		"records": stored_progress,
		"talent_loadouts": stored_talents
	}) and restored
	restored = branch_loadout.restore_persistence_state(
		stored_branch_loadout,
		branch_seeds
	) and restored
	equipment_stats.rebuild_from_equipment()
	equipment_loot.reconcile_instance_counter_from_inventory()
	is_restoring = false
	return restored


func _migrate_legacy_save(_config: ConfigFile, _stored_version: int) -> bool:
	return false


func _resolve_services() -> void:
	inventory = get_node_or_null("/root/Inventory") as InventoryService
	equipment = get_node_or_null("/root/Equipment") as EquipmentService
	equipment_stats = get_node_or_null(
		"/root/EquipmentStats"
	) as EquipmentStatService
	equipment_loot = get_node_or_null(
		"/root/EquipmentLoot"
	) as EquipmentLootService
	branch_seeds = get_node_or_null("/root/BranchSeeds") as BranchSeedService
	branch_progress = get_node_or_null(
		"/root/BranchProgress"
	) as BranchProgressService
	branch_loadout = get_node_or_null(
		"/root/BranchLoadout"
	) as BranchLoadoutService


func _services_are_valid() -> bool:
	return (
		is_instance_valid(inventory)
		and is_instance_valid(equipment)
		and is_instance_valid(equipment_stats)
		and is_instance_valid(equipment_loot)
		and is_instance_valid(branch_seeds)
		and is_instance_valid(branch_progress)
		and is_instance_valid(branch_loadout)
	)


func _ensure_progress_save_timer() -> void:
	if is_instance_valid(progress_save_timer):
		return
	progress_save_timer = Timer.new()
	progress_save_timer.name = "ProgressSaveTimer"
	progress_save_timer.one_shot = true
	progress_save_timer.wait_time = PROGRESS_SAVE_DELAY
	progress_save_timer.timeout.connect(_on_progress_save_timer_timeout)
	add_child(progress_save_timer)


func _connect_autosave_signals() -> void:
	if autosave_connected or not _services_are_valid():
		return
	inventory.item_added.connect(_on_immediate_persistence_changed)
	inventory.item_removed.connect(_on_immediate_persistence_changed)
	equipment.equipment_slot_changed.connect(_on_equipment_changed)
	branch_loadout.standard_slot_changed.connect(_on_standard_loadout_changed)
	branch_loadout.apex_slot_changed.connect(_on_apex_loadout_changed)
	branch_progress.progress_changed.connect(_on_branch_progress_changed)
	autosave_connected = true


func _disconnect_autosave_signals() -> void:
	if not autosave_connected:
		return
	if is_instance_valid(inventory):
		if inventory.item_added.is_connected(_on_immediate_persistence_changed):
			inventory.item_added.disconnect(_on_immediate_persistence_changed)
		if inventory.item_removed.is_connected(_on_immediate_persistence_changed):
			inventory.item_removed.disconnect(_on_immediate_persistence_changed)
	if (
		is_instance_valid(equipment)
		and equipment.equipment_slot_changed.is_connected(_on_equipment_changed)
	):
		equipment.equipment_slot_changed.disconnect(_on_equipment_changed)
	if is_instance_valid(branch_loadout):
		if branch_loadout.standard_slot_changed.is_connected(
			_on_standard_loadout_changed
		):
			branch_loadout.standard_slot_changed.disconnect(
				_on_standard_loadout_changed
			)
		if branch_loadout.apex_slot_changed.is_connected(_on_apex_loadout_changed):
			branch_loadout.apex_slot_changed.disconnect(_on_apex_loadout_changed)
	if (
		is_instance_valid(branch_progress)
		and branch_progress.progress_changed.is_connected(
			_on_branch_progress_changed
		)
	):
		branch_progress.progress_changed.disconnect(_on_branch_progress_changed)
	autosave_connected = false


func _on_immediate_persistence_changed(_instance_id: StringName) -> void:
	request_save()


func _on_equipment_changed(
	_slot_id: StringName,
	_previous_instance_id: StringName,
	_new_instance_id: StringName
) -> void:
	request_save()


func _on_standard_loadout_changed(
	_slot_id: StringName,
	_previous_branch_id: StringName,
	_new_branch_id: StringName
) -> void:
	request_save()


func _on_apex_loadout_changed(
	_previous_branch_id: StringName,
	_new_branch_id: StringName
) -> void:
	request_save()


func _on_branch_progress_changed(_branch_id: StringName) -> void:
	if is_restoring or writes_disabled_due_to_unsupported_version:
		return
	if progress_save_timer.is_stopped():
		progress_save_timer.start()


func _on_progress_save_timer_timeout() -> void:
	request_save()


func _flush_requested_save() -> void:
	if not save_request_pending:
		return
	save_request_pending = false
	save_now()


func _is_test_scene_run() -> bool:
	if not OS.is_debug_build():
		return false
	for argument in OS.get_cmdline_args():
		var normalized_argument: String = String(argument).replace("\\", "/")
		if (
			normalized_argument.begins_with("res://tests/")
			or normalized_argument.contains("/tests/")
		):
			return true
	return false
