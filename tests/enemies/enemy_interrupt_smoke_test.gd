extends Node


class MockTree:
	extends Node2D
	func take_damage(_amount: float) -> void:
		pass


var failures: Array[String] = []


func _ready() -> void:
	var tree_node := MockTree.new()
	tree_node.position = Vector2.ZERO
	add_child(tree_node)
	tree_node.add_to_group("tree")
	var normal: Node = _create_enemy("res://scenes/enemies/bark_beetle.tscn", &"bark_beetle", Vector2(180.0, 0.0))
	var miniboss: Node = _create_enemy("res://scenes/enemies/bark_warden.tscn", &"bark_warden", Vector2(180.0, 30.0))
	var boss: Node = _create_enemy("res://scenes/enemies/ancient_bark_colossus.tscn", &"ancient_bark_colossus", Vector2(180.0, 60.0))
	var attack_component := normal.get_node("AttackComponent") as EnemyAttackComponent
	attack_component.start_attacking()
	expect(normal.call("can_be_interrupted"), "Normal enemy is not interruptible.")
	expect(normal.call("interrupt_attack"), "Normal enemy attack cycle was not interrupted.")
	expect(not attack_component.is_attacking(), "Interrupt did not cancel the active attack timer.")
	expect(not miniboss.call("can_be_interrupted"), "Bark Warden lost default interrupt immunity.")
	expect(not miniboss.call("interrupt_attack"), "Bark Warden attack was interrupted.")
	expect(not boss.call("can_be_interrupted"), "Ancient Bark Colossus lost default interrupt immunity.")
	expect(not boss.call("interrupt_attack"), "Ancient Bark Colossus attack was interrupted.")
	expect(normal.call("get_current_health") == normal.call("get_maximum_health"), "Enemy health query seam is inconsistent.")
	if failures.is_empty():
		print("ENEMY INTERRUPT SMOKE TEST PASS")
		get_tree().quit(0)
		return
	print("ENEMY INTERRUPT SMOKE TEST FAIL: %d failure(s)" % failures.size())
	get_tree().quit(1)


func _create_enemy(scene_path: String, enemy_id: StringName, enemy_position: Vector2) -> Node:
	var enemy_scene := load(scene_path) as PackedScene
	var enemy: Node = enemy_scene.instantiate()
	var definition: EnemyDefinition = GameContent.get_enemy(enemy_id)
	expect(is_instance_valid(definition), "Missing EnemyDefinition '%s'." % enemy_id)
	enemy.call("configure_from_definition", definition)
	add_child(enemy)
	enemy.call("setup_crowd_formation", 1.0, 3, enemy_position.y, 0, 1.0, 0.0, 1.0)
	(enemy as Node2D).position.x = enemy_position.x
	return enemy


func expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
