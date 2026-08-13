class_name RunModifierIds
extends RefCounted


# Finální obecné modifiery.
const BRANCH_DAMAGE: StringName = &"branch_damage"
const ATTACK_SPEED: StringName = &"attack_speed"

const TREE_MAX_HEALTH: StringName = &"tree_max_health"
const TREE_REGEN_RATE: StringName = &"tree_regen_rate"
const TREE_FLAT_REGEN: StringName = &"tree_flat_regen"

const ESSENCE_GAIN: StringName = &"essence_gain"

const HEALING_POWER: StringName = &"healing_power"


# Dočasné migrační aliasy.
# Odstraníme je, jakmile převedeme současné skripty
# na nové definitivní názvy.
const BRANCH_POWER: StringName = BRANCH_DAMAGE
const ACTION_SPEED: StringName = ATTACK_SPEED
const MAX_HEALTH: StringName = TREE_MAX_HEALTH
