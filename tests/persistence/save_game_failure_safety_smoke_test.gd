extends Node


const TEST_PATH: String = "user://save_game_failure_safety_smoke_test.cfg"
const MISSING_PATH: String = "user://save_game_missing_smoke_test.cfg"

var failures: Array[String] = []


func _ready() -> void:
	cleanup_file(TEST_PATH)
	cleanup_file(MISSING_PATH)
	expect(SaveGame.initialize(TEST_PATH), "Failure-safety initialize failed.")
	var survivor := make_item(&"survivor", &"living_bark")
	expect(Inventory.add_item(survivor), "Survivor fixture add failed.")
	var corrupt_file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	corrupt_file.store_string("[metadata\nnot valid config")
	corrupt_file.close()
	expect(not SaveGame.load_now(), "Corrupt save was accepted.")
	expect(Inventory.has_item(survivor.instance_id), "Corrupt load destructively changed runtime state.")

	var future := ConfigFile.new()
	future.set_value("metadata", "version", 999)
	future.set_value("inventory", "items", [])
	future.set_value("equipment", "equipped_instance_ids_by_slot_id", {})
	future.set_value("branch_progress", "records", [])
	future.set_value("branch_progress", "talent_loadouts", [])
	future.set_value("branch_loadout", "equipped_branch_ids_by_slot_id", {})
	future.save(TEST_PATH)
	expect(not SaveGame.load_now(), "Future save version was accepted.")
	expect(SaveGame.writes_disabled_due_to_unsupported_version, "Future version did not disable writes.")
	expect(not SaveGame.save_now(), "Future save write protection failed.")
	var future_reload := ConfigFile.new()
	future_reload.load(TEST_PATH)
	expect(future_reload.get_value("metadata", "version", 0) == 999, "Future file was overwritten.")

	var legacy := ConfigFile.new()
	legacy.set_value("metadata", "version", 0)
	legacy.save(TEST_PATH)
	SaveGame.writes_disabled_due_to_unsupported_version = false
	expect(not SaveGame.load_now(), "Unsupported legacy version was accepted.")

	var malformed := ConfigFile.new()
	malformed.set_value("metadata", "version", 1)
	malformed.set_value("inventory", "items", [
		stored_item("valid", "living_bark", 5),
		stored_item("duplicate", "living_bark", 2),
		stored_item("duplicate", "living_bark", 3),
		stored_item("unknown", "missing_definition", 1),
		stored_item("bad_level", "living_bark", 0)
	])
	malformed.set_value("equipment", "equipped_instance_ids_by_slot_id", {
		"bark": "valid",
		"roots": "valid",
		"heartwood": "missing"
	})
	malformed.set_value("branch_progress", "records", [])
	malformed.set_value("branch_progress", "talent_loadouts", [])
	malformed.set_value("branch_loadout", "equipped_branch_ids_by_slot_id", {})
	malformed.save(TEST_PATH)
	expect(SaveGame.load_now(), "Partially malformed current save failed wholesale.")
	expect(
		Inventory.get_item_count() == 2
		and Inventory.has_item(&"valid") and Inventory.has_item(&"duplicate")
		and not Inventory.has_item(&"unknown") and not Inventory.has_item(&"bad_level"),
		"Malformed/duplicate/unknown item handling is wrong."
	)
	expect(
		Equipment.get_equipped_instance_id(&"bark") == &"valid"
		and Equipment.get_equipped_instance_id(&"roots") == &""
		and Equipment.get_equipped_instance_id(&"heartwood") == &"",
		"Missing or wrong-slot Equipment references were not emptied."
	)
	expect(SaveGame.load_now() and Inventory.get_item_count() == 2, "Repeated malformed load appended duplicates.")
	SaveGame.set_storage_path_for_testing(MISSING_PATH)
	expect(SaveGame.load_now(), "Missing save was not treated as fresh state.")
	expect(Inventory.get_item_count() == 0, "Missing save did not restore fresh Inventory state.")
	cleanup_file(TEST_PATH)
	cleanup_file(MISSING_PATH)
	finish()


func make_item(instance_id: StringName, definition_id: StringName) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.definition_id = definition_id
	item.rarity_id = ItemRarityRules.COMMON
	return item


func stored_item(instance_id: String, definition_id: String, level: int) -> Dictionary:
	return {"instance_id": instance_id, "definition_id": definition_id, "item_level": level, "rarity_id": "common", "is_locked": false, "affixes": []}


func cleanup_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func finish() -> void:
	if failures.is_empty():
		print("SAVE GAME FAILURE SAFETY SMOKE TEST PASS")
		get_tree().quit(0)
	else:
		print("SAVE GAME FAILURE SAFETY SMOKE TEST FAIL: %d failure(s)" % failures.size())
		get_tree().quit(1)
