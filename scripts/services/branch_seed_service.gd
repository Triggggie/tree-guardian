class_name BranchSeedService
extends Node


signal branch_seed_unlocked(branch_id: StringName)
signal branch_seed_dropped(
	branch_id: StringName,
	enemy_id: StringName,
	world_position: Vector2
)
signal branch_seed_pity_changed(
	legendary_tier: int,
	current_points: int,
	threshold: int
)


const DEFAULT_STORAGE_PATH: String = "user://branch_seed_unlocks.cfg"
const SAVE_VERSION: int = 2
const LEGACY_SAVE_VERSION: int = 1
const SAVE_SECTION: String = "branch_seed_unlocks"
const SAVE_VERSION_KEY: String = "version"
const SAVE_IDS_KEY: String = "branch_ids"
const PITY_SECTION: String = "branch_seed_pity"
const PITY_TIER_1_KEY: String = "tier_1_points"
const PITY_TIER_2_KEY: String = "tier_2_points"
const PITY_TIER_3_KEY: String = "tier_3_points"


var storage_path: String = DEFAULT_STORAGE_PATH
var unlocked_branch_seed_ids: Array[StringName] = []
var pity_points_by_tier: Dictionary = {
	BranchDefinition.LEGENDARY_TIER_1: 0,
	BranchDefinition.LEGENDARY_TIER_2: 0,
	BranchDefinition.LEGENDARY_TIER_3: 0
}
var random_number_generator: RandomNumberGenerator = RandomNumberGenerator.new()
var is_initialized: bool = false


func _ready() -> void:
	if not is_initialized:
		initialize()


func initialize(storage_path_override: String = "") -> bool:
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
	_reset_pity_points()

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

	var save_version: int = int(config.get_value(
		SAVE_SECTION,
		SAVE_VERSION_KEY,
		0
	))

	if save_version not in [LEGACY_SAVE_VERSION, SAVE_VERSION]:
		push_warning(
			"BranchSeeds found unsupported save version %d in '%s'."
			% [save_version, storage_path]
		)
		return false

	_load_unlock_ids(config)

	if save_version == LEGACY_SAVE_VERSION:
		return save_unlocks()

	pity_points_by_tier[BranchDefinition.LEGENDARY_TIER_1] = max(
		int(config.get_value(PITY_SECTION, PITY_TIER_1_KEY, 0)),
		0
	)
	pity_points_by_tier[BranchDefinition.LEGENDARY_TIER_2] = max(
		int(config.get_value(PITY_SECTION, PITY_TIER_2_KEY, 0)),
		0
	)
	pity_points_by_tier[BranchDefinition.LEGENDARY_TIER_3] = max(
		int(config.get_value(PITY_SECTION, PITY_TIER_3_KEY, 0)),
		0
	)

	return true


func is_branch_seed_unlocked(branch_id: StringName) -> bool:
	return branch_id != &"" and unlocked_branch_seed_ids.has(branch_id)


func get_unlocked_branch_seed_ids() -> Array[StringName]:
	return unlocked_branch_seed_ids.duplicate()


func get_pity_points(legendary_tier: int) -> int:
	return max(int(pity_points_by_tier.get(legendary_tier, 0)), 0)


func get_all_pity_points() -> Dictionary:
	return pity_points_by_tier.duplicate(true)


func get_pity_threshold(
	stage_definition: StageDefinition,
	legendary_tier: int
) -> int:
	if not is_instance_valid(stage_definition):
		return 0

	var loot_pool: BranchSeedLootPoolDefinition = (
		stage_definition.get_branch_seed_loot_pool()
	)
	if not is_instance_valid(loot_pool):
		return 0

	return loot_pool.get_pity_threshold(legendary_tier)


func unlock_branch_seed(branch_definition: BranchDefinition) -> bool:
	if (
		not is_instance_valid(branch_definition)
		or not branch_definition.is_valid_definition()
		or not branch_definition.is_legendary_branch()
	):
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
	stage_definition: StageDefinition,
	world_position: Vector2
) -> StringName:
	if (
		not is_instance_valid(enemy_definition)
		or not enemy_definition.is_valid_definition()
		or enemy_definition.is_normal_enemy()
		or not is_instance_valid(stage_definition)
		or not stage_definition.is_valid_definition()
	):
		return &""

	var loot_pool: BranchSeedLootPoolDefinition = (
		stage_definition.get_branch_seed_loot_pool()
	)
	if not is_instance_valid(loot_pool) or not loot_pool.is_valid_definition():
		return &""

	var maximum_tier: int = loot_pool.get_maximum_tier_for_encounter(
		enemy_definition.encounter_rank_id
	)
	var selected_tier: int = BranchDefinition.LEGENDARY_TIER_NONE
	var eligible_entries: Array[BranchSeedLootEntryDefinition] = []

	for checked_tier in range(maximum_tier, 0, -1):
		eligible_entries = _get_locked_entries_for_tier(
			loot_pool,
			checked_tier
		)
		if not eligible_entries.is_empty():
			selected_tier = checked_tier
			break

	if selected_tier == BranchDefinition.LEGENDARY_TIER_NONE:
		return &""

	var threshold: int = loot_pool.get_pity_threshold(selected_tier)
	if threshold < 1:
		return &""

	var previous_pity: int = get_pity_points(selected_tier)
	var guaranteed_drop: bool = previous_pity >= threshold

	if (
		not guaranteed_drop
		and not drop_succeeds(enemy_definition.branch_seed_roll_chance)
	):
		var updated_pity: int = min(
			previous_pity + enemy_definition.branch_seed_pity_points,
			threshold
		)
		if updated_pity == previous_pity:
			return &""

		pity_points_by_tier[selected_tier] = updated_pity
		if not save_unlocks():
			pity_points_by_tier[selected_tier] = previous_pity
			return &""

		branch_seed_pity_changed.emit(
			selected_tier,
			updated_pity,
			threshold
		)
		return &""

	var selected_entry: BranchSeedLootEntryDefinition = (
		_select_weighted_entry(eligible_entries)
	)
	if not is_instance_valid(selected_entry):
		return &""

	var branch_id: StringName = selected_entry.get_branch_id()
	unlocked_branch_seed_ids.append(branch_id)
	pity_points_by_tier[selected_tier] = 0

	if not save_unlocks():
		unlocked_branch_seed_ids.erase(branch_id)
		pity_points_by_tier[selected_tier] = previous_pity
		return &""

	branch_seed_unlocked.emit(branch_id)
	if previous_pity != 0:
		branch_seed_pity_changed.emit(selected_tier, 0, threshold)
	branch_seed_dropped.emit(
		branch_id,
		enemy_definition.enemy_id,
		world_position
	)
	return branch_id


func drop_succeeds(drop_chance: float) -> bool:
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

	config.set_value(SAVE_SECTION, SAVE_VERSION_KEY, SAVE_VERSION)
	config.set_value(SAVE_SECTION, SAVE_IDS_KEY, stored_ids)
	config.set_value(
		PITY_SECTION,
		PITY_TIER_1_KEY,
		get_pity_points(BranchDefinition.LEGENDARY_TIER_1)
	)
	config.set_value(
		PITY_SECTION,
		PITY_TIER_2_KEY,
		get_pity_points(BranchDefinition.LEGENDARY_TIER_2)
	)
	config.set_value(
		PITY_SECTION,
		PITY_TIER_3_KEY,
		get_pity_points(BranchDefinition.LEGENDARY_TIER_3)
	)

	var save_error: Error = config.save(storage_path)
	if save_error == OK:
		return true

	push_warning(
		"BranchSeeds could not save '%s' (error %d)."
		% [storage_path, save_error]
	)
	return false


func reset_all_progress_for_debug() -> bool:
	if not OS.is_debug_build():
		push_warning("Branch Seed progress reset is debug-build only.")
		return false
	var absolute_path: String = ProjectSettings.globalize_path(storage_path)
	if FileAccess.file_exists(storage_path):
		var remove_error: Error = DirAccess.remove_absolute(absolute_path)
		if remove_error != OK:
			push_warning(
				"BranchSeeds could not remove '%s' (error %d)."
				% [storage_path, remove_error]
			)
			return false
	unlocked_branch_seed_ids.clear()
	_reset_pity_points()
	return true


func _load_unlock_ids(config: ConfigFile) -> void:
	var stored_ids = config.get_value(
		SAVE_SECTION,
		SAVE_IDS_KEY,
		PackedStringArray()
	)
	var loaded_ids: Dictionary = {}

	if stored_ids is not Array and stored_ids is not PackedStringArray:
		return

	for stored_id in stored_ids:
		var branch_id := StringName(str(stored_id))
		if branch_id == &"" or loaded_ids.has(branch_id):
			continue

		loaded_ids[branch_id] = true
		unlocked_branch_seed_ids.append(branch_id)


func _reset_pity_points() -> void:
	for legendary_tier in range(
		BranchDefinition.LEGENDARY_TIER_1,
		BranchDefinition.LEGENDARY_TIER_3 + 1
	):
		pity_points_by_tier[legendary_tier] = 0


func _get_locked_entries_for_tier(
	loot_pool: BranchSeedLootPoolDefinition,
	legendary_tier: int
) -> Array[BranchSeedLootEntryDefinition]:
	var locked_entries: Array[BranchSeedLootEntryDefinition] = []

	for entry in loot_pool.get_entries_for_tier(legendary_tier):
		if not entry.is_valid_definition():
			continue
		if is_branch_seed_unlocked(entry.get_branch_id()):
			continue
		locked_entries.append(entry)

	return locked_entries


func _select_weighted_entry(
	eligible_entries: Array[BranchSeedLootEntryDefinition]
) -> BranchSeedLootEntryDefinition:
	var total_weight: float = 0.0
	for entry in eligible_entries:
		total_weight += max(entry.weight, 0.0)

	if total_weight <= 0.0:
		return null

	var selected_weight: float = random_number_generator.randf() * total_weight
	var cumulative_weight: float = 0.0

	for entry in eligible_entries:
		cumulative_weight += entry.weight
		if selected_weight < cumulative_weight:
			return entry

	return eligible_entries.back()
