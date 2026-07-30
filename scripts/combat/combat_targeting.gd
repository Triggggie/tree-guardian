class_name CombatTargeting
extends RefCounted


static func find_target(
	source: Node2D,
	profile: TargetingProfile,
	preferred_lane_index: int,
	maximum_range: float,
	facing_direction: float
) -> Node2D:
	if not is_instance_valid(source):
		return null

	if not source.is_inside_tree():
		return null

	if profile == null:
		return null

	if not profile.is_valid_definition():
		return null

	var safe_range: float = max(
		maximum_range,
		0.0
	)

	var safe_facing_direction: float = (
		-1.0
		if facing_direction < 0.0
		else 1.0
	)

	if (
		profile.lane_mode
		== TargetingProfile.LaneMode.PREFERRED
	):
		var preferred_target: Node2D = (
			find_best_target(
				source,
				profile,
				preferred_lane_index,
				safe_range,
				safe_facing_direction,
				true
			)
		)

		if preferred_target != null:
			return preferred_target

		return find_best_target(
			source,
			profile,
			preferred_lane_index,
			safe_range,
			safe_facing_direction,
			false
		)

	if (
		profile.lane_mode
		== TargetingProfile.LaneMode.STRICT
	):
		return find_best_target(
			source,
			profile,
			preferred_lane_index,
			safe_range,
			safe_facing_direction,
			true
		)

	return find_best_target(
		source,
		profile,
		preferred_lane_index,
		safe_range,
		safe_facing_direction,
		false
	)


static func find_best_target(
	source: Node2D,
	profile: TargetingProfile,
	preferred_lane_index: int,
	maximum_range: float,
	facing_direction: float,
	require_preferred_lane: bool
) -> Node2D:
	var best_target: Node2D = null

	var candidates: Array[Node] = (
		source.get_tree().get_nodes_in_group(
			profile.target_group
		)
	)

	for candidate in candidates:
		if not is_valid_target(
			source,
			candidate,
			profile,
			maximum_range,
			facing_direction
		):
			continue

		var candidate_node := (
			candidate as Node2D
		)

		if (
			require_preferred_lane
			and not is_target_in_preferred_lane(
				candidate_node,
				profile,
				preferred_lane_index
			)
		):
			continue

		if best_target == null:
			best_target = candidate_node
			continue

		if is_better_target(
			source,
			candidate_node,
			best_target,
			profile
		):
			best_target = candidate_node

	return best_target


static func is_valid_target(
	source: Node2D,
	candidate: Node,
	profile: TargetingProfile,
	maximum_range: float,
	facing_direction: float
) -> bool:
	if not is_instance_valid(candidate):
		return false

	if candidate is not Node2D:
		return false

	if candidate == source:
		return false

	if not candidate.is_in_group(
		profile.target_group
	):
		return false

	if not candidate.has_method(
		"take_damage"
	):
		return false

	if not candidate.has_method(
		"is_targetable"
	):
		return false

	if not bool(
		candidate.call(
			"is_targetable"
		)
	):
		return false

	var candidate_node := candidate as Node2D

	var horizontal_difference: float = (
		candidate_node.global_position.x
		- source.global_position.x
	)

	if (
		horizontal_difference
		* facing_direction
		<= 0.0
	):
		return false

	var horizontal_distance: float = abs(
		horizontal_difference
	)

	if horizontal_distance > maximum_range:
		return false

	return true


static func is_target_in_preferred_lane(
	target: Node2D,
	profile: TargetingProfile,
	preferred_lane_index: int
) -> bool:
	if (
		profile.lane_mode
		== TargetingProfile.LaneMode.ANY
	):
		return true

	if not target.has_method(
		"get_lane_index"
	):
		return false

	var target_lane_index: int = int(
		target.call(
			"get_lane_index"
		)
	)

	return profile.is_lane_allowed(
		target_lane_index,
		preferred_lane_index
	)


static func is_better_target(
	source: Node2D,
	candidate: Node2D,
	current_target: Node2D,
	profile: TargetingProfile
) -> bool:
	var candidate_distance: float = abs(
		candidate.global_position.x
		- source.global_position.x
	)

	var current_distance: float = abs(
		current_target.global_position.x
		- source.global_position.x
	)

	if (
		profile.target_priority
		== TargetingProfile.TargetPriority.FARTHEST
	):
		return candidate_distance > current_distance

	if (
		profile.target_priority
		== TargetingProfile.TargetPriority.LOWEST_HEALTH
	):
		var candidate_health: float = (
			get_target_health(candidate)
		)

		var current_health: float = (
			get_target_health(current_target)
		)

		if is_equal_approx(
			candidate_health,
			current_health
		):
			return (
				candidate_distance
				< current_distance
			)

		return candidate_health < current_health

	if (
		profile.target_priority
		== TargetingProfile.TargetPriority.HIGHEST_HEALTH
	):
		var candidate_health: float = (
			get_target_health(candidate)
		)

		var current_health: float = (
			get_target_health(current_target)
		)

		if is_equal_approx(
			candidate_health,
			current_health
		):
			return (
				candidate_distance
				< current_distance
			)

		return candidate_health > current_health

	return candidate_distance < current_distance


static func get_target_health(
	target: Node2D
) -> float:
	if target.has_method(
		"get_current_health"
	):
		return max(
			float(
				target.call(
					"get_current_health"
				)
			),
			0.0
		)

	var raw_health: Variant = target.get(
		"current_health"
	)

	if raw_health == null:
		return 0.0

	if (
		typeof(raw_health) != TYPE_INT
		and typeof(raw_health) != TYPE_FLOAT
	):
		return 0.0

	return max(
		float(raw_health),
		0.0
	)
