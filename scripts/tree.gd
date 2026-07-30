extends Node2D


signal forest_essence_changed(new_amount: int)
signal age_changed(new_age: int)
signal growth_changed(growth_factor: float)
signal tree_upgrade_changed(
	upgrade_id: StringName,
	new_level: int
)

signal health_changed(
	current_health: float,
	maximum_health: float
)

signal died
signal revived

signal healing_over_time_applied(
	effect_id: StringName,
	duration: float
)

signal healing_over_time_ended(
	effect_id: StringName
)


@export_category("Health")
@export var max_health: float = 100.0


@export_category("Essence Upgrades")
@export_range(1, 50, 1)
var base_tree_upgrade_limit: int = 3

@export_range(1, 100, 1)
var age_per_additional_upgrade_level: int = 5

@export_range(1.01, 5.0, 0.01)
var tree_upgrade_cost_growth: float = 1.40

@export var max_health_per_upgrade: float = 20.0
@export var max_health_upgrade_base_cost: int = 15

@export var health_regeneration_per_upgrade: float = 0.50
@export var health_regeneration_upgrade_base_cost: int = 20

@export_range(0.01, 1.0, 0.01)
var essence_gain_per_upgrade: float = 0.10
@export var essence_gain_upgrade_base_cost: int = 25


@export_category("Tree Growth")
# Věk, při kterém strom dosáhne konečné fyzické velikosti.
@export_range(2, 500, 1)
var maturity_age: int = 40

# Rozměry mladého stromku.
@export var sapling_trunk_height: float = 125.0
@export var sapling_trunk_width: float = 48.0
@export var sapling_crown_radius: float = 82.0

# Konečné rozměry dospělého stromu.
@export var mature_trunk_height: float = 205.0
@export var mature_trunk_width: float = 82.0
@export var mature_crown_radius: float = 128.0

# Attachment pointy jsou u mladého stromku blíž ke středu.
@export_range(0.5, 1.0, 0.01)
var sapling_attachment_scale: float = 0.72


@export_category("Tree Aging")
@export_range(1, 1000, 1)
var old_tree_age: int = 100

@export_range(1, 2000, 1)
var ancient_tree_age: int = 250

@export var young_trunk_color: Color = Color("825235")
@export var mature_trunk_color: Color = Color("70452d")
@export var ancient_trunk_color: Color = Color("594034")

@export var young_crown_color: Color = Color("54a860")
@export var mature_crown_color: Color = Color("3f8f4f")
@export var ancient_crown_color: Color = Color("597f4b")


@export_category("Idle Animation")
@export_range(0.0, 0.1, 0.001)
var idle_scale_amount: float = 0.015

@export_range(0.1, 5.0, 0.1)
var idle_speed: float = 1.2


@export_category("Damage Feedback")
@export var damage_flash_duration: float = 0.08
@export var damage_shake_distance: float = 12.0
@export var damage_shake_duration: float = 0.05


var forest_essence: int = 0
var age: int = 1

var max_health_upgrade_level: int = 0
var health_regeneration_upgrade_level: int = 0
var essence_gain_upgrade_level: int = 0

# Uchovává desetinnou část bonusové Essence.
# Například +10 % z odměny 1 Essence se projeví
# jednou dodatečnou Essence přibližně po deseti odměnách.
var essence_fraction_buffer: float = 0.0

var idle_time: float = 0.0
var current_health: float
var is_dead: bool = false

var resting_position: Vector2
var damage_tween: Tween

# Původní pozice markerů z editoru.
var attachment_base_positions: Dictionary = {}

# Aktivní léčivé efekty v čase.
# Klíčem je effect_id, takže opětovná aplikace stejného efektu
# pouze obnoví jeho trvání a nevytvoří další stack.
var healing_over_time_effects: Dictionary = {}


func _ready() -> void:
	add_to_group("tree")

	resting_position = position
	current_health = max_health

	store_attachment_positions()
	update_tree_growth()

	health_changed.emit(
		current_health,
		max_health
	)


func _process(delta: float) -> void:
	idle_time += delta * idle_speed

	var breath: float = (
		sin(idle_time) * idle_scale_amount
	)

	# Scale slouží pouze pro jemné dýchání.
	# Samotný růst stromu řeší rozměry v _draw().
	scale = Vector2(
		1.0 + breath,
		1.0 - breath * 0.35
	)

	process_health_regeneration(delta)
	process_healing_over_time(delta)


func _draw() -> void:
	var growth_progress: float = (
		get_growth_progress()
	)

	var trunk_height: float = lerp(
		sapling_trunk_height,
		mature_trunk_height,
		growth_progress
	)

	var trunk_width: float = lerp(
		sapling_trunk_width,
		mature_trunk_width,
		growth_progress
	)

	var crown_radius: float = lerp(
		sapling_crown_radius,
		mature_crown_radius,
		growth_progress
	)

	var trunk_color: Color = get_current_trunk_color()
	var crown_color: Color = get_current_crown_color()

	draw_trunk(
		trunk_height,
		trunk_width,
		trunk_color
	)

	draw_crown(
		trunk_height,
		crown_radius,
		crown_color
	)

	draw_age_details(
		trunk_height,
		trunk_width
	)


func draw_trunk(
	trunk_height: float,
	trunk_width: float,
	trunk_color: Color
) -> void:
	draw_rect(
		Rect2(
			-trunk_width * 0.5,
			-trunk_height,
			trunk_width,
			trunk_height
		),
		trunk_color
	)


func draw_crown(
	trunk_height: float,
	crown_radius: float,
	crown_color: Color
) -> void:
	var crown_center := Vector2(
		0.0,
		-trunk_height - crown_radius * 0.38
	)

	draw_circle(
		crown_center,
		crown_radius,
		crown_color
	)


func draw_age_details(
	trunk_height: float,
	trunk_width: float
) -> void:
	if age < old_tree_age:
		return

	var bark_color := Color(
		0.20,
		0.13,
		0.09,
		0.45
	)

	var detail_count: int = 3

	if age >= ancient_tree_age:
		detail_count = 5

	for detail_index in range(detail_count):
		var x_position: float = lerp(
			-trunk_width * 0.28,
			trunk_width * 0.28,
			float(detail_index)
			/ max(float(detail_count - 1), 1.0)
		)

		var top_y: float = (
			-trunk_height * 0.82
			+ detail_index * 11.0
		)

		var bottom_y: float = (
			-trunk_height * 0.20
			- detail_index * 8.0
		)

		draw_line(
			Vector2(x_position, top_y),
			Vector2(x_position - 5.0, bottom_y),
			bark_color,
			3.0,
			true
		)


func get_growth_progress() -> float:
	var safe_maturity_age: int = max(
		maturity_age,
		2
	)

	var raw_progress: float = clamp(
		float(age - 1)
		/ float(safe_maturity_age - 1),
		0.0,
		1.0
	)

	# Rychlejší růst zpočátku, později zpomalení.
	return 1.0 - pow(
		1.0 - raw_progress,
		2.2
	)


func get_tree_growth_factor() -> float:
	return lerp(
		sapling_attachment_scale,
		1.0,
		get_growth_progress()
	)


func get_current_trunk_color() -> Color:
	if age < old_tree_age:
		var progress: float = clamp(
			float(age - 1)
			/ float(max(old_tree_age - 1, 1)),
			0.0,
			1.0
		)

		return young_trunk_color.lerp(
			mature_trunk_color,
			progress
		)

	var ancient_progress: float = clamp(
		float(age - old_tree_age)
		/ float(
			max(
				ancient_tree_age - old_tree_age,
				1
			)
		),
		0.0,
		1.0
	)

	return mature_trunk_color.lerp(
		ancient_trunk_color,
		ancient_progress
	)


func get_current_crown_color() -> Color:
	if age < old_tree_age:
		var progress: float = clamp(
			float(age - 1)
			/ float(max(old_tree_age - 1, 1)),
			0.0,
			1.0
		)

		return young_crown_color.lerp(
			mature_crown_color,
			progress
		)

	var ancient_progress: float = clamp(
		float(age - old_tree_age)
		/ float(
			max(
				ancient_tree_age - old_tree_age,
				1
			)
		),
		0.0,
		1.0
	)

	return mature_crown_color.lerp(
		ancient_crown_color,
		ancient_progress
	)


func store_attachment_positions() -> void:
	var attachment_points: Node = get_node_or_null(
		"AttachmentPoints"
	)

	if attachment_points == null:
		return

	for child in attachment_points.get_children():
		if child is not Node2D:
			continue

		var marker := child as Node2D

		attachment_base_positions[
			marker.get_path()
		] = marker.position


func update_attachment_positions() -> void:
	var attachment_points: Node = get_node_or_null(
		"AttachmentPoints"
	)

	if attachment_points == null:
		return

	var growth_factor: float = (
		get_tree_growth_factor()
	)

	for child in attachment_points.get_children():
		if child is not Node2D:
			continue

		var marker := child as Node2D
		var marker_path: NodePath = marker.get_path()

		if not attachment_base_positions.has(
			marker_path
		):
			continue

		var base_position: Vector2 = (
			attachment_base_positions[marker_path]
		)

		marker.position = (
			base_position * growth_factor
		)


func update_tree_growth() -> void:
	update_attachment_positions()
	queue_redraw()

	growth_changed.emit(
		get_tree_growth_factor()
	)


func get_maximum_tree_upgrade_level() -> int:
	var safe_age_interval: int = max(
		age_per_additional_upgrade_level,
		1
	)

	var additional_levels: int = int(
		floor(
			float(max(age - 1, 0))
			/ float(safe_age_interval)
		)
	)

	return max(
		base_tree_upgrade_limit + additional_levels,
		1
	)


func get_tree_upgrade_cost(
	base_cost: int,
	current_upgrade_level: int
) -> int:
	var calculated_cost: float = (
		float(base_cost)
		* pow(
			tree_upgrade_cost_growth,
			current_upgrade_level
		)
	)

	return max(
		int(round(calculated_cost)),
		1
	)


func get_max_health_upgrade_cost() -> int:
	return get_tree_upgrade_cost(
		max_health_upgrade_base_cost,
		max_health_upgrade_level
	)


func get_health_regeneration_upgrade_cost() -> int:
	return get_tree_upgrade_cost(
		health_regeneration_upgrade_base_cost,
		health_regeneration_upgrade_level
	)


func get_essence_gain_upgrade_cost() -> int:
	return get_tree_upgrade_cost(
		essence_gain_upgrade_base_cost,
		essence_gain_upgrade_level
	)


func can_upgrade_tree_stat(
	current_upgrade_level: int
) -> bool:
	return (
		current_upgrade_level
		< get_maximum_tree_upgrade_level()
	)


func get_current_health_regeneration() -> float:
	return (
		health_regeneration_upgrade_level
		* health_regeneration_per_upgrade
	)


func get_current_essence_multiplier() -> float:
	return (
		1.0
		+ essence_gain_upgrade_level
		* essence_gain_per_upgrade
	)


func purchase_max_health_upgrade() -> bool:
	if not can_upgrade_tree_stat(
		max_health_upgrade_level
	):
		return false

	var cost: int = get_max_health_upgrade_cost()

	if not spend_forest_essence(cost):
		return false

	max_health_upgrade_level += 1
	max_health += max_health_per_upgrade
	current_health = min(
		current_health + max_health_per_upgrade,
		max_health
	)

	tree_upgrade_changed.emit(
		&"max_health",
		max_health_upgrade_level
	)

	health_changed.emit(
		current_health,
		max_health
	)

	print_tree_upgrade_result(
		"Maximum HP",
		max_health_upgrade_level,
		cost
	)

	return true


func purchase_health_regeneration_upgrade() -> bool:
	if not can_upgrade_tree_stat(
		health_regeneration_upgrade_level
	):
		return false

	var cost: int = (
		get_health_regeneration_upgrade_cost()
	)

	if not spend_forest_essence(cost):
		return false

	health_regeneration_upgrade_level += 1

	tree_upgrade_changed.emit(
		&"health_regeneration",
		health_regeneration_upgrade_level
	)

	print_tree_upgrade_result(
		"HP Regeneration",
		health_regeneration_upgrade_level,
		cost
	)

	return true


func purchase_essence_gain_upgrade() -> bool:
	if not can_upgrade_tree_stat(
		essence_gain_upgrade_level
	):
		return false

	var cost: int = get_essence_gain_upgrade_cost()

	if not spend_forest_essence(cost):
		return false

	essence_gain_upgrade_level += 1

	tree_upgrade_changed.emit(
		&"essence_gain",
		essence_gain_upgrade_level
	)

	print_tree_upgrade_result(
		"Essence Gain",
		essence_gain_upgrade_level,
		cost
	)

	return true


func print_tree_upgrade_result(
	upgrade_name: String,
	new_upgrade_level: int,
	cost: int
) -> void:
	print(
		upgrade_name,
		" upgraded to Level ",
		new_upgrade_level,
		" | Cost: ",
		cost,
		" | Max HP: ",
		max_health,
		" | HP Regen: ",
		get_current_health_regeneration(),
		"/s | Essence Gain: x",
		get_current_essence_multiplier()
	)


func process_health_regeneration(delta: float) -> void:
	if is_dead:
		return

	if current_health >= max_health:
		return

	var regeneration_per_second: float = (
		get_current_health_regeneration()
	)

	if regeneration_per_second <= 0.0:
		return

	heal(
		regeneration_per_second * delta
	)


func apply_healing_over_time(
	effect_id: StringName,
	healing_per_tick: float,
	tick_interval: float,
	duration: float,
	source: Node = null,
	print_ticks: bool = false
) -> bool:
	if is_dead:
		return false

	if effect_id == &"":
		return false

	if healing_per_tick <= 0.0:
		return false

	if tick_interval <= 0.0:
		return false

	if duration <= 0.0:
		return false

	var source_reference: WeakRef = null

	if is_instance_valid(source):
		source_reference = weakref(source)

	if healing_over_time_effects.has(effect_id):
		var existing_effect: Dictionary = (
			healing_over_time_effects[effect_id]
		)

		var existing_time_until_tick: float = (
			float(
				existing_effect.get(
					"time_until_tick",
					tick_interval
				)
			)
		)

		healing_over_time_effects[effect_id] = {
			"healing_per_tick": healing_per_tick,
			"tick_interval": tick_interval,
			"remaining_duration": duration,
			"time_until_tick": min(
				existing_time_until_tick,
				tick_interval
			),
			"source": source_reference,
			"print_ticks": print_ticks
		}
	else:
		healing_over_time_effects[effect_id] = {
			"healing_per_tick": healing_per_tick,
			"tick_interval": tick_interval,
			"remaining_duration": duration,
			"time_until_tick": tick_interval,
			"source": source_reference,
			"print_ticks": print_ticks
		}

	healing_over_time_applied.emit(
		effect_id,
		duration
	)

	return true


func process_healing_over_time(delta: float) -> void:
	if is_dead:
		return

	if healing_over_time_effects.is_empty():
		return

	var effect_ids: Array = (
		healing_over_time_effects.keys()
	)

	for effect_key in effect_ids:
		var effect_id: StringName = (
			StringName(effect_key)
		)

		if not healing_over_time_effects.has(
			effect_id
		):
			continue

		var effect: Dictionary = (
			healing_over_time_effects[effect_id]
		)

		var remaining_duration: float = (
			float(effect["remaining_duration"])
			- delta
		)

		var time_until_tick: float = (
			float(effect["time_until_tick"])
			- delta
		)

		var tick_interval: float = float(
			effect["tick_interval"]
		)

		while time_until_tick <= 0.0:
			var source_node: Node = null
			var source_reference: WeakRef = (
				effect.get("source") as WeakRef
			)

			if source_reference != null:
				var referenced_source: Object = (
					source_reference.get_ref()
				)

				if referenced_source is Node:
					source_node = (
						referenced_source as Node
					)

			heal(
				float(effect["healing_per_tick"]),
				source_node,
				bool(effect["print_ticks"])
			)

			time_until_tick += tick_interval

		effect["remaining_duration"] = (
			remaining_duration
		)

		effect["time_until_tick"] = (
			time_until_tick
		)

		if remaining_duration <= 0.0:
			healing_over_time_effects.erase(
				effect_id
			)

			healing_over_time_ended.emit(
				effect_id
			)
		else:
			healing_over_time_effects[effect_id] = (
				effect
			)


func clear_healing_over_time_effects() -> void:
	if healing_over_time_effects.is_empty():
		return

	var effect_ids: Array = (
		healing_over_time_effects.keys()
	)

	healing_over_time_effects.clear()

	for effect_key in effect_ids:
		healing_over_time_ended.emit(
			StringName(effect_key)
		)


func has_healing_over_time_effect(
	effect_id: StringName
) -> bool:
	return healing_over_time_effects.has(
		effect_id
	)


func calculate_forest_essence_reward(
	base_amount: int
) -> int:
	if base_amount <= 0:
		return 0

	var exact_reward: float = (
		float(base_amount)
		* get_current_essence_multiplier()
		+ essence_fraction_buffer
	)

	var rewarded_essence: int = int(
		floor(exact_reward)
	)

	essence_fraction_buffer = (
		exact_reward
		- float(rewarded_essence)
	)

	return max(
		rewarded_essence,
		1
	)


func add_forest_essence(amount: int) -> void:
	if amount <= 0:
		return

	forest_essence += amount

	forest_essence_changed.emit(
		forest_essence
	)

func add_age(amount: int) -> void:
	if amount <= 0:
		return

	age += amount

	update_tree_growth()

	age_changed.emit(age)

	print(
		"Strom dosáhl věku ",
		age,
		" | Growth factor: ",
		get_tree_growth_factor()
	)


func heal(
	amount: float,
	source: Node = null,
	print_result: bool = false
) -> float:
	if is_dead:
		return 0.0

	if amount <= 0.0:
		return 0.0

	if current_health >= max_health:
		return 0.0

	var health_before: float = current_health

	current_health = min(
		current_health + amount,
		max_health
	)

	var actual_healing: float = (
		current_health - health_before
	)

	if actual_healing <= 0.0:
		return 0.0

	health_changed.emit(
		current_health,
		max_health
	)

	if print_result:
		var source_name: String = "Unknown"

		if is_instance_valid(source):
			source_name = source.name

		print(
			"Strom byl vyléčen o ",
			actual_healing,
			" HP | Zdroj: ",
			source_name,
			" | HP: ",
			current_health,
			"/",
			max_health
		)

	return actual_healing


func take_damage(amount: float) -> void:
	if is_dead:
		return

	if amount <= 0.0:
		return

	current_health = max(
		current_health - amount,
		0.0
	)

	health_changed.emit(
		current_health,
		max_health
	)

	play_damage_feedback()

	print(
		"Strom dostal ",
		amount,
		" poškození | HP: ",
		current_health,
		"/",
		max_health
	)

	if current_health <= 0.0:
		die()


func play_damage_feedback() -> void:
	if is_instance_valid(damage_tween):
		damage_tween.kill()

	position = resting_position
	modulate = Color.WHITE

	damage_tween = create_tween()
	damage_tween.set_parallel(true)

	damage_tween.tween_property(
		self,
		"modulate",
		Color(1.0, 0.35, 0.35, 1.0),
		damage_flash_duration
	)

	damage_tween.tween_property(
		self,
		"position",
		resting_position + Vector2(
			damage_shake_distance,
			0.0
		),
		damage_shake_duration
	)

	damage_tween.set_parallel(false)

	damage_tween.tween_property(
		self,
		"position",
		resting_position - Vector2(
			damage_shake_distance,
			0.0
		),
		damage_shake_duration
	)

	damage_tween.tween_property(
		self,
		"position",
		resting_position,
		damage_shake_duration
	)

	damage_tween.tween_property(
		self,
		"modulate",
		Color.WHITE,
		damage_flash_duration
	)


func die() -> void:
	if is_dead:
		return

	is_dead = true
	current_health = 0.0

	clear_healing_over_time_effects()

	if is_instance_valid(damage_tween):
		damage_tween.kill()

	position = resting_position
	modulate = Color(
		0.55,
		0.55,
		0.55,
		1.0
	)

	health_changed.emit(
		current_health,
		max_health
	)

	died.emit()

	print("Strom zemřel")


func revive() -> void:
	if not is_dead:
		return

	if is_instance_valid(damage_tween):
		damage_tween.kill()

	is_dead = false
	current_health = max_health

	position = resting_position
	modulate = Color.WHITE

	health_changed.emit(
		current_health,
		max_health
	)

	revived.emit()

	print(
		"Strom byl oživen | HP: ",
		current_health,
		"/",
		max_health
	)
	
func get_forest_essence() -> int:
	return forest_essence


func spend_forest_essence(amount: int) -> bool:
	if amount <= 0:
		return false

	if forest_essence < amount:
		return false

	forest_essence -= amount

	forest_essence_changed.emit(
		forest_essence
	)

	print(
		"Spent ",
		amount,
		" Forest Essence | Remaining: ",
		forest_essence
	)

	return true
