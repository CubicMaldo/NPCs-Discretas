@tool
extends TestSuiteBase

## Ejecuta el conjunto de pruebas básicas al entrar en escena.
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	test_prefix = "SocialGraph"
	clear_tests()
	_register_tests()
	run_all_tests()


func _register_tests() -> void:
	add_test(Callable(self, "_test_npc_registration"), "NPC registration stores weak refs")
	add_test(Callable(self, "_test_serialization_roundtrip"), "Serialize/Deserialize preserves edges")
	add_test(Callable(self, "_test_decay_behavior"), "Decay removes edges when weight reaches zero")
	add_test(Callable(self, "_test_cleanup_invalid_nodes"), "Cleanup removes freed NPCs")
	add_test(Callable(self, "_test_manager_wrappers"), "Manager delegates serialization")
	add_test(Callable(self, "_test_caching_layer"), "Caching layer mirrors edges")
	add_test(Callable(self, "_test_shortest_path"), "Shortest path uses Dijkstra")
	add_test(Callable(self, "_test_mutual_connections"), "Mutual friend analytics")
	add_test(Callable(self, "_test_rumor_propagation"), "Rumor propagation reaches neighbors")


func _test_npc_registration() -> Dictionary:
	var graph := SocialGraph.new()
	var npc := NPC.new()
	npc.npc_id = 42
	var meta := NPCVertexMeta.new()
	meta.role = "test"
	graph.ensure_npc(npc, meta)
	var vertex := graph.get_vertex_by_npc(npc)
	var passed := vertex != null and vertex.id == 42
	npc.free()
	graph.clear()
	return assert_true(passed, "NPC registration stores weak refs", "Vertex not created")


func _test_serialization_roundtrip() -> Dictionary:
	var graph := SocialGraph.new()
	graph.connect_npcs(1, 2, 75.0)
	graph.connect_npcs(2, 3, 25.0)
	var data := graph.serialize()
	graph.clear()
	var ok := graph.deserialize(data)
	var reconnected := graph.has_edge(1, 2) and graph.has_edge(2, 3)
	var passed := ok and reconnected
	var details := ""
	if not passed:
		details = "Deserialize failed" if not ok else "Edges missing after reload"
	graph.clear()
	return make_result("Serialize/Deserialize preserves edges", passed, details)


func _test_decay_behavior() -> Dictionary:
	var graph := SocialGraph.new()
	graph.connect_npcs(10, 11, 5.0)
	graph.decay_rate_per_second = 10.0
	var stats := graph.apply_decay(1.0)
	var removed: bool = stats.get("removed", 0) >= 1
	var passed := removed and not graph.has_edge(10, 11)
	graph.clear()
	return assert_true(passed, "Decay removes edges when weight reaches zero", "Edge still present after decay")


func _test_cleanup_invalid_nodes() -> Dictionary:
	var graph := SocialGraph.new()
	var npc := NPC.new()
	npc.npc_id = 99
	graph.ensure_npc(npc)
	npc.free()
	var removed := graph.cleanup_invalid_nodes()
	graph.clear()
	return assert_true(removed >= 1, "Cleanup removes freed NPCs", "No nodes removed")


func _test_manager_wrappers() -> Dictionary:
	var manager := SocialGraphManager.new()
	manager._ready()
	manager.ensure_npc(5)
	manager.ensure_npc(6)
	manager.add_connection(5, 6, 10.0)
	var serialized := manager.serialize_graph()
	var valid: bool = serialized.get("metadata", {}).get("edge_count", 0) == 1
	manager.social_graph.clear()
	return assert_true(valid, "Manager delegates serialization", "Edge count mismatch")


func _test_caching_layer() -> Dictionary:
	var graph := SocialGraph.new()
	# En grafo dirigido: 1→2, 2→3
	graph.connect_npcs(1, 2, 10.0)
	graph.connect_npcs(2, 3, 5.0)

	var cache := graph.get_cached_neighbors(2)
	var cache_ids := graph.get_cached_neighbors_ids(2)
	var degree := graph.get_cached_degree(2)
	var degree_ids := graph.get_cached_degree_ids(2)
	
	var baseline_ok: bool = not cache.has(1) and cache.get(3, null) == 5.0
	baseline_ok = baseline_ok and not cache_ids.has(1) and cache_ids.get(3, null) == 5.0
	baseline_ok = baseline_ok and degree == 1 and degree_ids == 1
	graph.break_relationship(2, 3)
	var cache_after := graph.get_cached_neighbors(2)
	var removal_ok: bool = not cache_after.has(3)
	var passed: bool = baseline_ok and removal_ok
	graph.clear()
	return assert_true(passed, "Caching layer mirrors edges", "Cache desync detected")


func _test_shortest_path() -> Dictionary:
	var graph := SocialGraph.new()
	graph.connect_npcs(1, 2, 1.0)
	graph.connect_npcs(2, 3, 1.0)
	graph.connect_npcs(1, 3, 5.0)
	var result := graph.get_shortest_path(1, 3)
	graph.clear()
	if not result.get("reachable", false):
		return make_result("Shortest path uses Dijkstra", false, "Nodes reported unreachable")
	var path_ids: Array = result.get("path_ids", result.get("path", []))
	if path_ids != [1, 2, 3]:
		return make_result("Shortest path uses Dijkstra", false, "Unexpected path %s" % [str(path_ids)])
	return assert_float_approx(2.0, float(result.get("distance", 0.0)), 0.01, "Shortest path uses Dijkstra")


func _test_mutual_connections() -> Dictionary:
	var graph := SocialGraph.new()
	graph.connect_npcs(1, 2, 80.0)
	graph.connect_npcs(1, 3, 60.0)
	graph.connect_npcs(2, 3, 70.0)
	graph.connect_npcs(2, 4, 30.0)
	var result := graph.get_mutual_connections(1, 2, 50.0)
	var count_ok: bool = result.get("count", 0) == 1
	var entries: Array = result.get("entries_ids", [])
	graph.clear()
	if not count_ok or entries.size() == 0:
		return make_result("Mutual friend analytics", false, "Expected single mutual friend")
	var entry: Dictionary = entries[0]
	if entry.get("neighbor_id", null) != 3:
		return make_result("Mutual friend analytics", false, "Unexpected neighbor %s" % [str(entry)])
	return assert_float_approx(65.0, float(entry.get("average_weight", 0.0)), 0.1, "Mutual friend analytics")


func _test_rumor_propagation() -> Dictionary:
	var graph := SocialGraph.new()
	graph.connect_npcs(1, 2, 100.0)
	graph.connect_npcs(2, 3, 50.0)
	var result: Dictionary = graph.simulate_rumor(1, 3, 0.5, 0.1)
	var influence: Dictionary = result.get("influence_ids", {})
	graph.clear()
	if not influence.has(2) or not influence.has(3):
		return make_result("Rumor propagation reaches neighbors", false, "Influence map missing ids -> %s" % [str(influence)])
	var check_mid: Dictionary = assert_float_approx(0.5, float(influence.get(2, 0.0)), 0.05, "Rumor propagation reaches neighbors")
	if not check_mid.get("passed", false):
		return check_mid
	return assert_float_approx(0.125, float(influence.get(3, 0.0)), 0.05, "Rumor propagation reaches neighbors")
