class_name BranchProgressionRules
extends RefCounted


const XP_BASE: float = 2.0
const XP_LEVEL_COEFFICIENT: float = 1.5
const XP_LEVEL_EXPONENT: float = 1.35

const TALENT_POINT_LEVELS: Array[int] = [
	2,
	5,
	10,
	20,
	35,
	55,
	80,
	110,
	150,
	200,
	275,
	375
]


static func get_xp_required_for_level(current_level: int) -> int:
	var safe_level: int = max(current_level, 1)
	return max(
		int(
			ceil(
				XP_BASE
				+ XP_LEVEL_COEFFICIENT
				* pow(float(safe_level), XP_LEVEL_EXPONENT)
			)
		),
		1
	)


static func get_total_talent_points_for_level(branch_level: int) -> int:
	var total_points: int = 0
	for milestone_level in TALENT_POINT_LEVELS:
		if branch_level < milestone_level:
			break
		total_points += 1
	return total_points


static func is_talent_point_level(branch_level: int) -> bool:
	return branch_level in TALENT_POINT_LEVELS


static func get_talent_point_levels() -> Array[int]:
	return TALENT_POINT_LEVELS.duplicate()


static func get_cumulative_xp_for_level(target_level: int) -> int:
	var cumulative_xp: int = 0
	for current_level in range(1, max(target_level, 1)):
		cumulative_xp += get_xp_required_for_level(current_level)
	return cumulative_xp
