@tool
extends Node

const SocialGraphClass = preload("res://scripts/systems/SocialGraph.gd")
const SocialGraphManagerClass = preload("res://scripts/systems/SocialGraphManager.gd")
const NPCClass = preload("res://scripts/entities/NPC.gd")

## Ejecuta el conjunto de pruebas básicas al entrar en escena.
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	run_all_tests()


## Ejecuta todas las pruebas registradas y muestra resultados en la consola.
func run_all_tests() -> void:
	var tests := [
		_test_npc_registration,
		_test_serialization_roundtrip,
		_test_decay_behavior,
		_test_cleanup_invalid_nodes,
		_test_manager_wrappers
	]
	var passed := 0
	for callable in tests:
		var outcome: Dictionary = callable.call()
		if outcome.get("passed", false):
			passed += 1
			print("[SocialGraph][PASS] %s" % outcome.get("name", "Unnamed"))
		else:
			push_error("[SocialGraph][FAIL] %s -> %s" % [outcome.get("name", "Unnamed"), outcome.get("details", "")])
	print("[SocialGraph] %d/%d tests passed" % [passed, tests.size()])


func _test_npc_registration() -> Dictionary:
	var graph := SocialGraphClass.new()
	var npc := NPCClass.new()
	npc.npc_id = 42
	graph.ensure_npc(npc, {"role": "test"})
	var vertex := graph.get_vertex_by_npc(npc)
	var passed := vertex != null and vertex.id == 42
	npc.queue_free()
	return {
		"name": "NPC registration stores weak refs",
		"passed": passed,
		"details": "Vertex not created" if not passed else ""
	}


func _test_serialization_roundtrip() -> Dictionary:
	var graph := SocialGraphClass.new()
	graph.connect_npcs(1, 2, 75.0)
	graph.connect_npcs(2, 3, 25.0)
	var data := graph.serialize()
	graph.clear()
	var ok := graph.deserialize(data)
	var reconnected := graph.has_edge(1, 2) and graph.has_edge(2, 3)
	return {
		"name": "Serialize/Deserialize preserves edges",
		"passed": ok and reconnected,
		"details": "Deserialize failed" if not ok else "Edges missing after reload"
	}


func _test_decay_behavior() -> Dictionary:
	var graph := SocialGraphClass.new()
	graph.connect_npcs(10, 11, 5.0)
	graph.decay_rate_per_second = 10.0
	var stats := graph.apply_decay(1.0)
	var removed: bool = stats.get("removed", 0) >= 1
	return {
		"name": "Decay removes edges when weight reaches zero",
		"passed": removed and not graph.has_edge(10, 11),
		"details": "Edge still present after decay"
	}


func _test_cleanup_invalid_nodes() -> Dictionary:
	var graph := SocialGraphClass.new()
	var npc := NPCClass.new()
	npc.npc_id = 99
	graph.ensure_npc(npc)
	npc.queue_free()
	var removed := graph.cleanup_invalid_nodes()
	return {
		"name": "Cleanup removes freed NPCs",
		"passed": removed >= 1,
		"details": "No nodes removed" if removed == 0 else ""
	}


func _test_manager_wrappers() -> Dictionary:
	var manager := SocialGraphManagerClass.new()
	manager._ready()
	manager.ensure_npc(5)
	manager.ensure_npc(6)
	manager.add_connection(5, 6, 10.0)
	var serialized := manager.serialize_graph()
	var valid: bool = serialized.get("metadata", {}).get("edge_count", 0) == 1
	return {
		"name": "Manager delegates serialization",
		"passed": valid,
		"details": "Edge count mismatch"
	}
