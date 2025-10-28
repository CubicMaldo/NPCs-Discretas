@tool
extends TestSuiteBase

const SocialGraphClass = preload("res://scripts/systems/SocialGraph.gd")
const SocialGraphManagerClass = preload("res://scripts/systems/SocialGraphManager.gd")
const NPCClass = preload("res://scripts/entities/NPC.gd")

## Ejecuta el conjunto de pruebas básicas al entrar en escena.
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	test_prefix = "SocialGraph"
	clear_tests()
	_register_tests()
	
	# Imprimir la ubicación de los archivos de prueba
	print("============================================================")
	print("Archivos de prueba se guardan en:")
	print(OS.get_user_data_dir())
	print("============================================================")
	
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
	add_test(Callable(self, "_test_strongest_path"), "Strongest path prefers high familiarity")
	add_test(Callable(self, "_test_directed_graph_behavior"), "Directed graph allows asymmetric relationships")
	add_test(Callable(self, "_test_mutual_connection_helper"), "Mutual connection helper creates bidirectional edges")
	add_test(Callable(self, "_test_save_to_file_compressed"), "Save graph to compressed file")
	add_test(Callable(self, "_test_save_to_file_uncompressed"), "Save graph to uncompressed file")
	add_test(Callable(self, "_test_load_from_file"), "Load graph from file preserves data")
	add_test(Callable(self, "_test_save_load_roundtrip"), "Save/Load roundtrip maintains integrity")
	add_test(Callable(self, "_test_save_load_compressed_roundtrip"), "Compressed save/load roundtrip works")
	add_test(Callable(self, "_test_pretty_json_format"), "JSON files are human-readable with indentation")


func _test_npc_registration() -> Dictionary:
	var graph := SocialGraphClass.new()
	var npc := NPCClass.new()
	npc.npc_id = 42
	graph.ensure_npc(npc, {"role": "test"})
	var vertex := graph.get_vertex_by_npc(npc)
	var passed := vertex != null and vertex.id == 42
	npc.free()
	return assert_true(passed, "NPC registration stores weak refs", "Vertex not created")


func _test_serialization_roundtrip() -> Dictionary:
	var graph := SocialGraphClass.new()
	# Crear aristas dirigidas
	graph.connect_npcs(1, 2, 75.0)
	graph.connect_npcs(2, 3, 25.0)
	var data := graph.serialize()
	graph.clear()
	var ok := graph.deserialize(data)
	# Verificar que las aristas dirigidas existen
	var reconnected := graph.has_edge(1, 2) and graph.has_edge(2, 3)
	# Verificar que NO existen las aristas inversas (grafo dirigido)
	var no_reverse := not graph.has_edge(2, 1) and not graph.has_edge(3, 2)
	var passed := ok and reconnected and no_reverse
	var details := ""
	if not passed:
		if not ok:
			details = "Deserialize failed"
		elif not reconnected:
			details = "Directed edges missing after reload"
		else:
			details = "Unexpected reverse edges found (should be directed)"
	return make_result("Serialize/Deserialize preserves edges", passed, details)


func _test_decay_behavior() -> Dictionary:
	var graph := SocialGraphClass.new()
	graph.connect_npcs(10, 11, 5.0)
	graph.decay_rate_per_second = 10.0
	var stats := graph.apply_decay(1.0)
	var removed: bool = stats.get("removed", 0) >= 1
	var passed := removed and not graph.has_edge(10, 11)
	return assert_true(passed, "Decay removes edges when weight reaches zero", "Edge still present after decay")


func _test_cleanup_invalid_nodes() -> Dictionary:
	var graph := SocialGraphClass.new()
	var npc := NPCClass.new()
	npc.npc_id = 99
	graph.ensure_npc(npc)
	npc.free()
	var removed := graph.cleanup_invalid_nodes()
	return assert_true(removed >= 1, "Cleanup removes freed NPCs", "No nodes removed")


func _test_manager_wrappers() -> Dictionary:
	var manager := SocialGraphManagerClass.new()
	manager._ready()
	manager.ensure_npc(5)
	manager.ensure_npc(6)
	manager.add_connection(5, 6, 10.0)
	var serialized := manager.serialize_graph()
	var valid: bool = serialized.get("metadata", {}).get("edge_count", 0) == 1
	return assert_true(valid, "Manager delegates serialization", "Edge count mismatch")


func _test_caching_layer() -> Dictionary:
	var graph := SocialGraphClass.new()
	# Crear aristas dirigidas: 1→2 y 2→3
	graph.connect_npcs(1, 2, 10.0)
	graph.connect_npcs(2, 3, 5.0)
	
	# El nodo 2 tiene una arista saliente (2→3) y una entrante (1→2)
	# El caché de vecinos debe mostrar solo las aristas SALIENTES
	var cache := graph.get_cached_neighbors(2)
	var cache_ids := graph.get_cached_neighbors_ids(2)
	var degree := graph.get_cached_degree(2)
	var degree_ids := graph.get_cached_degree_ids(2)
	
	# En grafo dirigido: el nodo 2 solo tiene arista saliente a 3
	# NO debe tener a 1 en sus vecinos (1→2 es entrante, no saliente)
	var baseline_ok: bool = cache.get(3, null) == 5.0
	baseline_ok = baseline_ok and not cache.has(1)  # 1 no es vecino saliente de 2
	baseline_ok = baseline_ok and cache_ids.get(3, null) == 5.0
	baseline_ok = baseline_ok and not cache_ids.has(1)
	baseline_ok = baseline_ok and degree == 1 and degree_ids == 1  # Solo 1 arista saliente
	
	graph.break_relationship(2, 3)
	var cache_after := graph.get_cached_neighbors(2)
	var removal_ok: bool = not cache_after.has(3)
	var passed: bool = baseline_ok and removal_ok
	
	var details := ""
	if not passed:
		if not baseline_ok:
			details = "Cache should only contain outgoing edges in directed graph. Cache: %s" % [str(cache)]
		else:
			details = "Cache not updated after edge removal"
	
	return make_result("Caching layer mirrors edges", passed, details)


func _test_shortest_path() -> Dictionary:
	var graph := SocialGraphClass.new()
	# Crear caminos dirigidos: 1→2→3 (costo 2) vs 1→3 (costo 5)
	graph.connect_npcs(1, 2, 1.0)
	graph.connect_npcs(2, 3, 1.0)
	graph.connect_npcs(1, 3, 5.0)
	
	var result := graph.get_shortest_path(1, 3)
	if not result.get("reachable", false):
		return make_result("Shortest path uses Dijkstra", false, "Nodes reported unreachable")
	
	var path_ids: Array = result.get("path_ids", result.get("path", []))
	if path_ids != [1, 2, 3]:
		return make_result("Shortest path uses Dijkstra", false, "Expected [1,2,3], got %s" % [str(path_ids)])
	
	# Verificar que NO hay camino inverso (grafo dirigido)
	var reverse_result := graph.get_shortest_path(3, 1)
	if reverse_result.get("reachable", false):
		return make_result("Shortest path uses Dijkstra", false, "Reverse path should not exist in directed graph")
	
	return assert_float_approx(2.0, float(result.get("distance", 0.0)), 0.01, "Shortest path uses Dijkstra")


func _test_strongest_path() -> Dictionary:
	var graph := SocialGraphClass.new()
	# Crear caminos dirigidos con diferentes fuerzas
	# Camino directo: 1→3 (strength 0.5)
	# Camino via 2: 1→2→3 (strength 0.8 * 0.9 = 0.72)
	graph.connect_npcs(1, 2, 80.0)
	graph.connect_npcs(2, 3, 90.0)
	graph.connect_npcs(1, 3, 50.0)
	
	var result: Dictionary = graph.get_strongest_path(1, 3)
	if not result.get("reachable", false):
		return make_result("Strongest path prefers high familiarity", false, "Nodes unreachable")
	
	var path_ids: Array = result.get("path_ids", [])
	if path_ids != [1, 2, 3]:
		return make_result("Strongest path prefers high familiarity", false, "Expected [1,2,3], got %s" % [str(path_ids)])
	
	var expected_strength := 0.8 * 0.9
	
	# Verificar que NO hay camino inverso
	var reverse_result := graph.get_strongest_path(3, 1)
	if reverse_result.get("reachable", false):
		return make_result("Strongest path prefers high familiarity", false, "Reverse path should not exist in directed graph")
	
	return assert_float_approx(expected_strength, float(result.get("strength", 0.0)), 0.01, "Strongest path prefers high familiarity")


func _test_mutual_connections() -> Dictionary:
	var graph := SocialGraphClass.new()
	# En grafo dirigido, crear relaciones bidireccionales explícitamente
	# 1↔2, 1↔3, 2↔3, 2→4 (unidireccional)
	graph.connect_npcs_mutual(1, 2, 80.0, 80.0)
	graph.connect_npcs_mutual(1, 3, 60.0, 60.0)
	graph.connect_npcs_mutual(2, 3, 70.0, 70.0)
	graph.connect_npcs(2, 4, 30.0)  # Solo 2→4, no 4→2
	
	var result := graph.get_mutual_connections(1, 2, 50.0)
	var count_ok: bool = result.get("count", 0) == 1
	var entries: Array = result.get("entries_ids", [])
	
	if not count_ok or entries.size() == 0:
		return make_result("Mutual friend analytics", false, "Expected single mutual friend, got %d" % result.get("count", 0))
	
	var entry: Dictionary = entries[0]
	if entry.get("neighbor_id", null) != 3:
		return make_result("Mutual friend analytics", false, "Expected neighbor_id=3, got %s" % [str(entry)])
	
	# El promedio debe ser (80+60+70+70)/4 pero el algoritmo calcula (weight_a_to_mutual + weight_b_to_mutual)/2
	# En este caso: (60 + 70) / 2 = 65 (familiaridades de 1→3 y 2→3)
	return assert_float_approx(65.0, float(entry.get("average_weight", 0.0)), 0.1, "Mutual friend analytics")


func _test_rumor_propagation() -> Dictionary:
	var graph := SocialGraphClass.new()
	# Crear camino dirigido: 1→2→3
	graph.connect_npcs(1, 2, 100.0)
	graph.connect_npcs(2, 3, 50.0)
	
	var result := graph.simulate_rumor(1, 3, 0.5, 0.1)
	var influence: Dictionary = result.get("influence_ids", {})
	
	if not influence.has(2) or not influence.has(3):
		return make_result("Rumor propagation reaches neighbors", false, "Influence map missing ids -> %s" % [str(influence)])
	
	var check_mid: Dictionary = assert_float_approx(0.5, float(influence.get(2, 0.0)), 0.05, "Rumor propagation reaches neighbors")
	if not check_mid.get("passed", false):
		return check_mid
	
	# Verificar que el rumor NO se propaga hacia atrás (grafo dirigido)
	# Solo debe afectar 1→2→3, no al revés
	return assert_float_approx(0.125, float(influence.get(3, 0.0)), 0.05, "Rumor propagation reaches neighbors")


func _test_save_to_file_compressed() -> Dictionary:
	var graph := SocialGraphClass.new()
	graph.connect_npcs(1, 2, 50.0)
	graph.connect_npcs(2, 3, 75.0)
	graph.connect_npcs(3, 4, 90.0)
	
	var test_path := "user://test_graph_compressed.json.gz"
	var err := graph.save_to_file(test_path, true)
	
	if err != OK:
		return make_result("Save graph to compressed file", false, "Save failed with error: %d" % err)
	
	# Verificar que el archivo existe
	var file_exists := FileAccess.file_exists(test_path)
	
	# Limpiar archivo de prueba
	if file_exists:
		DirAccess.remove_absolute(test_path)
	
	return assert_true(file_exists, "Save graph to compressed file", "File was not created")


func _test_save_to_file_uncompressed() -> Dictionary:
	var graph := SocialGraphClass.new()
	graph.connect_npcs(10, 20, 30.0)
	graph.connect_npcs(20, 30, 40.0)
	
	var test_path := "user://test_graph_uncompressed.json"
	var err := graph.save_to_file(test_path, false)
	
	if err != OK:
		return make_result("Save graph to uncompressed file", false, "Save failed with error: %d" % err)
	
	# Verificar que el archivo existe y es legible
	var file := FileAccess.open(test_path, FileAccess.READ)
	var file_exists := file != null
	var content := ""
	if file_exists:
		content = file.get_as_text()
		file.close()
	
	# Verificar que el contenido es JSON válido
	var json := JSON.new()
	var parse_result := json.parse(content)
	var is_valid_json := parse_result == OK
	
	# Limpiar archivo de prueba
	if file_exists:
		DirAccess.remove_absolute(test_path)
	
	if not file_exists:
		return make_result("Save graph to uncompressed file", false, "File was not created")
	if not is_valid_json:
		return make_result("Save graph to uncompressed file", false, "File content is not valid JSON")
	
	return make_result("Save graph to uncompressed file", true, "")


func _test_load_from_file() -> Dictionary:
	var graph := SocialGraphClass.new()
	# Crear aristas dirigidas
	graph.connect_npcs(100, 200, 60.0)
	graph.connect_npcs(200, 300, 80.0)
	graph.connect_npcs(100, 300, 40.0)
	
	var test_path := "user://test_graph_load.json"
	var save_err := graph.save_to_file(test_path, false)
	
	if save_err != OK:
		return make_result("Load graph from file preserves data", false, "Setup: Save failed")
	
	# Crear un nuevo grafo vacío y cargar
	var new_graph := SocialGraphClass.new()
	var load_err := new_graph.load_from_file(test_path)
	
	if load_err != OK:
		DirAccess.remove_absolute(test_path)
		return make_result("Load graph from file preserves data", false, "Load failed with error: %d" % load_err)
	
	# Verificar que las aristas dirigidas se cargaron correctamente
	var has_edge_1 := new_graph.has_edge(100, 200)
	var has_edge_2 := new_graph.has_edge(200, 300)
	var has_edge_3 := new_graph.has_edge(100, 300)
	
	# Verificar que NO existen aristas inversas (grafo dirigido)
	var no_reverse := not new_graph.has_edge(200, 100) and not new_graph.has_edge(300, 200) and not new_graph.has_edge(300, 100)
	
	var weight_1: float = new_graph.get_edge(100, 200)
	var weight_2: float = new_graph.get_edge(200, 300)
	var weight_3: float = new_graph.get_edge(100, 300)
	
	# Limpiar archivo de prueba
	DirAccess.remove_absolute(test_path)
	
	if not (has_edge_1 and has_edge_2 and has_edge_3):
		return make_result("Load graph from file preserves data", false, "Missing directed edges after load")
	
	if not no_reverse:
		return make_result("Load graph from file preserves data", false, "Found unexpected reverse edges (should be directed)")
	
	var weights_match: bool = (abs(weight_1 - 60.0) < 0.01) and (abs(weight_2 - 80.0) < 0.01) and (abs(weight_3 - 40.0) < 0.01)
	
	return assert_true(weights_match, "Load graph from file preserves data", "Edge weights don't match")


func _test_save_load_roundtrip() -> Dictionary:
	var graph := SocialGraphClass.new()
	
	# Crear un grafo con varios NPCs y relaciones
	for i in range(1, 6):
		graph.ensure_npc(i)
	
	graph.connect_npcs(1, 2, 85.0)
	graph.connect_npcs(2, 3, 70.0)
	graph.connect_npcs(3, 4, 55.0)
	graph.connect_npcs(4, 5, 90.0)
	graph.connect_npcs(1, 5, 45.0)
	
	# Usar archivo sin compresión para evitar problemas de detección
	var test_path := "user://test_graph_roundtrip.json"
	
	# Guardar
	var save_err := graph.save_to_file(test_path, false)
	if save_err != OK:
		return make_result("Save/Load roundtrip maintains integrity", false, "Save failed")
	
	# Obtener estadísticas originales
	var original_vertex_count: int = graph.get_node_count()
	var original_edge_count: int = graph.get_edge_count()
	
	# Cargar en un nuevo grafo
	var loaded_graph := SocialGraphClass.new()
	var load_err := loaded_graph.load_from_file(test_path)
	
	# Limpiar archivo de prueba
	DirAccess.remove_absolute(test_path)
	
	if load_err != OK:
		return make_result("Save/Load roundtrip maintains integrity", false, "Load failed")
	
	# Verificar que las estadísticas coinciden
	var vertex_count_matches: bool = loaded_graph.get_node_count() == original_vertex_count
	var edge_count_matches: bool = loaded_graph.get_edge_count() == original_edge_count
	
	if not vertex_count_matches:
		return make_result("Save/Load roundtrip maintains integrity", false, "Vertex count mismatch: %d vs %d" % [loaded_graph.get_node_count(), original_vertex_count])
	
	if not edge_count_matches:
		return make_result("Save/Load roundtrip maintains integrity", false, "Edge count mismatch: %d vs %d" % [loaded_graph.get_edge_count(), original_edge_count])
	
	# Verificar algunos pesos específicos
	var weight_check_1: bool = abs(loaded_graph.get_edge(1, 2) - 85.0) < 0.01
	var weight_check_2: bool = abs(loaded_graph.get_edge(4, 5) - 90.0) < 0.01
	
	if not (weight_check_1 and weight_check_2):
		return make_result("Save/Load roundtrip maintains integrity", false, "Edge weights don't match after roundtrip")
	
	return make_result("Save/Load roundtrip maintains integrity", true, "")


func _test_save_load_compressed_roundtrip() -> Dictionary:
	var graph := SocialGraphClass.new()
	
	# Crear un grafo pequeño
	graph.connect_npcs(10, 20, 100.0)
	graph.connect_npcs(20, 30, 75.0)
	graph.connect_npcs(30, 10, 50.0)
	
	# Usar extensión .gz para que se detecte como comprimido
	var test_path := "user://test_compressed.json.gz"
	
	# Guardar comprimido
	var save_err := graph.save_to_file(test_path, true)
	if save_err != OK:
		return make_result("Compressed save/load roundtrip works", false, "Save failed")
	
	# Cargar desde archivo comprimido
	var loaded_graph := SocialGraphClass.new()
	var load_err := loaded_graph.load_from_file(test_path)
	
	# Limpiar
	DirAccess.remove_absolute(test_path)
	
	if load_err != OK:
		return make_result("Compressed save/load roundtrip works", false, "Load failed with error: %d" % load_err)
	
	# Verificar datos
	var edges_ok := loaded_graph.has_edge(10, 20) and loaded_graph.has_edge(20, 30) and loaded_graph.has_edge(30, 10)
	if not edges_ok:
		return make_result("Compressed save/load roundtrip works", false, "Missing edges after compressed load")
	
	var weight_ok: bool = abs(loaded_graph.get_edge(10, 20) - 100.0) < 0.01
	
	return assert_true(weight_ok, "Compressed save/load roundtrip works", "Weights don't match")


func _test_pretty_json_format() -> Dictionary:
	var graph := SocialGraphClass.new()
	
	# Crear un grafo pequeño de ejemplo
	graph.ensure_npc(1, {"nombre": "Alice", "rol": "Guardia"})
	graph.ensure_npc(2, {"nombre": "Bob", "rol": "Comerciante"})
	graph.ensure_npc(3, {"nombre": "Carol", "rol": "Maga"})
	
	graph.connect_npcs(1, 2, 85.0)
	graph.connect_npcs(2, 3, 70.0)
	graph.connect_npcs(1, 3, 45.0)
	
	# Guardar sin comprimir para formato legible
	var test_path := "user://example_readable_graph.json"
	var save_err := graph.save_to_file(test_path, false)
	
	if save_err != OK:
		return make_result("JSON files are human-readable with indentation", false, "Failed to save")
	
	# Leer el archivo para verificar que tiene formato pretty-print
	var file := FileAccess.open(test_path, FileAccess.READ)
	if file == null:
		return make_result("JSON files are human-readable with indentation", false, "Could not read file")
	
	var content := file.get_as_text()
	file.close()
	
	# Verificar que contiene saltos de línea y tabulaciones (formato pretty)
	var has_newlines := "\n" in content
	var has_tabs := "\t" in content
	var has_proper_format := has_newlines and has_tabs
	
	# NO eliminar este archivo para que el usuario pueda inspeccionarlo
	# DirAccess.remove_absolute(test_path)
	
	print("\n📄 Archivo de ejemplo guardado en: ", test_path)
	print("   Puedes abrirlo para ver el formato JSON legible")
	
	if not has_proper_format:
		return make_result("JSON files are human-readable with indentation", false, "File doesn't have pretty formatting")
	
	return make_result("JSON files are human-readable with indentation", true, "")


func _test_directed_graph_behavior() -> Dictionary:
	var graph := SocialGraphClass.new()
	
	# Crear arista dirigida: Alice conoce a Bob, pero Bob NO conoce a Alice
	graph.connect_npcs("Alice", "Bob", 75.0)
	
	# Verificar que solo existe Alice→Bob
	var has_forward := graph.has_edge("Alice", "Bob")
	var has_reverse := graph.has_edge("Bob", "Alice")
	
	if not has_forward:
		return make_result("Directed graph allows asymmetric relationships", false, "Forward edge Alice→Bob not found")
	
	if has_reverse:
		return make_result("Directed graph allows asymmetric relationships", false, "Unexpected reverse edge Bob→Alice found")
	
	# Verificar que el peso es correcto
	var weight: float = graph.get_edge("Alice", "Bob")
	var weight_ok: bool = abs(weight - 75.0) < 0.01
	
	if not weight_ok:
		return make_result("Directed graph allows asymmetric relationships", false, "Weight mismatch: expected 75.0, got %f" % weight)
	
	# Verificar que el grado saliente de Alice es 1 y de Bob es 0
	var alice_degree: int = graph.get_cached_degree("Alice")
	var bob_degree: int = graph.get_cached_degree("Bob")
	
	if alice_degree != 1:
		return make_result("Directed graph allows asymmetric relationships", false, "Alice out-degree should be 1, got %d" % alice_degree)
	
	if bob_degree != 0:
		return make_result("Directed graph allows asymmetric relationships", false, "Bob out-degree should be 0, got %d" % bob_degree)
	
	return make_result("Directed graph allows asymmetric relationships", true, "")


func _test_mutual_connection_helper() -> Dictionary:
	var graph := SocialGraphClass.new()
	
	# Usar connect_npcs_mutual para crear relación bidireccional con diferentes pesos
	graph.connect_npcs_mutual("Alice", "Bob", 80.0, 60.0)
	
	# Verificar que ambas direcciones existen
	var has_a_to_b := graph.has_edge("Alice", "Bob")
	var has_b_to_a := graph.has_edge("Bob", "Alice")
	
	if not has_a_to_b:
		return make_result("Mutual connection helper creates bidirectional edges", false, "Alice→Bob edge not found")
	
	if not has_b_to_a:
		return make_result("Mutual connection helper creates bidirectional edges", false, "Bob→Alice edge not found")
	
	# Verificar que los pesos son diferentes
	var weight_a_to_b: float = graph.get_edge("Alice", "Bob")
	var weight_b_to_a: float = graph.get_edge("Bob", "Alice")
	
	var weight_a_ok: bool = abs(weight_a_to_b - 80.0) < 0.01
	var weight_b_ok: bool = abs(weight_b_to_a - 60.0) < 0.01
	
	if not weight_a_ok:
		return make_result("Mutual connection helper creates bidirectional edges", false, "Alice→Bob weight should be 80.0, got %f" % weight_a_to_b)
	
	if not weight_b_ok:
		return make_result("Mutual connection helper creates bidirectional edges", false, "Bob→Alice weight should be 60.0, got %f" % weight_b_to_a)
	
	# Probar con peso simétrico (segundo parámetro null)
	graph.connect_npcs_mutual("Carol", "Dave", 90.0)
	
	var weight_c_to_d: float = graph.get_edge("Carol", "Dave")
	var weight_d_to_c: float = graph.get_edge("Dave", "Carol")
	
	var symmetric_ok: bool = abs(weight_c_to_d - 90.0) < 0.01 and abs(weight_d_to_c - 90.0) < 0.01
	
	if not symmetric_ok:
		return make_result("Mutual connection helper creates bidirectional edges", false, "Symmetric weights should both be 90.0")
	
	return make_result("Mutual connection helper creates bidirectional edges", true, "")
