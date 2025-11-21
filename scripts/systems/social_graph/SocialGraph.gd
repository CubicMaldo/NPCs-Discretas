## Grafo social especializado para NPCs.
##
## Extiende `Graph` y añade utilidades de dominio:
## - Usa objetos `NPC` como claves de primer orden cuando es posible.
## - Atajos para registrar NPCs, conectar/desconectar por objeto o id entero cuando no exista el objeto.
## - Consultas orientadas a claves-objeto (`get_relationships_for`, top relaciones, filtros por umbral) y variantes basadas en ids.
## - Registro de interacciones con heurísticas opcionales expuestas por cada `NPC` para ajustar la familiaridad.
class_name SocialGraph
extends Graph

## Emitido cuando se registra una interacción y se actualiza la familiaridad.
## Emite las claves tal y como se almacenan en el grafo (NPC u id).
signal interaction_registered(a_key, b_key, delta, new_weight)
## Variante opcional que emite ids enteros cuando es posible (puede emitir null si no hay npc_id).
signal interaction_registered_ids(a_id, b_id, delta, new_weight)

## Límite sugerido de relaciones simultáneas (Dunbar's number).
const DUNBAR_LIMIT := 150

## Tasa de decaimiento por segundo aplicada en `apply_decay`.
var decay_rate_per_second: float = 0.0

## Serializador para guardado/cargado de datos.
var _serializer: SocialGraphSerializer

## Registro de NPCs activos mediante WeakRef: npc_id -> WeakRef(NPC).
var _npc_registry: Dictionary = {}
## Acceso rápido a vértices a partir del NPC.
var _npc_to_vertex: Dictionary = {}
## Vértices cargados desde disco pero aún sin NPC asociado: npc_id -> Vertex.
var _pending_vertices: Dictionary = {}
## NPCs con señal `tree_exiting` conectada para limpieza automática.
var _connected_npcs: Dictionary = {}
## Índices cacheados para consultas rápidas.
var _adjacency_by_key: Dictionary = {}
var _adjacency_by_id: Dictionary = {}

func _init() -> void:
	_serializer = SocialGraphSerializer.new(self)


## Garantiza que un NPC quede registrado y monitorizado.
## Acepta cualquier Resource como metadata, pero por defecto usa NPCVertexMeta.
func ensure_npc(npc_or_id, meta: Resource = null) -> Vertex:
	if npc_or_id == null:
		return null
	if npc_or_id is NPC:
		return _ensure_npc_object(npc_or_id, meta)
	elif typeof(npc_or_id) == TYPE_INT:
		return _ensure_npc_id(int(npc_or_id), meta)
	return super.ensure_node(npc_or_id, meta)


## Registra un NPC por objeto, enlazando WeakRef y ganchos de limpieza.
## Acepta cualquier Resource como metadata, pero crea NPCVertexMeta por defecto si no se proporciona.
func _ensure_npc_object(npc: NPC, meta: Resource = null) -> Vertex:
	if npc == null:
		return null
	var npc_id := int(npc.npc_id)
	var vertex: Vertex = get_vertex(npc)
	
	# Si el vértice ya existe y no se proporciona metadata, no crear metadata por defecto
	# Solo crear metadata por defecto para vértices nuevos
	var npc_meta := meta
	if npc_meta == null and vertex == null:
		var default_meta := NPCVertexMeta.new()
		default_meta.id = npc_id
		if npc.name and npc.name != "":
			default_meta.display_name = npc.name
		else:
			default_meta.display_name = "NPC_%d" % npc_id
		npc_meta = default_meta
	
	if vertex == null and npc_id != -1 and _pending_vertices.has(npc_id):
		vertex = _pending_vertices[npc_id]
		if super.rekey_vertex(npc_id, npc):
			_rekey_cache_entry(npc_id, npc)
			_pending_vertices.erase(npc_id)
			if npc_meta != null:
				vertex.meta = npc_meta
		else:
			vertex = null
	
	if vertex == null:
		vertex = super.ensure_node(npc, npc_meta)
	elif npc_meta != null:
		# Solo actualizar metadata si se proporcionó explícitamente
		vertex.meta = npc_meta
	
	if vertex:
		if npc_id != -1:
			vertex.id = npc_id
			_npc_registry[npc_id] = weakref(npc)
		_npc_to_vertex[npc] = vertex
		_connect_lifecycle_hooks(npc)
		_enforce_dunbar_limit(vertex.key)
	return vertex


## Registra un NPC por id entero (modo persistencia/pending).
## Acepta cualquier Resource como metadata, pero crea NPCVertexMeta por defecto si no se proporciona.
func _ensure_npc_id(npc_id: int, meta: Resource = null) -> Vertex:
	# Si el vértice ya existe y no se proporciona metadata, no sobrescribir
	var existing_vertex = get_vertex(npc_id)
	if existing_vertex != null and meta == null:
		return existing_vertex
	
	var npc_meta := meta
	if npc_meta == null:
		var default_meta := NPCVertexMeta.new()
		default_meta.id = npc_id
		default_meta.display_name = "NPC_%d" % npc_id
		npc_meta = default_meta
	
	var vertex: Vertex = super.ensure_node(npc_id, npc_meta)
	if vertex:
		vertex.id = npc_id
		_pending_vertices[npc_id] = vertex
	return vertex


## Conecta señales para detectar cuando el NPC sea liberado.
func _connect_lifecycle_hooks(npc: NPC) -> void:
	if not is_instance_valid(npc):
		return
	if _connected_npcs.has(npc):
		return
	var wr: WeakRef = weakref(npc)
	var callable: Callable = Callable(self, "_on_npc_tree_exiting").bind(wr)
	if not npc.tree_exiting.is_connected(callable):
		npc.tree_exiting.connect(callable, Object.CONNECT_ONE_SHOT)
	_connected_npcs[npc] = callable


func _on_npc_tree_exiting(npc_ref: WeakRef) -> void:
	var npc = npc_ref.get_ref()
	if npc == null:
		cleanup_invalid_nodes()
		return
	if _connected_npcs.has(npc):
		_connected_npcs.erase(npc)
	_remove_vertex_for_key(npc)


## Elimina un vértice del grafo y limpia registros auxiliares.
func _remove_vertex_for_key(key) -> bool:
	var vertex: Vertex = get_vertex(key)
	if vertex == null:
		return false
	var neighbor_keys: Array = vertex.get_neighbor_keys()
	var npc_id := vertex.id
	super.remove_node(key)
	_purge_vertex_indices(vertex, neighbor_keys)
	if typeof(key) == TYPE_OBJECT:
		var obj = key
		var callable: Callable = _connected_npcs.get(obj, Callable())
		if callable and is_instance_valid(obj) and obj is Node:
			var node := obj as Node
			if node.tree_exiting.is_connected(callable):
				node.tree_exiting.disconnect(callable)
		_npc_to_vertex.erase(obj)
		_connected_npcs.erase(obj)
	if npc_id != -1:
		_npc_registry.erase(npc_id)
		_pending_vertices.erase(npc_id)
	return true


## Devuelve una clave normalizada a usar en el grafo, favoreciendo objetos `NPC`.
## - Si recibe un `NPC`, se usa directamente el objeto como clave.
## - Si recibe otro `Object`, también se conserva.
## - Si recibe un entero, se devuelve tal cual para compatibilidad con datos antiguos.
func _normalize_key(entity_or_id):
	if entity_or_id is NPC:
		return entity_or_id
	if entity_or_id is Object:
		return entity_or_id
	if entity_or_id is int:
		return entity_or_id
	return entity_or_id


## Intenta extraer un npc_id entero desde un objeto NPC o clave; retorna null si no aplica.
func _to_id(entity_or_key):
	if entity_or_key is int:
		return entity_or_key
	if entity_or_key is NPC:
		return int((entity_or_key as NPC).npc_id)
	if entity_or_key is Object and entity_or_key:
		if not is_instance_valid(entity_or_key):
			return null
		if entity_or_key.has_method("get"):
			var nid = entity_or_key.get("npc_id")
			if nid != null:
				return int(nid)
		if entity_or_key.has_method("get_npc_id"):
			return int(entity_or_key.get_npc_id())
	return null


## Sobrecarga add_connection para crear conexiones UNIDIRECCIONALES (dirigidas).
## A diferencia de la clase base Graph que crea conexiones bidireccionales,
## esta versión solo crea la arista A→B sin crear B→A automáticamente.
## Internamente, convierte "familiarity" a "weight" para compatibilidad.
func add_connection(a, b, familiarity: float, edge_metadata: Resource = null, _initial_flux: int = 0, _directed: bool = false) -> void:
	if a == b:
		push_error("SocialGraph.add_connection: cannot connect node to itself")
		return
	
	if familiarity < 0.0:
		push_warning("SocialGraph.add_connection: negative familiarity %f for %s->%s, removing connection" % [familiarity, a, b])
		remove_connection(a, b)
		return
	
	var existed := has_edge(a, b)
	
	# Crear SocialEdgeMeta por defecto si no se proporciona metadata
	var meta: Resource = edge_metadata
	if meta == null:
		meta = SocialEdgeMeta.new(familiarity)
	
	# Asegurar que ambos nodos existen
	ensure_node(a)
	ensure_node(b)
	
	# Crear/actualizar arista SOLO en dirección A→B (unidireccional)
	var va: Vertex = vertices[a]
	var vb: Vertex = vertices[b]
	var edge: Edge = va.edges.get(b)
	
	if edge == null:
		# Crear nueva arista unidireccional
		edge = Edge.new(va, vb, familiarity)
		edge.metadata = meta
		va.edges[b] = edge # Solo agregar en dirección A→B
		# NO agregar vb.edges[a] para mantener el grafo dirigido
		emit_signal("edge_added", a, b)
	else:
		# Actualizar arista existente
		edge.weight = familiarity
		edge.metadata = meta
	
	# Actualizar índices de cache
	if has_edge(a, b):
		var weight: float = float(get_edge_weight(a, b))
		_update_edge_indices(a, b, weight)
	elif existed:
		_remove_edge_indices(a, b)


## Elimina la conexión unidireccional A→B sin afectar B→A.
func remove_connection(a, b) -> void:
	var va: Vertex = vertices.get(a)
	if va == null:
		return
	
	var existed := has_edge(a, b)
	var edge: Edge = va.edges.get(b)
	if edge == null:
		return
	
	# Solo remover en dirección A→B (unidireccional)
	va.edges.erase(b)
	# NO remover vb.edges[a] para mantener el grafo dirigido
	
	emit_signal("edge_removed", a, b)
	
	if existed:
		_remove_edge_indices(a, b)


func _graph_key_from_input(input) -> Variant:
	if input == null:
		return null
	if input is Vertex:
		return (input as Vertex).key
	if input is NPC:
		return input
	if typeof(input) == TYPE_INT:
		if vertices.has(input):
			return input
		if _pending_vertices.has(int(input)):
			return _pending_vertices[int(input)].key
		var npc: NPC = get_npc_by_id(int(input))
		if npc != null and is_instance_valid(npc):
			return npc
		return input
	return input


func _resolve_id_for_input(input, vertex: Vertex = null):
	if vertex and vertex.id != -1:
		return vertex.id
	if typeof(input) == TYPE_INT:
		return int(input)
	if input is Vertex:
		var v: Vertex = input as Vertex
		if v.id != -1:
			return v.id
		return null
	if input is NPC:
		var npc := input as NPC
		var npc_id := int(npc.npc_id)
		if npc_id != -1:
			return npc_id
		return null
	if input is Object:
		if not is_instance_valid(input):
			return null
		var attached_vertex: Vertex = vertex
		if attached_vertex == null:
			attached_vertex = get_vertex(input)
		if attached_vertex and attached_vertex.id != -1:
			return attached_vertex.id
		var inferred = _to_id(input)
		if inferred != null and inferred != -1:
			return inferred
		return null
	return null


func _update_edge_indices(key_a, key_b, weight: float) -> void:
	if weight <= 0.0:
		_remove_edge_indices(key_a, key_b)
		return
	var vertex_a: Vertex = get_vertex(key_a)
	var vertex_b: Vertex = get_vertex(key_b)
	var actual_key_a = vertex_a.key if vertex_a else key_a
	var actual_key_b = vertex_b.key if vertex_b else key_b
	_set_cache_entry(_adjacency_by_key, actual_key_a, actual_key_b, weight)
	var id_a = _resolve_id_for_input(actual_key_a, vertex_a)
	var id_b = _resolve_id_for_input(actual_key_b, vertex_b)
	if id_a != null and id_b != null:
		_set_cache_entry(_adjacency_by_id, id_a, id_b, weight)


func _remove_edge_indices(key_a, key_b) -> void:
	var vertex_a: Vertex = get_vertex(key_a)
	var vertex_b: Vertex = get_vertex(key_b)
	var actual_key_a = vertex_a.key if vertex_a else key_a
	var actual_key_b = vertex_b.key if vertex_b else key_b
	_remove_cache_entry(_adjacency_by_key, actual_key_a, actual_key_b)
	var id_a = _resolve_id_for_input(actual_key_a, vertex_a)
	var id_b = _resolve_id_for_input(actual_key_b, vertex_b)
	if id_a != null and id_b != null:
		_remove_cache_entry(_adjacency_by_id, id_a, id_b)


func _update_bidirectional_cache(store: Dictionary, a_key, b_key, weight: float) -> void:
	if a_key == null or b_key == null:
		return
	_set_cache_entry(store, a_key, b_key, weight)
	_set_cache_entry(store, b_key, a_key, weight)


func _remove_bidirectional_cache(store: Dictionary, a_key, b_key) -> void:
	if a_key == null or b_key == null:
		return
	_remove_cache_entry(store, a_key, b_key)
	_remove_cache_entry(store, b_key, a_key)


func _set_cache_entry(store: Dictionary, entry_key, neighbor_key, weight: float) -> void:
	if entry_key == null or neighbor_key == null:
		return
	if weight <= 0.0:
		_remove_cache_entry(store, entry_key, neighbor_key)
		return
	if not store.has(entry_key):
		store[entry_key] = {}
	var bucket: Dictionary = store[entry_key]
	bucket[neighbor_key] = weight


func _remove_cache_entry(store: Dictionary, entry_key, neighbor_key) -> void:
	if not store.has(entry_key):
		return
	var bucket: Dictionary = store.get(entry_key)
	if bucket == null:
		return
	bucket.erase(neighbor_key)
	if bucket.is_empty():
		store.erase(entry_key)


func _purge_cache_for_key(store: Dictionary, key) -> void:
	if key == null or store.is_empty():
		return
	if store.has(key):
		store.erase(key)
	var keys_snapshot: Array = store.keys()
	var empty_keys: Array = []
	for bucket_key in keys_snapshot:
		var bucket: Dictionary = store.get(bucket_key)
		if bucket and bucket.erase(key):
			if bucket.is_empty():
				empty_keys.append(bucket_key)
	for bucket_key in empty_keys:
		store.erase(bucket_key)


func _purge_vertex_indices(vertex: Vertex, neighbor_keys: Array = []) -> void:
	if vertex == null:
		return
	var primary_key = vertex.key
	var vertex_id := vertex.id
	_purge_cache_for_key(_adjacency_by_key, primary_key)
	if neighbor_keys and neighbor_keys.size() > 0:
		for neighbor_key in neighbor_keys:
			_remove_cache_entry(_adjacency_by_key, neighbor_key, primary_key)
	if vertex_id != -1:
		_purge_cache_for_key(_adjacency_by_id, vertex_id)
		if neighbor_keys and neighbor_keys.size() > 0:
			for neighbor_key in neighbor_keys:
				var neighbor_vertex: Vertex = get_vertex(neighbor_key)
				var neighbor_id = _resolve_id_for_input(neighbor_key, neighbor_vertex)
				if neighbor_id != null:
					_remove_cache_entry(_adjacency_by_id, neighbor_id, vertex_id)


func _rekey_cache_entry(old_key, new_key) -> void:
	if old_key == null or new_key == null or old_key == new_key:
		return
	if _adjacency_by_key.has(old_key):
		var bucket: Dictionary = _adjacency_by_key[old_key]
		_adjacency_by_key.erase(old_key)
		_adjacency_by_key[new_key] = bucket
	var keys_snapshot: Array = _adjacency_by_key.keys()
	for entry_key in keys_snapshot:
		var bucket: Dictionary = _adjacency_by_key.get(entry_key)
		if bucket == null or not bucket.has(old_key):
			continue
		var weight = bucket[old_key]
		bucket.erase(old_key)
		bucket[new_key] = weight


## Conecta dos NPCs (o ids) con un peso (conexión unidireccional A→B).
## Argumentos:
## - `a`, `b`: Objetos NPC o ids enteros.
## - `familiarity`: Nivel de familiaridad a asignar (qué tan bien se conocen).
## - `edge_metadata`: SocialEdgeMeta opcional para la arista (o cualquier Resource compatible).
func connect_npcs(a, b, familiarity: float, edge_metadata: Resource = null) -> void:
	if a == b:
		return
	var vertex_a: Vertex = ensure_npc(a)
	var vertex_b: Vertex = ensure_npc(b)
	var key_a = vertex_a.key if vertex_a else _normalize_key(a)
	var key_b = vertex_b.key if vertex_b else _normalize_key(b)
	add_connection(key_a, key_b, float(familiarity), edge_metadata)
	_enforce_dunbar_limit(key_a)
	_enforce_dunbar_limit(key_b)


## Conecta dos NPCs con una relación bidireccional (A↔B).
## Crea ambas aristas con los pesos especificados.
## Argumentos:
## - `a`, `b`: Objetos NPC o ids enteros.
## - `familiarity_a_to_b`: Familiaridad de A hacia B (qué tan bien A conoce a B).
## - `familiarity_b_to_a`: Familiaridad de B hacia A. Si es null, usa el mismo valor que A→B.
## - `edge_metadata_a_to_b`: SocialEdgeMeta opcional para la arista A→B (o cualquier Resource).
## - `edge_metadata_b_to_a`: SocialEdgeMeta opcional para la arista B→A (o cualquier Resource).
func connect_npcs_mutual(a, b, familiarity_a_to_b: float, familiarity_b_to_a: Variant = null, edge_metadata_a_to_b: Resource = null, edge_metadata_b_to_a: Resource = null) -> void:
	if a == b:
		return
	var fam_ba: float = familiarity_b_to_a if familiarity_b_to_a != null else familiarity_a_to_b
	connect_npcs(a, b, familiarity_a_to_b, edge_metadata_a_to_b)
	connect_npcs(b, a, fam_ba, edge_metadata_b_to_a)


## Elimina la relación (si existe) entre dos NPCs.
func break_relationship(a, b) -> void:
	var ka = _normalize_key(a)
	var kb = _normalize_key(b)
	remove_connection(ka, kb)


## Devuelve las relaciones (id -> familiaridad) de un NPC.
## Si las claves vecinas no son enteras, intenta normalizarlas a `npc_id`.
func get_relationships_for(npc_or_id) -> Dictionary:
	var k = _normalize_key(npc_or_id)
	# Devuelve las claves exactamente como se almacenan en el grafo (objetos o ids).
	return get_neighbor_weights(k)


## Variante: devuelve diccionario id->familiaridad cuando es posible; mantiene claves originales si no hay id.
func get_relationships_for_ids(npc_or_id) -> Dictionary:
	var k = _normalize_key(npc_or_id)
	var raw := get_neighbor_weights(k)
	var out: Dictionary = {}
	for neigh_key in raw:
		var nid = _to_id(neigh_key)
		out[nid if nid != null else neigh_key] = raw[neigh_key]
	return out


func get_cached_neighbors(npc_or_id) -> Dictionary:
	var key = _graph_key_from_input(npc_or_id)
	if key == null:
		return {}
	var bucket = _adjacency_by_key.get(key)
	if bucket == null:
		return {}
	return bucket.duplicate(true)


func get_cached_neighbors_ids(npc_or_id) -> Dictionary:
	var key = _graph_key_from_input(npc_or_id)
	if key == null:
		return {}
	var vertex: Vertex = get_vertex(key)
	var resolved_id = _resolve_id_for_input(key, vertex)
	if resolved_id == null and typeof(npc_or_id) == TYPE_INT:
		resolved_id = int(npc_or_id)
	if resolved_id == null:
		return {}
	var bucket = _adjacency_by_id.get(resolved_id)
	if bucket == null:
		return {}
	return bucket.duplicate(true)


func get_cached_degree(npc_or_id) -> int:
	return get_cached_neighbors(npc_or_id).size()


func get_cached_degree_ids(npc_or_id) -> int:
	return get_cached_neighbors_ids(npc_or_id).size()


## Devuelve el número total de aristas dirigidas en el grafo.
## Sobrescribe el método de Graph que asume grafo no dirigido (divide por 2).
func get_edge_count() -> int:
	var count := 0
	for k in vertices:
		count += (vertices[k] as Vertex).edges.size()
	return count


func get_shortest_path(a, b) -> Dictionary:
	var key_a = _graph_key_from_input(a)
	var key_b = _graph_key_from_input(b)
	if key_a == null or key_b == null:
		return {
			"reachable": false,
			"distance": 0.0,
			"path": [],
			"path_ids": []
		}
	if not has_vertex(key_a) or not has_vertex(key_b):
		return {
			"reachable": false,
			"distance": 0.0,
			"path": [],
			"path_ids": []
		}
	var result: Dictionary = GraphAlgorithms.shortest_path(self, key_a, key_b)
	var path: Array = result.get("path", [])
	result["path_ids"] = _keys_to_ids(path)
	return result


## Busca el camino dirigido más fuerte (máxima confianza acumulada) entre dos actores.
## [br]
## IMPORTANTE: Busca el mejor camino siguiendo solo aristas dirigidas desde A hasta B.
## El resultado representa la cadena de relaciones más confiable, calculada como producto
## de pesos normalizados.
func get_strongest_path(a, b) -> Dictionary:
	var key_a = _graph_key_from_input(a)
	var key_b = _graph_key_from_input(b)
	if key_a == null or key_b == null:
		return {
			"reachable": false,
			"strength": 0.0,
			"path": [],
			"path_ids": []
		}
	if not has_vertex(key_a) or not has_vertex(key_b):
		return {
			"reachable": false,
			"strength": 0.0,
			"path": [],
			"path_ids": []
		}
	var result: Dictionary = GraphAlgorithms.strongest_path(self, key_a, key_b)
	var path: Array = result.get("path", [])
	result["path_ids"] = _keys_to_ids(path)
	return result


func get_mutual_connections(a, b, min_weight := 0.0) -> Dictionary:
	var key_a = _graph_key_from_input(a)
	var key_b = _graph_key_from_input(b)
	if key_a == null or key_b == null:
		return {
			"count": 0,
			"entries": [],
			"average_weight": 0.0,
			"jaccard_index": 0.0,
			"entries_ids": []
		}
	if not has_vertex(key_a) or not has_vertex(key_b):
		return {
			"count": 0,
			"entries": [],
			"average_weight": 0.0,
			"jaccard_index": 0.0,
			"entries_ids": []
		}
	var result: Dictionary = GraphAlgorithms.mutual_metrics(self, key_a, key_b, float(min_weight))
	var entries: Array = result.get("entries", [])
	result["entries_ids"] = _convert_entries_neighbors_to_ids(entries)
	return result


## Propaga un "rumor" desde un NPC inicial usando BFS con atenuación.
## Utiliza BFS como base y aplica atenuación por nivel y familiaridad de relaciones.
## 
## Argumentos:
## - seed_actor: NPC o id inicial del rumor
## - steps: Número máximo de "saltos" permitidos (niveles BFS)
## - attenuation: Factor de atenuación por salto (0.0-1.0, default 0.6 = 60%)
## - min_strength: Fuerza mínima para continuar propagación (default 0.05 = 5%)
## - use_ids: Si true, incluye versiones con ids en el resultado
##
## Retorna: { seed, steps, reached: Array, influence: Dictionary, reached_ids?, influence_ids?, seed_id? }
func simulate_rumor(seed_actor, steps := 3, attenuation := 0.6, min_strength := 0.05, use_ids := true) -> Dictionary:
	var seed_key = _graph_key_from_input(seed_actor)
	
	var result := {
		"seed": seed_actor,
		"steps": int(steps),
		"reached": [],
		"influence": {}
	}
	
	if use_ids:
		result["reached_ids"] = []
		result["influence_ids"] = {}
	
	if seed_key == null or not has_vertex(seed_key):
		return result
	
	# Realizar BFS para obtener estructura de niveles
	var bfs_result: Dictionary = GraphAlgorithms.bfs(self, seed_key)
	var levels: Dictionary = bfs_result.get("levels", {})
	
	# Calcular influencia usando BFS por niveles
	var influence: Dictionary = {}
	influence[seed_key] = 1.0
	
	# Procesar nodos por nivel (BFS garantiza orden)
	var visited_keys: Array = bfs_result.get("visited", [])
	
	for current in visited_keys:
		var current_level: int = int(levels.get(current, 0))
		
		# Si excedemos el número de pasos, detener
		if current_level >= int(steps):
			continue
		
		var strength: float = float(influence.get(current, 0.0))
		if strength <= 0.0:
			continue
		
		# Propagar a vecinos
		var neighbor_weights: Dictionary = get_neighbor_weights(current)
		for neighbor in neighbor_weights.keys():
			# Solo procesar vecinos en el siguiente nivel (BFS)
			var neighbor_level: int = int(levels.get(neighbor, -1))
			if neighbor_level != current_level + 1:
				continue
			
			var weight: float = float(neighbor_weights[neighbor])
			# Normalizar familiaridad (asumiendo escala 0-100)
			var normalized_weight: float = clamp(weight / 100.0, 0.0, 1.0)
			var propagated: float = strength * float(attenuation) * normalized_weight
			
			if propagated < float(min_strength):
				continue
			
			# Actualizar si la influencia es mayor
			var existing: float = float(influence.get(neighbor, 0.0))
			if propagated > existing:
				influence[neighbor] = propagated
	
	result["seed"] = seed_key
	result["influence"] = influence
	result["reached"] = influence.keys()
	
	# Agregar versiones con ids si se solicita
	if use_ids:
		result["reached_ids"] = _keys_to_ids(result["reached"])
		result["influence_ids"] = _map_influence_to_ids(influence)
		result["seed_id"] = _to_id(seed_key)
	
	return result


func _keys_to_ids(keys: Array) -> Array:
	var out: Array = []
	for key in keys:
		var mapped = _to_id(key)
		out.append(mapped if mapped != null else key)
	return out


func _convert_entries_neighbors_to_ids(entries: Array) -> Array:
	var out: Array = []
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var digest: Dictionary = entry.duplicate(true)
		var neighbor_key = entry.get("neighbor")
		var neighbor_id = _to_id(neighbor_key)
		if neighbor_id != null:
			digest["neighbor_id"] = neighbor_id
		out.append(digest)
	return out


func _map_influence_to_ids(influence: Dictionary) -> Dictionary:
	var mapped: Dictionary = {}
	for key in influence.keys():
		var nid = _to_id(key)
		mapped[nid if nid != null else key] = influence[key]
	return mapped


## Limita el número de conexiones activas según la constante `DUNBAR_LIMIT`.
func _enforce_dunbar_limit(key) -> void:
	if DUNBAR_LIMIT <= 0:
		return
	var vertex: Vertex = get_vertex(key)
	if vertex == null:
		return
	var degree := vertex.degree()
	if degree <= DUNBAR_LIMIT:
		return
	# Collect neighbor relationships with their weights
	var relationships: Array = []
	for neighbor_key in vertex.edges.keys():
		var edge: Edge = vertex.edges[neighbor_key]
		var weight: float = edge.weight if edge else 0.0
		relationships.append({"neighbor": neighbor_key, "weight": weight})

	# Sort ascending by weight so weakest relationships are first
	relationships.sort_custom(Callable(self, "_compare_weight_asc"))

	# Remove weakest edges until we're within the Dunbar limit
	var to_remove := degree - DUNBAR_LIMIT
	var idx := 0
	while idx < to_remove and idx < relationships.size():
		var info = relationships[idx]
		remove_connection(key, info.neighbor)
		idx += 1

## Devuelve los N vecinos con mayor familiaridad: Array de diccionarios { key, weight }.
func get_top_relations(npc_or_id, top_n := 3) -> Array:
	var rels := get_relationships_for(npc_or_id)
	var pairs: Array = []
	for key in rels:
		pairs.append({"key": key, "weight": rels[key]})
	pairs.sort_custom(func(a, b): return a.weight > b.weight)
	return pairs.slice(0, int(top_n))


## Comparator helper: sort relation dicts by weight ascending
func _compare_weight_asc(a, b) -> int:
	var aw := float(0.0)
	var bw := float(0.0)
	if typeof(a) == TYPE_DICTIONARY and a.has("weight"):
		aw = float(a["weight"])
	if typeof(b) == TYPE_DICTIONARY and b.has("weight"):
		bw = float(b["weight"])
	if aw < bw:
		return -1
	elif aw > bw:
		return 1
	return 0


## Devuelve claves de vecinos cuya familiaridad supera (>=) el umbral.
func get_friends_above(npc_or_id, threshold: float) -> Array:
	var rels := get_relationships_for(npc_or_id)
	var out: Array = []
	for id in rels:
		if float(rels[id]) >= threshold:
			out.append(id)
	return out


## Registra una interacción entre A y B y actualiza la familiaridad.
## Argumentos:
## - `a`, `b`: NPCs o ids.
## - `base_delta`: Delta base a sumar.
## - `options`: { min_weight:=0.0, max_weight:=100.0, smoothing:=0.0, meta_a:=Resource, meta_b:=Resource }
## Notas:
## - Si los NPCs implementan `_evaluate_interaction_delta(other)` se promedia su contribución.
func register_interaction(a, b, base_delta := 0.0, options: Dictionary = {}) -> void:
	if a == null or b == null:
		return
	var meta_a: Resource = options.get("meta_a", null)
	var meta_b: Resource = options.get("meta_b", null)
	var vertex_a: Vertex = ensure_npc(a, meta_a)
	var vertex_b: Vertex = ensure_npc(b, meta_b)
	var ka = vertex_a.key if vertex_a else _normalize_key(a)
	var kb = vertex_b.key if vertex_b else _normalize_key(b)
	var current := float(get_edge_weight(ka, kb) if has_edge(ka, kb) else 0.0)
	var d_a := 0.0
	var d_b := 0.0
	if a is NPC:
		d_a = float(a._evaluate_interaction_delta(b))
	if b is NPC:
		d_b = float(b._evaluate_interaction_delta(a))
	var eval_delta := (d_a + d_b) * 0.5
	var total_delta := float(base_delta) + eval_delta
	if total_delta == 0.0:
		total_delta = 0.1 # pequeño impulso por defecto

	var min_w := float(options.get("min_weight", 0.0))
	var max_w := float(options.get("max_weight", 100.0))
	var smoothing: float = float(clamp(float(options.get("smoothing", 0.0)), 0.0, 1.0))

	var proposed: float = float(clamp(current + total_delta, min_w, max_w))
	var new_weight: float = proposed
	if smoothing > 0.0:
		new_weight = lerp(current, proposed, smoothing)

	add_connection(ka, kb, new_weight)
	_enforce_dunbar_limit(ka)
	_enforce_dunbar_limit(kb)
	# Emitimos con claves tal cual (objetos o ids) y también con ids si están disponibles.
	interaction_registered.emit(ka, kb, total_delta, new_weight)
	interaction_registered_ids.emit(_to_id(ka), _to_id(kb), total_delta, new_weight)


## Ayuda booleana: ¿existe relación >= umbral?
func has_relationship_at_least(a, b, threshold: float) -> bool:
	var ka = _normalize_key(a)
	var kb = _normalize_key(b)
	var w = get_edge_weight(ka, kb)
	return w != null and float(w) >= threshold


## Rompe la relación si está por debajo o igual al umbral. Devuelve true si se eliminó.
func break_if_below(a, b, threshold: float) -> bool:
	var ka = _normalize_key(a)
	var kb = _normalize_key(b)
	var w = get_edge_weight(ka, kb)
	if w == null:
		return false
	if float(w) <= threshold:
		remove_connection(ka, kb)
		return true
	return false


## Elimina por completo un NPC o id del grafo.
func remove_npc(npc_or_id) -> void:
	if npc_or_id is NPC:
		_remove_vertex_for_key(npc_or_id)
	elif typeof(npc_or_id) == TYPE_INT:
		var key := int(npc_or_id)
		if vertices.has(key):
			_remove_vertex_for_key(key)
		else:
			_pending_vertices.erase(key)
			_purge_cache_for_key(_adjacency_by_id, key)


## Limpia nodos cuyo objeto ya no es válido. Devuelve la cantidad eliminada.
func cleanup_invalid_nodes() -> int:
	var removed := 0
	var keys_snapshot := vertices.keys()
	for key in keys_snapshot:
		if typeof(key) == TYPE_OBJECT:
			var obj = key
			if not is_instance_valid(obj):
				if _remove_vertex_for_key(obj):
					removed += 1
	var stale_ids: Array = []
	for npc_id in _npc_registry.keys():
		var ref: WeakRef = _npc_registry[npc_id]
		if ref == null or not is_instance_valid(ref.get_ref()):
			stale_ids.append(npc_id)
	for npc_id in stale_ids:
		_npc_registry.erase(npc_id)
		_pending_vertices.erase(npc_id)
		_purge_cache_for_key(_adjacency_by_id, npc_id)
	return removed


## Lista problemas de integridad en los registros de NPCs.
func validate_npc_references() -> Array[String]:
	var issues: Array[String] = []
	for key in vertices.keys():
		if typeof(key) == TYPE_OBJECT:
			var obj = key
			if not is_instance_valid(obj):
				issues.append("Dangling NPC reference for freed key")
	for npc in _npc_to_vertex.keys():
		if not is_instance_valid(npc):
			issues.append("Stale NPC object reference detected")
	var seen_ids: Dictionary = {}
	for npc_id in _npc_registry.keys():
		var ref: WeakRef = _npc_registry[npc_id]
		var npc = ref.get_ref() if ref else null
		if npc == null or not is_instance_valid(npc):
			issues.append("WeakRef missing NPC for id %d" % [npc_id])
		else:
			seen_ids[npc_id] = true
	for npc_id in _pending_vertices.keys():
		if seen_ids.has(npc_id):
			continue
		var vertex: Vertex = _pending_vertices[npc_id]
		if vertex == null:
			issues.append("Pending vertex missing for id %d" % [npc_id])
	return issues


## Recupera el NPC asociado a un id, si sigue válido.
func get_npc_by_id(npc_id: int) -> NPC:
	var ref: WeakRef = _npc_registry.get(npc_id)
	if ref:
		var npc = ref.get_ref()
		return npc if is_instance_valid(npc) else null
	return null


## Devuelve el vértice asociado a un objeto NPC.
func get_vertex_by_npc(npc: NPC) -> Vertex:
	return _npc_to_vertex.get(npc, null)


## Registra un NPC instanciado tras la carga de datos.
## Acepta cualquier Resource como metadata.
func register_loaded_npc(npc: NPC, meta: Resource = null) -> void:
	_ensure_npc_object(npc, meta)


## Aplica decaimiento temporal a las relaciones. Devuelve estadísticas de actualización.
func apply_decay(delta_seconds: float) -> Dictionary:
	if decay_rate_per_second <= 0.0 or delta_seconds <= 0.0:
		return {"updated": 0, "removed": 0}
	var decay_amount := decay_rate_per_second * delta_seconds
	var updated := 0
	var removed := 0
	var snapshot := get_edges()
	for entry in snapshot:
		var key_a = entry["source"]
		var key_b = entry["target"]
		var weight: float = float(entry["weight"])
		var new_weight: float = float(max(weight - decay_amount, 0.0))
		if new_weight <= 0.0:
			remove_connection(key_a, key_b)
			removed += 1
		elif !is_equal_approx(new_weight, weight):
			add_connection(key_a, key_b, new_weight)
			updated += 1
	return {"updated": updated, "removed": removed}


## Serializa el estado completo del grafo a un diccionario.
## Delega al serializador interno.
func serialize() -> Dictionary:
	return _serializer.serialize()


## Reconstruye el grafo a partir de datos serializados.
## Delega al serializador interno.
func deserialize(data: Dictionary) -> bool:
	return _serializer.deserialize(data)


## Guarda el grafo en disco en formato JSON opcionalmente comprimido.
## Delega al serializador interno.
func save_to_file(path: String, compressed := true) -> Error:
	return _serializer.save_to_file(path, compressed)


## Carga el grafo desde disco, detectando automáticamente compresión.
## Delega al serializador interno.
func load_from_file(path: String) -> Error:
	return _serializer.load_from_file(path)


## Verifica que la estructura cargada contenga información válida.
## Delega al serializador interno.
func validate_loaded_data(data: Dictionary) -> Array[String]:
	return _serializer.validate_loaded_data(data)


## Ejecuta validaciones de integridad sobre el grafo actual.
func validate_graph() -> Dictionary:
	var dangling := _check_dangling_references()
	var asym := _check_edge_symmetry()
	var npc_issues := _check_npc_validity()
	var weight_issues := _check_weight_ranges()
	var errors: Array[String] = []
	errors.append_array(dangling)
	errors.append_array(weight_issues)
	errors.append_array(asym)
	var warnings: Array[String] = []
	warnings.append_array(npc_issues)
	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"stats": {
			"dangling_refs": dangling.size(),
			"asymmetric_edges": asym.size(),
			"invalid_weights": weight_issues.size(),
			"invalid_npcs": npc_issues.size()
		}
	}


func _check_dangling_references() -> Array[String]:
	var issues: Array[String] = []
	for edge_info in get_edges():
		var key_a = edge_info["source"]
		var key_b = edge_info["target"]
		if get_vertex(key_a) == null or get_vertex(key_b) == null:
			issues.append("Dangling edge detected between %s and %s" % [str(key_a), str(key_b)])
	return issues


func _check_edge_symmetry() -> Array[String]:
	var issues: Array[String] = []
	for key in vertices.keys():
		var vertex: Vertex = vertices[key]
		for neighbor_key in vertex.edges.keys():
			var neighbor_vertex: Vertex = vertices.get(neighbor_key)
			if neighbor_vertex == null or not neighbor_vertex.edges.has(key):
				issues.append("Asymmetry between %s and %s" % [str(key), str(neighbor_key)])
	return issues


func _check_npc_validity() -> Array[String]:
	return validate_npc_references()


func _check_weight_ranges() -> Array[String]:
	var issues: Array[String] = []
	for edge_info in get_edges():
		var weight: float = float(edge_info.get("weight", 0.0))
		if weight < 0.0:
			var key_a = edge_info["source"]
			var key_b = edge_info["target"]
			issues.append("Negative weight %f between %s and %s" % [weight, str(key_a), str(key_b)])
	return issues


## Intenta reparar problemas comunes y devuelve un informe detallado.
func repair_graph() -> Dictionary:
	var report := {
		"actions_taken": [],
		"errors_fixed": 0,
		"nodes_removed": 0,
		"edges_fixed": 0
	}
	var removed_nodes := cleanup_invalid_nodes()
	if removed_nodes > 0:
		report["actions_taken"].append("Removed %d invalid NPC nodes" % [removed_nodes])
	report["nodes_removed"] = removed_nodes
	var edges_fixed := 0
	var asymmetry_fixed := 0
	var snapshot := get_edges()
	for edge_info in snapshot:
		var key_a = edge_info["source"]
		var key_b = edge_info["target"]
		if get_vertex(key_a) == null or get_vertex(key_b) == null:
			remove_connection(key_a, key_b)
			edges_fixed += 1
			continue
		var weight: float = float(edge_info.get("weight", 0.0))
		if weight < 0.0:
			remove_connection(key_a, key_b)
			edges_fixed += 1
	for key in vertices.keys():
		var vertex: Vertex = vertices[key]
		for neighbor_key in vertex.edges.keys():
			var neighbor_vertex: Vertex = vertices.get(neighbor_key)
			if neighbor_vertex == null:
				continue
			if not neighbor_vertex.edges.has(key):
				var edge: Edge = vertex.edges[neighbor_key]
				add_connection(key, neighbor_key, edge.weight)
				asymmetry_fixed += 1
	if edges_fixed > 0:
		report["actions_taken"].append("Removed %d inconsistent edges" % [edges_fixed])
	if asymmetry_fixed > 0:
		report["actions_taken"].append("Restored symmetry on %d edges" % [asymmetry_fixed])
	report["edges_fixed"] = edges_fixed + asymmetry_fixed
	report["errors_fixed"] = removed_nodes + report["edges_fixed"]
	return report


## Genera un grafo aleatorio y devuelve estadísticas de rendimiento básicas.
func stress_test(num_nodes: int, num_edges: int) -> Dictionary:
	var test_graph := SocialGraph.new()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var start := Time.get_ticks_usec()
	for i in range(num_nodes):
		test_graph.ensure_npc(i)
	var created := 0
	if num_nodes > 1:
		while created < num_edges:
			var a := rng.randi_range(0, num_nodes - 1)
			var b := rng.randi_range(0, num_nodes - 1)
			if a == b:
				continue
			var weight := rng.randf_range(0.0, 100.0)
			test_graph.connect_npcs(a, b, weight)
			created += 1
	var duration_ms := (Time.get_ticks_usec() - start) / 1000.0
	var validation := test_graph.validate_graph()
	return {
		"duration_ms": duration_ms,
		"nodes": test_graph.get_node_count(),
		"edges": test_graph.get_edge_count(),
		"validation": validation
	}


## Ejecuta comprobaciones rápidas para escenarios límite y devuelve resultados descriptivos.
func test_edge_cases() -> Array[String]:
	var results: Array[String] = []
	var temp := SocialGraph.new()
	temp.ensure_npc(1)
	temp.ensure_npc(2)
	temp.connect_npcs(1, 2, 10.0)
	temp.break_relationship(1, 2)
	results.append("Break relationship removes edge: %s" % ["PASS" if not temp.has_edge(1, 2) else "FAIL"])
	var npc_a := NPC.new()
	npc_a.npc_id = 10
	temp.ensure_npc(npc_a)
	results.append("Ensure_npc handles object keys: %s" % ["PASS" if temp.has_vertex(npc_a) else "FAIL"])
	temp.remove_npc(npc_a)
	npc_a.free()
	temp.decay_rate_per_second = 5.0
	temp.connect_npcs(20, 21, 2.5)
	temp.apply_decay(1.0)
	results.append("Decay stops at zero: %s" % ["PASS" if not temp.has_edge(20, 21) else "FAIL"])
	return results


## Reemplaza y limpia toda la estructura interna.
func clear() -> void:
	super.clear()
	for npc in _connected_npcs.keys():
		var callable: Callable = _connected_npcs[npc]
		if is_instance_valid(npc) and (npc is Node) and (npc as Node).tree_exiting.is_connected(callable):
			(npc as Node).tree_exiting.disconnect(callable)
	_npc_registry.clear()
	_npc_to_vertex.clear()
	_pending_vertices.clear()
	_connected_npcs.clear()
	_adjacency_by_key.clear()
	_adjacency_by_id.clear()
