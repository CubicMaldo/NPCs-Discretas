class_name SocialGraphManager
extends Node

const SocialGraphClass = preload("res://scripts/systems/SocialGraph.gd")

## Grafo social interno que maneja todas las relaciones.
var social_graph: SocialGraph

## Señales espejo del grafo social para que otros sistemas se conecten aquí.
signal interaction_registered(a_key, b_key, new_familiarity)
signal interaction_registered_ids(a_id, b_id, new_familiarity)

func _ready() -> void:
	social_graph = SocialGraphClass.new()
	social_graph.interaction_registered.connect(_on_interaction_registered)
	social_graph.interaction_registered_ids.connect(_on_interaction_registered_ids)

## Asegura que un NPC (objeto o id) exista en el grafo, propagando metadata opcional.
func ensure_npc(npc_or_id, meta: Dictionary = {}) -> void:
	social_graph.ensure_npc(npc_or_id, meta)

## Registra una interacción delegando en el grafo social (objeto-first, ids opcionales).
func register_interaction(a, b, base_delta := 0.0, options: Dictionary = {}) -> void:
	social_graph.register_interaction(a, b, base_delta, options)

## Conecta dos NPCs/ids con una arista dirigida A→B.
## [br]
## IMPORTANTE: Esto crea una conexión unidireccional. Si necesitas una relación bidireccional,
## usa `add_connection_mutual()` en su lugar.
## [br]
## Parámetros:
## - a: NPC origen (objeto o id).
## - b: NPC destino (objeto o id).
## - affinity: Familiaridad/conocimiento que A tiene de B [0..100].
## - meta_a, meta_b: Metadata opcional para los nodos.
func add_connection(a, b, affinity: float, meta_a := {}, meta_b := {}) -> void:
	social_graph.connect_npcs(a, b, affinity, meta_a, meta_b)


## Conecta dos NPCs/ids con una relación bidireccional (ambos se conocen mutuamente).
## [br]
## Crea dos aristas dirigidas: A→B y B→A con los pesos especificados.
## [br]
## Parámetros:
## - a, b: NPCs (objetos o ids) a conectar.
## - affinity_a_to_b: Familiaridad que A tiene de B [0..100].
## - affinity_b_to_a: Familiaridad que B tiene de A [0..100]. Si es `null`, usa el mismo valor que A→B.
## - meta_a, meta_b: Metadata opcional para los nodos.
func add_connection_mutual(a, b, affinity_a_to_b: float, affinity_b_to_a: Variant = null, meta_a := {}, meta_b := {}) -> void:
	social_graph.connect_npcs_mutual(a, b, affinity_a_to_b, affinity_b_to_a, meta_a, meta_b)

## Elimina la arista dirigida entre dos actores si existe.
## [br]
## IMPORTANTE: En un grafo dirigido, esto solo elimina la arista en la dirección especificada (A→B).
## Para eliminar ambas direcciones en una relación bidireccional, llama al método dos veces invirtiendo los parámetros.
func remove_connection(a, b) -> void:
	social_graph.break_relationship(a, b)

## Elimina un NPC o id del grafo.
func remove_npc(npc_or_id) -> void:
	social_graph.remove_npc(npc_or_id)

## Establece explícitamente la familiaridad (peso del vínculo social) de manera dirigida.
## [br]
## IMPORTANTE: Esto crea/actualiza una arista dirigida A→B. Para relaciones bidireccionales,
## establece la familiaridad en ambas direcciones por separado.
func set_familiarity(a, b, familiarity: float) -> void:
	social_graph.set_familiarity(a, b, familiarity)

## Establece hostilidad explícitamente (arista dirigida).
## [br]
## IMPORTANTE: Esto crea/actualiza una arista dirigida A→B con el valor de hostilidad.
func set_hostility(a, b, hostility: float) -> void:
	social_graph.set_hostility(a, b, hostility)

## Comprueba si la relación está por encima de un umbral.
func has_relationship_at_least(a, b, threshold: float) -> bool:
	return social_graph.has_relationship_at_least(a, b, threshold)

## Rompe la relación si cae por debajo del umbral.
func break_if_below(a, b, threshold: float) -> bool:
	return social_graph.break_if_below(a, b, threshold)

## Obtiene la familiaridad actual que A tiene de B (o `default` si no hay arista A→B).
## [br]
## IMPORTANTE: En un grafo dirigido, esto devuelve el peso de la arista A→B únicamente.
## La arista B→A puede tener un peso diferente o no existir.
func get_familiarity(a, b, default := 0.0) -> float:
	return social_graph.get_familiarity(a, b, default)

## Devuelve relaciones (aristas salientes) usando las claves almacenadas (objetos o ids).
## [br]
## IMPORTANTE: Solo devuelve las aristas SALIENTES desde el nodo especificado.
func get_relationships_for(key) -> Dictionary:
	return social_graph.get_relationships_for(key)

## Variante que intenta mapear a ids donde sea posible (solo aristas salientes).
func get_relationships_for_ids(key) -> Dictionary:
	return social_graph.get_relationships_for_ids(key)

## Helpers de consultas sobre vecinos salientes.
func get_top_relations(key, top_n := 3) -> Array:
	return social_graph.get_top_relations(key, top_n)

func get_friends_above(key, threshold: float) -> Array:
	return social_graph.get_friends_above(key, threshold)

## Devuelve vecinos salientes en caché (solo aristas salientes del nodo).
func get_cached_neighbors(key) -> Dictionary:
	return social_graph.get_cached_neighbors(key)

func get_cached_neighbors_ids(key) -> Dictionary:
	return social_graph.get_cached_neighbors_ids(key)

## Devuelve el grado saliente del nodo (número de aristas salientes).
func get_cached_degree(key) -> int:
	return social_graph.get_cached_degree(key)

func get_cached_degree_ids(key) -> int:
	return social_graph.get_cached_degree_ids(key)

## Busca el camino dirigido más corto entre dos actores usando Dijkstra.
## [br]
## IMPORTANTE: Solo encuentra caminos que sigan las aristas en su dirección correcta (A→B).
func get_shortest_path(a, b) -> Dictionary:
	return social_graph.get_shortest_path(a, b)

## Variante robusta con Bellman-Ford (soporta pesos negativos en grafo dirigido).
func get_shortest_path_robust(a, b) -> Dictionary:
	return social_graph.get_shortest_path_robust(a, b)

## Busca el camino dirigido más fuerte (máxima confianza acumulada).
## [br]
## IMPORTANTE: Busca el mejor camino siguiendo solo aristas dirigidas desde A hasta B.
func get_strongest_path(a, b) -> Dictionary:
	return social_graph.get_strongest_path(a, b)

## Encuentra amigos mutuos (vecinos salientes que ambos actores conocen).
## [br]
## IMPORTANTE: Busca nodos que tanto A como B tienen aristas salientes hacia ellos.
func get_mutual_connections(a, b, min_weight := 0.0) -> Dictionary:
	return social_graph.get_mutual_connections(a, b, min_weight)

## Simula propagación de rumor siguiendo aristas dirigidas desde el actor semilla.
## [br]
## IMPORTANTE: El rumor solo se propaga en la dirección de las aristas (A→B).
func simulate_rumor(seed_actor, steps := 3, attenuation := 0.6, min_strength := 0.05, use_ids := true) -> Dictionary:
	return social_graph.simulate_rumor(seed_actor, steps, attenuation, min_strength, use_ids)

## Atributos por vecindad
func get_neighbor_attribute_map(key, field: String, default_value: Variant = null) -> Dictionary:
	return social_graph.get_neighbor_attribute_map(key, field, default_value)

func get_neighbor_attribute_map_ids(key, field: String, default_value: Variant = null) -> Dictionary:
	return social_graph.get_neighbor_attribute_map_ids(key, field, default_value)

## Depuración rápida (imprime estado del grafo).
func debug_dump() -> void:
	social_graph.debug_print()

## Limpia NPCs inválidos y devuelve el total removido.
func cleanup_invalid_nodes() -> int:
	return social_graph.cleanup_invalid_nodes()

## Valida referencias internas de NPCs.
func validate_npc_references() -> Array[String]:
	return social_graph.validate_npc_references()

## Aplica decaimiento temporal a las relaciones activas.
func apply_decay(delta_seconds: float) -> Dictionary:
	return social_graph.apply_decay(delta_seconds)

## Registra un NPC cargado desde disco para atar el vértice pendiente.
func register_loaded_npc(npc: NPC, meta: Dictionary = {}) -> void:
	social_graph.register_loaded_npc(npc, meta)

## Recupera un NPC por su id si sigue activo.
func get_npc_by_id(npc_id: int) -> NPC:
	return social_graph.get_npc_by_id(npc_id)

## Devuelve el vértice asociado a un NPC concreto.
func get_vertex_by_npc(npc: NPC) -> Vertex:
	return social_graph.get_vertex_by_npc(npc)

## Serializa el grafo.
func serialize_graph() -> Dictionary:
	return social_graph.serialize()

## Reconstruye el grafo desde datos serializados.
func deserialize_graph(data: Dictionary) -> bool:
	return social_graph.deserialize(data)

## Guarda en disco el grafo social.
func save_to_file(path: String, compressed := true) -> Error:
	return social_graph.save_to_file(path, compressed)

## Carga el grafo desde disco.
func load_from_file(path: String) -> Error:
	return social_graph.load_from_file(path)

## Limpia completamente el grafo social.
func clear_graph() -> void:
	social_graph.clear()

## Ejecuta las validaciones de integridad sobre el grafo.
func validate_graph() -> Dictionary:
	return social_graph.validate_graph()

## Intenta reparar inconsistencias detectadas.
func repair_graph() -> Dictionary:
	return social_graph.repair_graph()

## Ejecuta un stress test sobre un grafo temporal.
func stress_test(num_nodes: int, num_edges: int) -> Dictionary:
	return social_graph.stress_test(num_nodes, num_edges)

## Lanza pruebas rápidas para casos límite.
func test_edge_cases() -> Array[String]:
	return social_graph.test_edge_cases()

func _on_interaction_registered(a_key, b_key, _delta, new_weight) -> void:
	interaction_registered.emit(a_key, b_key, new_weight)

func _on_interaction_registered_ids(a_id, b_id, _delta, new_weight) -> void:
	interaction_registered_ids.emit(a_id, b_id, new_weight)
