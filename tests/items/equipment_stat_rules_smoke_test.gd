extends Node


var failures: Array[String] = []


func _ready() -> void:
	test_supported_stats()
	test_display_names()
	test_value_formatting()

	if failures.is_empty():
		print("EQUIPMENT STAT RULES SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("EQUIPMENT STAT RULES SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func test_supported_stats() -> void:
	var supported_ids: Array[StringName] = EquipmentStatRules.get_supported_stat_ids()
	expect(
		supported_ids == [
			&"maximum_health",
			&"health_regeneration",
			&"branch_damage",
			&"attack_speed"
		],
		"Equipment Stat V1 supported IDs are not exact or deterministic."
	)
	for stat_id in supported_ids:
		expect(
			EquipmentStatRules.is_supported_stat_id(stat_id),
			"Supported stat %s was rejected." % stat_id
		)
	expect(
		not EquipmentStatRules.is_supported_stat_id(&"range")
		and not EquipmentStatRules.is_supported_stat_id(&"defense")
		and not EquipmentStatRules.is_supported_stat_id(&"healing_power"),
		"Equipment Stat V1 accepts an out-of-scope stat."
	)
	expect(
		EquipmentStatRules.is_percentage_stat(&"branch_damage")
		and EquipmentStatRules.is_percentage_stat(&"attack_speed")
		and not EquipmentStatRules.is_percentage_stat(&"maximum_health")
		and not EquipmentStatRules.is_percentage_stat(&"health_regeneration"),
		"Flat/percentage stat classification is wrong."
	)


func test_display_names() -> void:
	expect(
		EquipmentStatRules.get_stat_display_name(&"maximum_health") == "Maximum Health"
		and EquipmentStatRules.get_stat_display_name(&"health_regeneration") == "Health Regeneration"
		and EquipmentStatRules.get_stat_display_name(&"branch_damage") == "Branch Damage"
		and EquipmentStatRules.get_stat_display_name(&"attack_speed") == "Attack Speed"
		and EquipmentStatRules.get_stat_display_name(&"future_stat") == "",
		"Equipment stat display names are wrong."
	)


func test_value_formatting() -> void:
	expect(
		EquipmentStatRules.format_stat_value(&"maximum_health", 20.0) == "+20",
		"Maximum Health formatting is wrong."
	)
	expect(
		EquipmentStatRules.format_stat_value(&"health_regeneration", 0.5) == "+0.5/s",
		"Health Regeneration formatting is wrong."
	)
	expect(
		EquipmentStatRules.format_stat_value(&"branch_damage", 0.10) == "+10%",
		"Branch Damage formatting is wrong."
	)
	expect(
		EquipmentStatRules.format_stat_value(&"attack_speed", 0.15) == "+15%",
		"Attack Speed formatting is wrong."
	)
	expect(
		EquipmentStatRules.format_stat_value(&"branch_damage", -0.125) == "-12.5%"
		and EquipmentStatRules.format_stat_value(&"future_stat", 10.0) == "",
		"Safe negative or unknown stat formatting is wrong."
	)


func expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error(message)
