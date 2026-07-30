class_name TargetingProfile
extends Resource


enum LaneMode {
	ANY,
	PREFERRED,
	STRICT
}


enum TargetPriority {
	NEAREST,
	FARTHEST,
	LOWEST_HEALTH,
	HIGHEST_HEALTH
}


@export_category("Target")

@export var target_group: StringName = &"enemies"

@export var target_priority: TargetPriority = (
	TargetPriority.NEAREST
)


@export_category("Lane")

# ANY:
# Lane se při výběru cíle neřeší.
#
# PREFERRED:
# Nejdříve se hledá v preferované lane,
# poté je povolen fallback do ostatních lane.
#
# STRICT:
# Lze cílit pouze do preferované lane.
@export var lane_mode: LaneMode = (
	LaneMode.PREFERRED
)

@export_range(0, 4, 1)
var preferred_lane_span: int = 1


func uses_preferred_lane() -> bool:
	return lane_mode != LaneMode.ANY


func allows_lane_fallback() -> bool:
	return lane_mode == LaneMode.PREFERRED


func is_lane_allowed(
	target_lane_index: int,
	preferred_lane_index: int
) -> bool:
	if lane_mode == LaneMode.ANY:
		return true

	var safe_lane_span: int = max(
		preferred_lane_span,
		0
	)

	return (
		abs(
			target_lane_index
			- preferred_lane_index
		)
		<= safe_lane_span
	)


func is_valid_definition() -> bool:
	if target_group == &"":
		return false

	if preferred_lane_span < 0:
		return false

	return true
