class_name TreeBranchLoadoutController
extends Node


signal runtime_standard_slot_changed(
	slot_id: StringName,
	branch_id: StringName
)

signal runtime_apex_slot_changed(branch_id: StringName)


const DEFAULT_BRANCH_IDS: Dictionary = {
	BranchSlotRules.STANDARD_SLOT_1_ID: &"strength_branch",
	BranchSlotRules.STANDARD_SLOT_2_ID: &"blossom_branch",
	BranchSlotRules.STANDARD_SLOT_3_ID: &"strength_branch",
	BranchSlotRules.STANDARD_SLOT_4_ID: &"blossom_branch"
}

const MOUNT_PATHS: Dictionary = {
	BranchSlotRules.STANDARD_SLOT_1_ID: NodePath("../../AttachmentPoints/LeftLower/BranchMount"),
	BranchSlotRules.STANDARD_SLOT_2_ID: NodePath("../../AttachmentPoints/LeftUpper/BranchMount"),
	BranchSlotRules.STANDARD_SLOT_3_ID: NodePath("../../AttachmentPoints/RightLower/BranchMount"),
	BranchSlotRules.STANDARD_SLOT_4_ID: NodePath("../../AttachmentPoints/RightUpper/BranchMount")
}

const APEX_MOUNT_PATH: NodePath = NodePath(
	"../../AttachmentPoints/Apex/BranchMount"
)

var runtime_branches_by_slot_id: Dictionary = {}
var branch_loadout: BranchLoadoutService


func _ready() -> void:
	add_to_group("branch_loadout_controller")
	branch_loadout = get_node_or_null("/root/BranchLoadout") as BranchLoadoutService
	if not is_instance_valid(branch_loadout):
		push_error("TreeBranchLoadoutController requires BranchLoadout.")
		return
	if not branch_loadout.standard_slot_changed.is_connected(_on_standard_slot_changed):
		branch_loadout.standard_slot_changed.connect(_on_standard_slot_changed)
	if not branch_loadout.apex_slot_changed.is_connected(_on_apex_slot_changed):
		branch_loadout.apex_slot_changed.connect(_on_apex_slot_changed)
	for slot_id in DEFAULT_BRANCH_IDS:
		branch_loadout.ensure_standard_slot_initialized(slot_id, DEFAULT_BRANCH_IDS[slot_id])
	branch_loadout.ensure_apex_slot_initialized(&"")
	refresh_all_standard_slots()
	refresh_apex_slot()


func get_runtime_branch(slot_id: StringName) -> CombatBranch:
	var branch: CombatBranch = runtime_branches_by_slot_id.get(slot_id) as CombatBranch
	return branch if is_instance_valid(branch) else null


func get_runtime_apex_branch() -> CombatBranch:
	return get_runtime_branch(BranchSlotRules.APEX_SLOT_ID)


func refresh_standard_slot(slot_id: StringName) -> bool:
	if not BranchSlotRules.is_standard_slot(BranchSlotRules.get_slot_index(slot_id)):
		return false
	var mount: Node2D = get_node_or_null(MOUNT_PATHS.get(slot_id, NodePath())) as Node2D
	if not is_instance_valid(mount):
		push_error("Missing BranchMount for %s." % slot_id)
		return false
	var requested_branch_id: StringName = branch_loadout.get_equipped_branch_id(slot_id)
	var current_branch: CombatBranch = get_runtime_branch(slot_id)
	if is_instance_valid(current_branch) and current_branch.branch_id == requested_branch_id:
		return false
	_remove_runtime_branch(slot_id, mount)
	if requested_branch_id == &"":
		runtime_standard_slot_changed.emit(slot_id, &"")
		return true

	var definition: BranchDefinition = GameContent.get_branch(requested_branch_id)
	var slot_index: int = BranchSlotRules.get_slot_index(slot_id)
	if (
		not is_instance_valid(definition)
		or definition.branch_scene == null
		or not BranchSlotRules.can_place_definition(definition, slot_index)
	):
		push_error("Cannot instantiate invalid Branch '%s' in %s." % [requested_branch_id, slot_id])
		return false
	var instance: Node = definition.branch_scene.instantiate()
	if instance is not CombatBranch:
		push_error("Branch scene for '%s' must instantiate CombatBranch." % requested_branch_id)
		instance.queue_free()
		return false
	var runtime_branch := instance as CombatBranch
	runtime_branch.slot_index = slot_index
	runtime_branch.facing_side = 0 if runtime_branch.slot_index in [1, 2] else 1
	runtime_branch.position = Vector2.ZERO
	mount.add_child(runtime_branch)
	if runtime_branch.branch_id != requested_branch_id:
		push_error("Branch scene ID '%s' does not match requested '%s'." % [runtime_branch.branch_id, requested_branch_id])
		mount.remove_child(runtime_branch)
		runtime_branch.queue_free()
		return false
	runtime_branches_by_slot_id[slot_id] = runtime_branch
	runtime_standard_slot_changed.emit(slot_id, requested_branch_id)
	return true


func refresh_all_standard_slots() -> void:
	for slot_index in range(BranchSlotRules.FIRST_STANDARD_SLOT, BranchSlotRules.LAST_STANDARD_SLOT + 1):
		refresh_standard_slot(BranchSlotRules.get_slot_id(slot_index))


func refresh_apex_slot() -> bool:
	var mount: Node2D = get_node_or_null(APEX_MOUNT_PATH) as Node2D
	if not is_instance_valid(mount):
		push_error("Missing BranchMount for apex_slot.")
		return false
	var requested_branch_id: StringName = branch_loadout.get_equipped_apex_branch_id()
	var current_branch: CombatBranch = get_runtime_apex_branch()
	if is_instance_valid(current_branch) and current_branch.branch_id == requested_branch_id:
		return false
	_remove_runtime_branch(BranchSlotRules.APEX_SLOT_ID, mount)
	if requested_branch_id == &"":
		runtime_apex_slot_changed.emit(&"")
		return true

	var definition: BranchDefinition = GameContent.get_branch(requested_branch_id)
	if not is_instance_valid(definition) or definition.branch_scene == null:
		push_error("Cannot instantiate unknown Apex Branch '%s'." % requested_branch_id)
		return false
	var instance: Node = definition.branch_scene.instantiate()
	if instance is not CombatBranch:
		push_error("Apex Branch scene for '%s' must instantiate CombatBranch." % requested_branch_id)
		instance.queue_free()
		return false
	var runtime_branch := instance as CombatBranch
	runtime_branch.slot_index = BranchSlotRules.APEX_SLOT
	runtime_branch.position = Vector2.ZERO
	mount.add_child(runtime_branch)
	if (
		runtime_branch.branch_id != requested_branch_id
		or runtime_branch.get_slot_id() != BranchSlotRules.APEX_SLOT_ID
		or not runtime_branch.is_slot_assignment_valid()
	):
		push_error("Apex Branch '%s' has an invalid runtime identity." % requested_branch_id)
		mount.remove_child(runtime_branch)
		runtime_branch.queue_free()
		return false
	runtime_branches_by_slot_id[BranchSlotRules.APEX_SLOT_ID] = runtime_branch
	runtime_apex_slot_changed.emit(requested_branch_id)
	return true


func _remove_runtime_branch(slot_id: StringName, mount: Node2D) -> void:
	var old_branch: CombatBranch = get_runtime_branch(slot_id)
	if not is_instance_valid(old_branch):
		runtime_branches_by_slot_id.erase(slot_id)
		return
	old_branch.stop_combat()
	if old_branch.get_parent() == mount:
		mount.remove_child(old_branch)
	old_branch.queue_free()
	runtime_branches_by_slot_id.erase(slot_id)


func _on_standard_slot_changed(
	slot_id: StringName,
	_previous_branch_id: StringName,
	_new_branch_id: StringName
) -> void:
	refresh_standard_slot(slot_id)


func _on_apex_slot_changed(
	_previous_branch_id: StringName,
	_new_branch_id: StringName
) -> void:
	refresh_apex_slot()
