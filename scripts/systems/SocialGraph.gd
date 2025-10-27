## Grafo social especializado para NPCs.
##
## Extiende `Graph` y añade utilidades de dominio:
## - Usa objetos `NPC` como claves de primer orden cuando es posible.
## - Atajos para registrar NPCs, conectar/desconectar por objeto o id entero cuando no exista el objeto.
## - Consultas orientadas a claves-objeto (`get_relationships_for`, top relaciones, filtros por umbral) y variantes basadas en ids.
## - Registro de interacciones con heurísticas opcionales expuestas por cada `NPC` para ajustar la afinidad.
class_name SocialGraph
extends Graph

const GraphAlgo = preload("res://scripts/utils/GraphAlgorithms.gd")

## Emitido cuando se registra una interacción y se actualiza la afinidad.
## Emite las claves tal y como se almacenan en el grafo (NPC u id).
signal interaction_registered(a_key, b_key, delta, new_weight)
## Variante opcional que emite ids enteros cuando es posible (puede emitir null si no hay npc_id).
signal interaction_registered_ids(a_id, b_id, delta, new_weight)

## Límite sugerido de relaciones simultáneas (Dunbar's number).
const DUNBAR_LIMIT := 150
const SAVE_VERSION := 2

## Tasa de decaimiento por segundo aplicada en `apply_decay`.
var decay_rate_per_second: float = 0.0

## Registro de NPCs activos mediante WeakRef: npc_id -> WeakRef(NPC).
var _npc_registry: Dictionary = {}
## Acceso rápido a vértices a partir del NPC.
var _npc_to_vertex: Dictionary = {}
## Vértices cargados desde disco pero aún sin NPC asociado: npc_id -> Vertex.
var _pending_vertices: Dictionary = {}
## NPCs con señal `tree_exiting` conectada para limpieza automática.
var _connected_npcs: Dictionary = {}


## Garantiza que un NPC quede registrado y monitorizado.
func ensure_npc(npc_or_id, meta: Dictionary = {}) -> Vertex:
	if npc_or_id == null:
		return null
	if npc_or_id is NPC:
		return _ensure_npc_object(npc_or_id, meta)
	elif typeof(npc_or_id) == TYPE_INT:
		return _ensure_npc_id(int(npc_or_id), meta)
	return super.ensure_node(npc_or_id, meta)


## Registra un NPC por objeto, enlazando WeakRef y ganchos de limpieza.
func _ensure_npc_object(npc: NPC, meta: Dictionary = {}) -> Vertex:
	if npc == null:
		return null
	var npc_id := int(npc.npc_id)
	var vertex: Vertex = get_vertex(npc)
	if vertex == null and npc_id != -1 and _pending_vertices.has(npc_id):
		vertex = _pending_vertices[npc_id]
		if super.rekey_vertex(npc_id, npc):
			_pending_vertices.erase(npc_id)
		else:
			vertex = null
	if vertex == null:
		vertex = super.ensure_node(npc, meta)
	elif meta:
		for mkey in meta:
			vertex.meta[mkey] = meta[mkey]
	if vertex:
		if npc_id != -1:
			vertex.id = npc_id
			_npc_registry[npc_id] = weakref(npc)
		if meta:
			for mkey in meta:
				vertex.meta[mkey] = meta[mkey]
		_npc_to_vertex[npc] = vertex
		_connect_lifecycle_hooks(npc)
		_enforce_dunbar_limit(vertex.key)
	return vertex


## Registra un NPC por id entero (modo persistencia/pending).
func _ensure_npc_id(npc_id: int, meta: Dictionary = {}) -> Vertex:
	var vertex: Vertex = super.ensure_node(npc_id, meta)
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
	var npc_id := vertex.id
	super.remove_node(key)
	if key is Object:
		var callable: Callable = _connected_npcs.get(key, Callable())
		if callable and (key is Node) and (key as Node).tree_exiting.is_connected(callable):
			(key as Node).tree_exiting.disconnect(callable)
		_npc_to_vertex.erase(key)
		_connected_npcs.erase(key)
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
		if entity_or_key.has_method("get"):
			var nid = entity_or_key.get("npc_id")
			if nid != null:
				return int(nid)
		if entity_or_key.has_method("get_npc_id"):
			return int(entity_or_key.get_npc_id())
	return null


## Conecta dos NPCs (o ids) con un peso.
## Argumentos:
## - `a`, `b`: Objetos NPC o ids enteros.
## - `weight`: Afinidad a asignar.
## - `meta_a`, `meta_b`: Metadata para cada nodo, si se crean.
func connect_npcs(a, b, weight := 1.0, meta_a := {}, meta_b := {}) -> void:
	if a == b:
		return
	var vertex_a: Vertex = ensure_npc(a, meta_a)
	var vertex_b: Vertex = ensure_npc(b, meta_b)
	var key_a = vertex_a.key if vertex_a else _normalize_key(a)
	var key_b = vertex_b.key if vertex_b else _normalize_key(b)
	add_connection(key_a, key_b, float(weight))
	_enforce_dunbar_limit(key_a)
	_enforce_dunbar_limit(key_b)


## Establece explícitamente la afinidad entre dos NPCs.
func set_affinity(a, b, weight: float) -> void:
	connect_npcs(a, b, weight)


## Elimina la relación (si existe) entre dos NPCs.
func break_relationship(a, b) -> void:
	var ka = _normalize_key(a)
	var kb = _normalize_key(b)
	remove_connection(ka, kb)


## Devuelve las relaciones (id -> afinidad) de un NPC.
## Si las claves vecinas no son enteras, intenta normalizarlas a `npc_id`.
func get_relationships_for(npc_or_id) -> Dictionary:
	var k = _normalize_key(npc_or_id)
	# Devuelve las claves exactamente como se almacenan en el grafo (objetos o ids).
	return get_neighbor_weights(k)


## Variante: devuelve diccionario id->afinidad cuando es posible; mantiene claves originales si no hay id.
func get_relationships_for_ids(npc_or_id) -> Dictionary:
	var k = _normalize_key(npc_or_id)
	var raw := get_neighbor_weights(k)
	var out: Dictionary = {}
	for neigh_key in raw:
		var nid = _to_id(neigh_key)
		out[nid if nid != null else neigh_key] = raw[neigh_key]
	return out


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
	var relationships: Array = []
	for neighbor_key in vertex.edges.keys():
		var edge: Edge = vertex.edges[neighbor_key]
		var weight: float = edge.weight if edge else 0.0
		relationships.append({"neighbor": neighbor_key, "weight": weight})
	relationships.sort_custom(func(a, b): return a.weight > b.weight)
	var idx := DUNBAR_LIMIT
	while idx < relationships.size():
		var info = relationships[idx]
		remove_connection(key, info.neighbor)
		idx += 1


## Devuelve los N vecinos con mayor afinidad: Array de diccionarios { key, weight }.
func get_top_relations(npc_or_id, top_n := 3) -> Array:
	var rels := get_relationships_for(npc_or_id)
	var pairs: Array = []
	for key in rels:
		pairs.append({"key": key, "weight": rels[key]})
	pairs.sort_custom(func(a, b): return a.weight > b.weight)
	return pairs.slice(0, int(top_n))


## Devuelve claves de vecinos cuya afinidad supera (>=) el umbral.
func get_friends_above(npc_or_id, threshold: float) -> Array:
	var rels := get_relationships_for(npc_or_id)
	var out: Array = []
	for id in rels:
		if float(rels[id]) >= threshold:
			out.append(id)
	return out


## Registra una interacción entre A y B y actualiza la afinidad.
## Argumentos:
## - `a`, `b`: NPCs o ids.
## - `base_delta`: Delta base a sumar.
## - `options`: { min_weight:=0.0, max_weight:=100.0, smoothing:=0.0 }
## Notas:
## - Si los NPCs implementan `_evaluate_interaction_delta(other)` se promedia su contribución.
func register_interaction(a, b, base_delta := 0.0, options: Dictionary = {}) -> void:
	if a == null or b == null:
		return
	var meta_a: Dictionary = options.get("meta_a", {})
	var meta_b: Dictionary = options.get("meta_b", {})
	var vertex_a: Vertex = ensure_npc(a, meta_a)
	var vertex_b: Vertex = ensure_npc(b, meta_b)
	var ka = vertex_a.key if vertex_a else _normalize_key(a)
	var kb = vertex_b.key if vertex_b else _normalize_key(b)
	var current := float(get_edge(ka, kb) if has_edge(ka, kb) else 0.0)
	var d_a := 0.0
	var d_b := 0.0
	if a is NPC and a.has_method("_evaluate_interaction_delta"):
		d_a = float(a._evaluate_interaction_delta(b))
	elif a is Object and a and a.has_method("_evaluate_interaction_delta"):
		d_a = float(a._evaluate_interaction_delta(b))
	if b is NPC and b.has_method("_evaluate_interaction_delta"):
		d_b = float(b._evaluate_interaction_delta(a))
	elif b is Object and b and b.has_method("_evaluate_interaction_delta"):
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
	var w = get_edge(ka, kb)
	return w != null and float(w) >= threshold


## Rompe la relación si está por debajo o igual al umbral. Devuelve true si se eliminó.
func break_if_below(a, b, threshold: float) -> bool:
	var ka = _normalize_key(a)
	var kb = _normalize_key(b)
	var w = get_edge(ka, kb)
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


## Limpia nodos cuyo objeto ya no es válido. Devuelve la cantidad eliminada.
func cleanup_invalid_nodes() -> int:
	var removed := 0
	var keys_to_remove: Array = []
	for key in vertices.keys():
		if key is Object and not is_instance_valid(key):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		if _remove_vertex_for_key(key):
			removed += 1
	var stale_ids: Array = []
	for npc_id in _npc_registry.keys():
		var ref: WeakRef = _npc_registry[npc_id]
		if ref == null or not is_instance_valid(ref.get_ref()):
			stale_ids.append(npc_id)
	for npc_id in stale_ids:
		_npc_registry.erase(npc_id)
		_pending_vertices.erase(npc_id)
	return removed


## Lista problemas de integridad en los registros de NPCs.
func validate_npc_references() -> Array[String]:
	var issues: Array[String] = []
	for key in vertices.keys():
		if key is Object and not is_instance_valid(key):
			issues.append("Dangling NPC reference for key %s" % [str(key)])
	for npc in _npc_to_vertex.keys():
		if not is_instance_valid(npc):
			issues.append("Stale NPC object with instance_id %d" % [npc.get_instance_id()])
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
func register_loaded_npc(npc: NPC, meta: Dictionary = {}) -> void:
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
func serialize() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"nodes": _serialize_nodes(),
		"edges": _serialize_edges(),
		"metadata": {
			"node_count": get_node_count(),
			"edge_count": get_edge_count(),
			"avg_affinity": GraphAlgo.average_affinity(self)
		}
	}


func _serialize_nodes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in vertices.keys():
		var vertex: Vertex = vertices[key]
		if vertex == null:
			continue
		var v_id := vertex.id
		if v_id == -1:
			var inferred = _to_id(key)
			if inferred != null:
				v_id = int(inferred)
		var entry: Dictionary = {
			"id": v_id,
			"meta": vertex.meta.duplicate(true)
		}
		entry["has_object"] = key is Object
		out.append(entry)
	return out


func _serialize_edges() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for edge_info in get_edges():
		var key_a = edge_info["source"]
		var key_b = edge_info["target"]
		var vertex_a: Vertex = get_vertex(key_a)
		var vertex_b: Vertex = get_vertex(key_b)
		if vertex_a == null or vertex_b == null:
			continue
		var id_a := vertex_a.id
		var id_b := vertex_b.id
		if id_a == -1 or id_b == -1:
			continue
		var weight: float = float(edge_info["weight"])
		out.append({
			"a": id_a,
			"b": id_b,
			"w": round(weight * 100.0) / 100.0
		})
	return out


## Reconstruye el grafo a partir de datos serializados.
func deserialize(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var payload := data
	var version := int(payload.get("version", 1))
	if version < SAVE_VERSION:
		payload = _migrate_from_v1(payload)
	var validation := validate_loaded_data(payload)
	if validation.size() > 0:
		var packed := PackedStringArray(validation)
		push_error("SocialGraph.deserialize: invalid data -> %s" % [", ".join(packed)])
		return false
	clear()
	var nodes: Array = payload.get("nodes", [])
	for node_dict in nodes:
		var npc_id := int(node_dict.get("id", -1))
		if npc_id == -1:
			continue
		var meta: Dictionary = node_dict.get("meta", {})
		var vertex := super.ensure_node(npc_id, meta)
		if vertex:
			vertex.id = npc_id
			vertex.meta["loaded_from_save"] = true
			_pending_vertices[npc_id] = vertex
	var edges: Array = payload.get("edges", [])
	for edge_dict in edges:
		var a_id := int(edge_dict.get("a", -1))
		var b_id := int(edge_dict.get("b", -1))
		var weight := float(edge_dict.get("w", 0.0))
		if a_id == -1 or b_id == -1:
			continue
		connect_npcs(a_id, b_id, weight)
	return true


## Guarda el grafo en disco en formato JSON opcionalmente comprimido.
func save_to_file(path: String, compressed := true) -> Error:
	var data := serialize()
	var json := JSON.stringify(data)
	var file: FileAccess
	if compressed:
		file = FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_GZIP)
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
	var open_error := FileAccess.get_open_error()
	if open_error != OK or file == null:
		return open_error
	file.store_string(json)
	file.close()
	return OK


## Carga el grafo desde disco, detectando automáticamente compresión.
func load_from_file(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.READ)
	var err := FileAccess.get_open_error()
	var text := ""
	if err == OK and file:
		text = file.get_as_text()
		file.close()
	else:
		file = FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_GZIP)
		err = FileAccess.get_open_error()
		if err != OK or file == null:
			return err
		text = file.get_as_text()
		file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return ERR_PARSE_ERROR
	return OK if deserialize(parsed) else ERR_INVALID_DATA


func _migrate_from_v1(data: Dictionary) -> Dictionary:
	# Placeholder para migraciones futuras.
	return data


## Verifica que la estructura cargada contenga información válida.
func validate_loaded_data(data: Dictionary) -> Array[String]:
	var issues: Array[String] = []
	var version := int(data.get("version", SAVE_VERSION))
	if version > SAVE_VERSION:
		issues.append("Unsupported save version %d" % [version])
	if not data.has("nodes") or not data.has("edges"):
		issues.append("Missing nodes or edges arrays")
	elif typeof(data["nodes"]) != TYPE_ARRAY or typeof(data["edges"]) != TYPE_ARRAY:
		issues.append("Nodes or edges are not arrays")
	else:
		var known_ids: Dictionary = {}
		for node_dict in data["nodes"]:
			if typeof(node_dict) != TYPE_DICTIONARY:
				issues.append("Node entry is not a Dictionary")
				continue
			var nid := int(node_dict.get("id", -1))
			if nid == -1:
				issues.append("Node missing id")
			else:
				known_ids[nid] = true
		for edge_dict in data["edges"]:
			if typeof(edge_dict) != TYPE_DICTIONARY:
				issues.append("Edge entry is not a Dictionary")
				continue
			var a_id := int(edge_dict.get("a", -1))
			var b_id := int(edge_dict.get("b", -1))
			var weight := float(edge_dict.get("w", 0.0))
			if a_id == -1 or b_id == -1:
				issues.append("Edge missing endpoint ids")
			elif not known_ids.has(a_id) or not known_ids.has(b_id):
				issues.append("Edge references unknown node (%d, %d)" % [a_id, b_id])
			if weight < 0.0:
				issues.append("Edge weight below zero between %d and %d" % [a_id, b_id])
	return issues


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
	npc_a.queue_free()
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
