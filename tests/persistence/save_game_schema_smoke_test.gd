extends Node


const TEST_PATH: String = "user://save_game_schema_smoke_test.cfg"

var failures: Array[String] = []


func _ready() -> void:
	cleanup_file()
	expect(SaveGame.initialize(TEST_PATH), "Missing test save was not accepted.")
	var item := create_item(&"schema_item", &"living_bark", 7)
	expect(Inventory.add_item(item), "Schema fixture item add failed.")
	await get_tree().process_frame
	expect(FileAccess.file_exists(TEST_PATH), "Inventory item_added did not autosave.")
	expect(Equipment.equip_item(item.instance_id), "Schema Equipment fixture failed.")
	await get_tree().process_frame
	var autosave_config := ConfigFile.new()
	autosave_config.load(TEST_PATH)
	var autosaved_equipment: Dictionary = autosave_config.get_value(
		"equipment", "equipped_instance_ids_by_slot_id", {}
	)
	expect(autosaved_equipment.get("bark", "") == "schema_item", "Equipment change did not autosave.")
	expect(BranchLoadout.equip_standard_branch(&"standard_slot_1", &"blossom_branch"), "Schema Branch Loadout fixture failed.")
	await get_tree().process_frame
	autosave_config = ConfigFile.new()
	autosave_config.load(TEST_PATH)
	var autosaved_branches: Dictionary = autosave_config.get_value(
		"branch_loadout", "equipped_branch_ids_by_slot_id", {}
	)
	expect(autosaved_branches.get("standard_slot_1", "") == "blossom_branch", "Branch Loadout change did not autosave.")
	BranchProgress.progress_changed.emit(&"strength_branch")
	var progress_timer: Timer = SaveGame.get_progress_save_timer_for_testing()
	var first_time_left: float = progress_timer.time_left
	BranchProgress.progress_changed.emit(&"strength_branch")
	expect(
		not progress_timer.is_stopped()
		and progress_timer.time_left <= first_time_left
		and SaveGame.get_node("ProgressSaveTimer") == progress_timer,
		"Branch Progress changes did not coalesce into one pending Timer."
	)
	expect(SaveGame.save_now(), "Schema explicit save failed.")
	var config := ConfigFile.new()
	expect(config.load(TEST_PATH) == OK, "Schema save could not be reloaded.")
	expect(
		config.get_value("metadata", "version", 0) == SaveGameService.SAVE_VERSION
		and config.has_section_key("inventory", "items")
		and config.has_section_key("equipment", "equipped_instance_ids_by_slot_id")
		and config.has_section_key("branch_progress", "records")
		and config.has_section_key("branch_progress", "talent_loadouts")
		and config.has_section_key("branch_loadout", "equipped_branch_ids_by_slot_id"),
		"Save schema sections or version are incomplete."
	)
	var text: String = FileAccess.get_file_as_string(TEST_PATH)
	expect(
		not text.contains("branch_seed")
		and not text.contains("claimed_guarantee")
		and not text.contains("current_wave")
		and not text.contains("tree_soul"),
		"Save schema contains out-of-scope state."
	)
	cleanup_file()
	finish("SAVE GAME SCHEMA SMOKE TEST")


func create_item(instance_id: StringName, definition_id: StringName, level: int) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.definition_id = definition_id
	item.item_level = level
	item.rarity_id = ItemRarityRules.EPIC
	item.is_locked = true
	item.affix_rolls.append(ItemAffixRoll.new(&"branch_damage", 0.125))
	return item


func cleanup_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func finish(label: String) -> void:
	if failures.is_empty():
		print("%s PASS" % label)
		get_tree().quit(0)
	else:
		print("%s FAIL: %d failure(s)" % [label, failures.size()])
		get_tree().quit(1)
