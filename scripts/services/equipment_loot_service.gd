class_name EquipmentLootService
extends Node


signal equipment_item_dropped(
	instance_id: StringName,
	enemy_id: StringName,
	world_position: Vector2
)


const INSTANCE_ID_PREFIX: String = "equipment_loot_"


var inventory: InventoryService
var item_generator := EquipmentItemGenerator.new()
var random_number_generator := RandomNumberGenerator.new()
var claimed_guarantee_keys: Dictionary = {}
var next_instance_number: int = 1
var inventory_add_override_for_testing: Callable


func _ready() -> void:
	inventory = get_node_or_null("/root/Inventory") as InventoryService
	if not is_instance_valid(inventory):
		push_error("EquipmentLootService requires Inventory.")
		return
	random_number_generator.randomize()


func process_enemy_defeat(
	enemy_definition: EnemyDefinition,
	stage_definition: StageDefinition,
	global_wave: int,
	world_position: Vector2
) -> ItemInstance:
	if (
		not is_instance_valid(inventory)
		or not is_instance_valid(enemy_definition)
		or not enemy_definition.is_valid_definition()
		or not is_instance_valid(stage_definition)
		or not stage_definition.is_valid_definition()
		or global_wave < 1
		or not enemy_definition.can_roll_equipment()
	):
		return null

	var guarantee_key: StringName = _get_guarantee_key(
		stage_definition.stage_id,
		global_wave,
		enemy_definition.enemy_id
	)
	var guarantee_available: bool = (
		enemy_definition.equipment_guaranteed_once_per_wave
		and not claimed_guarantee_keys.has(guarantee_key)
	)
	if (
		not guarantee_available
		and not _drop_succeeds(enemy_definition.equipment_drop_chance)
	):
		return null

	var item: ItemInstance = item_generator.generate_item(
		_get_next_available_instance_id(),
		enemy_definition,
		global_wave,
		random_number_generator
	)
	if item == null or not item.is_valid_data():
		return null

	if not _add_item_to_inventory(item):
		return null

	if guarantee_available:
		claimed_guarantee_keys[guarantee_key] = true

	equipment_item_dropped.emit(
		item.instance_id,
		enemy_definition.enemy_id,
		world_position
	)
	return item


func set_random_seed_for_testing(seed_value: int) -> void:
	if not OS.is_debug_build():
		push_warning("EquipmentLoot RNG seeding is debug-build only.")
		return
	random_number_generator.seed = seed_value


func set_inventory_add_override_for_testing(callback: Callable) -> void:
	if not OS.is_debug_build():
		push_warning("EquipmentLoot Inventory override is debug-build only.")
		return
	inventory_add_override_for_testing = callback


func clear_runtime_state_for_testing() -> void:
	if not OS.is_debug_build():
		push_warning("EquipmentLoot test reset is debug-build only.")
		return
	claimed_guarantee_keys.clear()
	next_instance_number = 1
	random_number_generator.seed = 1
	inventory_add_override_for_testing = Callable()


func is_guarantee_claimed_for_testing(
	stage_id: StringName,
	global_wave: int,
	enemy_id: StringName
) -> bool:
	return claimed_guarantee_keys.has(
		_get_guarantee_key(stage_id, global_wave, enemy_id)
	)


func reconcile_instance_counter_from_inventory() -> void:
	if not is_instance_valid(inventory):
		return
	var highest_instance_number: int = 0
	for item in inventory.get_items():
		var stored_id: String = String(item.instance_id)
		if not stored_id.begins_with(INSTANCE_ID_PREFIX):
			continue
		var numeric_suffix: String = stored_id.trim_prefix(INSTANCE_ID_PREFIX)
		if not numeric_suffix.is_valid_int():
			continue
		highest_instance_number = max(
			highest_instance_number,
			int(numeric_suffix)
		)
	next_instance_number = max(
		next_instance_number,
		highest_instance_number + 1
	)


func _drop_succeeds(drop_chance: float) -> bool:
	if drop_chance <= 0.0:
		return false
	if drop_chance >= 1.0:
		return true
	return random_number_generator.randf() < drop_chance


func _get_next_available_instance_id() -> StringName:
	while true:
		var instance_id := StringName(
			"%s%06d" % [INSTANCE_ID_PREFIX, next_instance_number]
		)
		next_instance_number += 1
		if not inventory.has_item(instance_id):
			return instance_id
	return &""


func _get_guarantee_key(
	stage_id: StringName,
	global_wave: int,
	enemy_id: StringName
) -> StringName:
	return StringName("%s|%d|%s" % [stage_id, global_wave, enemy_id])


func _add_item_to_inventory(item: ItemInstance) -> bool:
	if inventory_add_override_for_testing.is_valid():
		return bool(inventory_add_override_for_testing.call(item))
	return inventory.add_item(item)
