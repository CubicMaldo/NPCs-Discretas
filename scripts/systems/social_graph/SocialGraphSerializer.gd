## Serializador para SocialGraph.
##
## Maneja la serialización/deserialización, guardado/cargado y validación de datos
## del grafo social. Separado de SocialGraph para mantener responsabilidad única.
class_name SocialGraphSerializer
extends RefCounted

const SAVE_VERSION := 2

## Referencia al grafo social que se está serializando/deserializando.
var _graph: SocialGraph


func _init(graph: SocialGraph) -> void:
	_graph = graph


## Serializa el estado completo del grafo a un diccionario.
func serialize() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"nodes": _serialize_nodes(),
		"edges": _serialize_edges(),
		"metadata": {
			"node_count": _graph.get_node_count(),
			"edge_count": _graph.get_edge_count(),
			"avg_familiarity": GraphAlgorithms.average_weight(_graph)
		}
	}


func _serialize_nodes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key in _graph.vertices.keys():
		var vertex: Vertex = _graph.vertices[key]
		if vertex == null:
			continue
		var v_id := vertex.id
		if v_id == -1:
			var inferred = _graph._to_id(key)
			if inferred != null:
				v_id = int(inferred)
		
		# Serializar metadata usando to_dict() si es VertexMeta o subclase
		var meta_dict: Dictionary = {}
		if vertex.meta != null:
			if vertex.meta.has_method("to_dict"):
				meta_dict = vertex.meta.to_dict()
			else:
				# Si es otro tipo de Resource, intentar var2str o advertir
				push_warning("Vertex metadata no tiene método to_dict(), no se serializará completamente")
		
		var entry: Dictionary = {
			"id": v_id,
			"meta": meta_dict
		}
		entry["has_object"] = typeof(key) == TYPE_OBJECT
		out.append(entry)
	return out


func _serialize_edges() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for edge_info in _graph.get_edges():
		var key_a = edge_info["source"]
		var key_b = edge_info["target"]
		var vertex_a: Vertex = _graph.get_vertex(key_a)
		var vertex_b: Vertex = _graph.get_vertex(key_b)
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
		push_error("SocialGraphSerializer.deserialize: invalid data -> %s" % [", ".join(packed)])
		return false
	_graph.clear()
	var nodes: Array = payload.get("nodes", [])
	for node_dict in nodes:
		var npc_id := int(node_dict.get("id", -1))
		if npc_id == -1:
			continue
		var meta_dict: Dictionary = node_dict.get("meta", {})
		# Crear NPCVertexMeta desde el diccionario guardado
		var npc_meta: NPCVertexMeta = NPCVertexMeta.from_dict(meta_dict)
		npc_meta.loaded_from_save = true
		var vertex := _graph.ensure_node(npc_id, npc_meta)
		if vertex:
			vertex.id = npc_id
			_graph._pending_vertices[npc_id] = vertex
	var edges: Array = payload.get("edges", [])
	for edge_dict in edges:
		var a_id := int(edge_dict.get("a", -1))
		var b_id := int(edge_dict.get("b", -1))
		var weight := float(edge_dict.get("w", 0.0))
		if a_id == -1 or b_id == -1:
			continue
		_graph.connect_npcs(a_id, b_id, weight)
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
