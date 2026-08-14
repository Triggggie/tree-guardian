extends Node


const TEST_PATH: String = "user://save_game_branch_progress_smoke_test.cfg"

var failures: Array[String] = []


func _ready() -> void:
	cleanup_file()
	expect(SaveGame.initialize(TEST_PATH), "Fresh Branch Progress initialize failed.")
	var strength: BranchDefinition = GameContent.get_branch(&"strength_branch")
	var blossom: BranchDefinition = GameContent.get_branch(&"blossom_branch")
	var strength_talents: Array[StringName] = strength.talent_tree.get_talent_ids()
	var progress_state: Dictionary = {
		"records": [
			make_progress(&"strength_branch", 9, 1, 3, strength.get_upgrade_ids()[0], 4),
			make_progress(&"blossom_branch", 5, 0, 2, blossom.get_upgrade_ids()[0], 2)
		],
		"talent_loadouts": [
			make_loadout(&"standard_slot_1", &"strength_branch", [strength_talents[0]]),
			make_loadout(&"standard_slot_3", &"strength_branch", [strength_talents[1]])
		]
	}
	expect(BranchProgress.restore_persistence_state(progress_state), "Progress fixture restore failed.")
	expect(SaveGame.save_now(), "Branch Progress save failed.")
	expect(BranchProgress.restore_persistence_state({"records": [], "talent_loadouts": []}), "Progress clear failed.")
	expect(SaveGame.load_now(), "Branch Progress reload failed.")
	var strength_record: BranchProgressRecord = BranchProgress.get_progress(&"strength_branch")
	var blossom_record: BranchProgressRecord = BranchProgress.get_progress(&"blossom_branch")
	expect(
		strength_record != null and strength_record.branch_level == 9
		and strength_record.current_xp == 1
		and strength_record.total_talent_points_earned == 3
		and strength_record.get_upgrade_level(strength.get_upgrade_ids()[0]) == 4,
		"Strength shared progress did not round trip."
	)
	expect(
		blossom_record != null and blossom_record.branch_level == 5
		and blossom_record.total_talent_points_earned == 2
		and blossom_record.get_upgrade_level(blossom.get_upgrade_ids()[0]) == 2,
		"Blossom shared progress did not round trip independently."
	)
	var slot_one: BranchTalentLoadoutRecord = BranchProgress.get_talent_loadout(&"standard_slot_1", &"strength_branch")
	var slot_three: BranchTalentLoadoutRecord = BranchProgress.get_talent_loadout(&"standard_slot_3", &"strength_branch")
	expect(
		slot_one != null and slot_three != null
		and slot_one.is_talent_purchased(strength_talents[0])
		and not slot_one.is_talent_purchased(strength_talents[1])
		and slot_three.is_talent_purchased(strength_talents[1])
		and not slot_three.is_talent_purchased(strength_talents[0]),
		"Slot + Branch talent identities were merged."
	)
	cleanup_file()
	finish()


func make_progress(branch_id: StringName, level: int, xp: int, points: int, upgrade_id: StringName, upgrade_level: int) -> Dictionary:
	return {"branch_id": String(branch_id), "branch_level": level, "current_xp": xp, "total_talent_points_earned": points, "upgrade_levels": {String(upgrade_id): upgrade_level}}


func make_loadout(slot_id: StringName, branch_id: StringName, talents: Array[StringName]) -> Dictionary:
	var stored_talents: Array[String] = []
	for talent_id in talents:
		stored_talents.append(String(talent_id))
	return {"slot_id": String(slot_id), "branch_id": String(branch_id), "purchased_talent_ids": stored_talents}


func cleanup_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func finish() -> void:
	if failures.is_empty():
		print("SAVE GAME BRANCH PROGRESS SMOKE TEST PASS")
		get_tree().quit(0)
	else:
		print("SAVE GAME BRANCH PROGRESS SMOKE TEST FAIL: %d failure(s)" % failures.size())
		get_tree().quit(1)
