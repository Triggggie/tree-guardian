class_name WavePacingRules
extends RefCounted


const ONBOARDING_FINAL_WAVE: int = 10
const EARLY_OVERLAP_FINAL_WAVE: int = 25
const PRE_BOSS_OVERLAP_FINAL_WAVE: int = 49

const EARLY_SURVIVOR_THRESHOLD: float = 0.20
const MID_SURVIVOR_THRESHOLD: float = 0.30
const LATE_SURVIVOR_THRESHOLD: float = 0.35

const MAXIMUM_ACTIVE_COHORTS: int = 2


static func is_overlap_enabled(global_wave: int) -> bool:
	return global_wave > ONBOARDING_FINAL_WAVE


static func get_overlap_threshold(global_wave: int) -> float:
	if not is_overlap_enabled(global_wave):
		return 0.0
	if global_wave <= EARLY_OVERLAP_FINAL_WAVE:
		return EARLY_SURVIVOR_THRESHOLD
	if global_wave <= PRE_BOSS_OVERLAP_FINAL_WAVE:
		return MID_SURVIVOR_THRESHOLD
	return LATE_SURVIVOR_THRESHOLD


static func is_survivor_ratio_eligible(
	global_wave: int,
	active_enemy_count: int,
	initial_enemy_count: int
) -> bool:
	if initial_enemy_count < 1 or active_enemy_count < 0:
		return false
	return (
		float(active_enemy_count) / float(initial_enemy_count)
		<= get_overlap_threshold(global_wave)
	)
