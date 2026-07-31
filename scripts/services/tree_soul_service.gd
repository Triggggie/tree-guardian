class_name TreeSoulService
extends Node


signal soul_selected(
	soul_definition: TreeSoulDefinition,
	soul_rank: int
)

signal soul_rank_changed(
	old_rank: int,
	new_rank: int
)

signal soul_cleared()


const MODIFIER_SOURCE_ID: StringName = &"tree_soul"


var selected_soul: TreeSoulDefinition
var current_rank: int = 0
var last_announced_rank: int = 0


func has_selected_soul() -> bool:
	return is_instance_valid(selected_soul)


func get_available_souls() -> Array[TreeSoulDefinition]:
	return GameContent.get_tree_souls()


func select_soul_by_id(
	tree_soul_id: StringName,
	tree_age: int
) -> bool:
	var soul_definition: TreeSoulDefinition = GameContent.get_tree_soul(
		tree_soul_id
	)

	return select_soul(
		soul_definition,
		tree_age
	)

func can_select_soul(
	soul_definition: TreeSoulDefinition,
	tree_age: int
) -> bool:
	if has_selected_soul():
		return false

	if not is_instance_valid(
		soul_definition
	):
		return false

	if not soul_definition.is_valid_definition():
		return false

	return (
		soul_definition.get_rank_for_age(
			tree_age
		)
		>= 1
	)


func select_soul(
	soul_definition: TreeSoulDefinition,
	tree_age: int
) -> bool:
	if not can_select_soul(
		soul_definition,
		tree_age
	):
		return false

	selected_soul = soul_definition

	current_rank = selected_soul.get_rank_for_age(
		tree_age
	)

	last_announced_rank = current_rank

	apply_current_modifiers()

	soul_selected.emit(
		selected_soul,
		current_rank
	)

	return true


func update_for_age(
	tree_age: int
) -> void:
	if not has_selected_soul():
		return

	var new_rank: int = (
		selected_soul.get_rank_for_age(
			tree_age
		)
	)

	if new_rank == current_rank:
		return

	var old_rank: int = current_rank
	current_rank = new_rank

	apply_current_modifiers()

	soul_rank_changed.emit(
		old_rank,
		current_rank
	)


func apply_current_modifiers() -> void:
	RunModifiers.clear_source(
		MODIFIER_SOURCE_ID
	)

	if not has_selected_soul():
		return

	if current_rank <= 0:
		return

	for bonus in selected_soul.bonuses:
		if not is_instance_valid(bonus):
			continue

		if not bonus.is_valid_definition():
			continue

		var modifier_value: float = (
			bonus.get_run_modifier_value_for_rank(
				current_rank,
				selected_soul.soft_cap_rank,
				selected_soul.post_soft_cap_multiplier
			)
		)

		match bonus.application_mode:
			TreeSoulBonusDefinition.ApplicationMode.ADDITIVE:
				RunModifiers.set_additive_modifier(
					bonus.modifier_id,
					MODIFIER_SOURCE_ID,
					modifier_value
				)

			TreeSoulBonusDefinition.ApplicationMode.MULTIPLIER_BONUS:
				RunModifiers.set_multiplier_modifier(
					bonus.modifier_id,
					MODIFIER_SOURCE_ID,
					modifier_value
				)


func has_unannounced_rank_up() -> bool:
	return (
		current_rank
		> last_announced_rank
	)


func mark_current_rank_announced() -> void:
	last_announced_rank = current_rank


func clear_for_prestige() -> void:
	RunModifiers.clear_source(
		MODIFIER_SOURCE_ID
	)

	selected_soul = null
	current_rank = 0
	last_announced_rank = 0

	soul_cleared.emit()
