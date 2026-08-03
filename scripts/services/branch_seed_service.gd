class_name BranchSeedService
extends Node


signal branch_seed_unlocked(
	branch_id: StringName
)

signal branch_seed_dropped(
	branch_id: StringName,
	enemy_id: StringName,
	world_position: Vector2
)


const DEFAULT_STORAGE_PATH: String = (
	"user://branch_seed_unlocks.cfg"
)
const SAVE_VERSION: int = 1
const SAVE_SECTION: String = "branch_seed_unlocks"
const SAVE_VERSION_KEY: String = "version"
const SAVE_IDS_KEY: String = "branch_ids"


var storage_path: String = DEFAULT_STORAGE_PATH
var unlocked_branch_seed_ids: Array[StringName] = []
var random_number_generator: RandomNumberGenerator = (
	RandomNumberGenerator.new()
)
var is_initialized: bool = false


func _ready() -> void:
	if is_initialized:
		return

	initialize()


func initialize(
	storage_path_override: String = ""
) -> bool:
	storage_path = (
		storage_path_override
		if not storage_path_override.is_empty()
		else DEFAULT_STORAGE_PATH
	)
	random_number_generator.randomize()
	is_initialized = true

	return reload_from_disk()


func reload_from_disk() -> bool:
	unlocked_branch_seed_ids.clear()

	var config := ConfigFile.new()
	var load_error: Error = config.load(storage_path)

	if load_error == ERR_FILE_NOT_FOUND:
		return true

	if load_error != OK:
		push_warning(
			"BranchSeeds could not load '%s' (error %d)."
			% [storage_path, load_error]
		)
		return false

	var save_version: int = int(
		config.get_value(
			SAVE_SECTION,
			SAVE_VERSION_KEY,
			0
		)
	)

	if save_version != SAVE_VERSION:
		push_warning(
			"BranchSeeds found unsupported save version %d in '%s'."
			% [save_version, storage_path]
		)
		return false

	var stored_ids = config.get_value(
		SAVE_SECTION,
		SAVE_IDS_KEY,
		PackedStringArray()
	)
	var loaded_ids: Dictionary = {}

	if stored_ids is Array or stored_ids is PackedStringArray:
		for stored_id in stored_ids:
			var branch_id := StringName(str(stored_id))

			if branch_id == &"":
				continue

			if loaded_ids.has(branch_id):
				continue

			loaded_ids[branch_id] = true
			unlocked_branch_seed_ids.append(branch_id)

	return true


func is_branch_seed_unlocked(
	branch_id: StringName
) -> bool:
	if branch_id == &"":
		return false

	return unlocked_branch_seed_ids.has(branch_id)


func get_unlocked_branch_seed_ids() -> Array[StringName]:
	return unlocked_branch_seed_ids.duplicate()


func unlock_branch_seed(
	branch_definition: BranchDefinition
) -> bool:
	if not is_instance_valid(branch_definition):
		return false

	if not branch_definition.is_valid_definition():
		return false

	if not branch_definition.is_legendary_branch():
		return false

	var branch_id: StringName = branch_definition.branch_id

	if is_branch_seed_unlocked(branch_id):
		return false

	unlocked_branch_seed_ids.append(branch_id)

	if not save_unlocks():
		unlocked_branch_seed_ids.erase(branch_id)
		return false

	branch_seed_unlocked.emit(branch_id)
	return true


func process_enemy_defeat(
	enemy_definition: EnemyDefinition,
	world_position: Vector2
) -> StringName:
	if not is_instance_valid(enemy_definition):
		return &""

	if not enemy_definition.is_valid_definition():
		return &""

	for branch_seed_drop in (
		enemy_definition.branch_seed_drops
	):
		if not is_instance_valid(branch_seed_drop):
			continue

		if not branch_seed_drop.is_valid_definition():
			continue

		var branch: BranchDefinition = (
			branch_seed_drop.branch_definition
		)
		var branch_id: StringName = branch.branch_id

		if is_branch_seed_unlocked(branch_id):
			continue

		if not drop_succeeds(branch_seed_drop.drop_chance):
			continue

		if not unlock_branch_seed(branch):
			continue

		branch_seed_dropped.emit(
			branch_id,
			enemy_definition.enemy_id,
			world_position
		)

		return branch_id

	return &""


func drop_succeeds(
	drop_chance: float
) -> bool:
	if drop_chance <= 0.0:
		return false

	if drop_chance >= 1.0:
		return true

	return random_number_generator.randf() < drop_chance


func save_unlocks() -> bool:
	var config := ConfigFile.new()
	var stored_ids := PackedStringArray()

	for branch_id in unlocked_branch_seed_ids:
		stored_ids.append(String(branch_id))

	config.set_value(
		SAVE_SECTION,
		SAVE_VERSION_KEY,
		SAVE_VERSION
	)
	config.set_value(
		SAVE_SECTION,
		SAVE_IDS_KEY,
		stored_ids
	)

	var save_error: Error = config.save(storage_path)

	if save_error == OK:
		return true

	push_warning(
		"BranchSeeds could not save '%s' (error %d)."
		% [storage_path, save_error]
	)
	return false
