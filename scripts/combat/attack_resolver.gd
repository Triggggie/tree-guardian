class_name AttackResolver
extends RefCounted


static func resolve_damage(
	context: AttackContext
) -> bool:
	if context == null:
		return false

	if not context.is_valid_context():
		return false

	if not context.target.has_method(
		"take_damage"
	):
		return false

	if context.target.has_method(
		"is_targetable"
	):
		if not bool(
			context.target.call(
				"is_targetable"
			)
		):
			return false

	var final_damage: float = (
		context.get_final_damage()
	)

	if final_damage <= 0.0:
		return false

	context.target.call(
		"take_damage",
		final_damage,
		context.source
	)

	return true
