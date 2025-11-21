## GraphBuilder: Nodo para construir grafos desde el Inspector de Godot
## Permite al diseñador crear la estructura del grafo visualmente sin código
@tool
class_name GraphBuilder
extends Node

## Lista de nodos del grafo (se puede editar en el Inspector)
@export var nodes: Array[GraphNodeData] = []

## Lista de conexiones entre nodos
@export var connections: Array[GraphConnectionData] = []

## Si está activo, ignora las conexiones configuradas y genera aristas aleatorias
@export var use_random_connections: bool = false

## Si está activo, asigna pesos aleatorios a las aristas (tanto configuradas como aleatorias)
@export var randomize_edge_weights: bool = false

## Límite para la cantidad de aristas aleatorias y el rango máximo de pesos aleatorios
@export_range(0, 128, 1, "or_greater") var random_generation_limit: int = 5

## Grafo construido (solo lectura, generado automáticamente)
var graph: Graph = null
var _rng := RandomNumberGenerator.new()

## Señal emitida cuando el grafo es reconstruido
signal graph_built(graph: Graph)


func _ready() -> void:
	_rng.randomize()
	if not Engine.is_editor_hint():
		# En runtime, construir el grafo automáticamente
		build_graph()


## Construye el grafo a partir de los datos configurados en el Inspector
func build_graph() -> Graph:
	graph = Graph.new()
	
	# Agregar todos los nodos con su metadata
	for node_data in nodes:
		if node_data and node_data.node_key != "":
			var meta = node_data.get_metadata()
			graph.add_node(node_data.node_key, meta)
	
	var weight_limit: int = max(1, random_generation_limit)
	if use_random_connections:
		_build_random_connections(weight_limit)
	else:
		_build_configured_connections(weight_limit)
	
	graph_built.emit(graph)
	return graph


func _build_configured_connections(weight_limit: int) -> void:
	for conn in connections:
		if conn == null or conn.from_node == "" or conn.to_node == "":
			continue
		if not conn.directed:
			push_warning("GraphBuilder: Non-directed connection %s -> %s detected; graph operates in directed mode." % [conn.from_node, conn.to_node])
		var edge_meta = conn.get_edge_metadata()
		var weight = _pick_weight(conn.weight, weight_limit)
		graph.connect_vertices(conn.from_node, conn.to_node, weight, null, null, edge_meta, conn.flux, conn.directed)


func _build_random_connections(weight_limit: int) -> void:
	var node_keys: Array = graph.get_nodes().keys()
	if node_keys.size() < 2:
		return
	var possible_pairs: Array = []
	for i in range(node_keys.size()):
		for j in range(i + 1, node_keys.size()):
			possible_pairs.append([node_keys[i], node_keys[j]])
	possible_pairs.shuffle()
	var edge_cap: int = max(0, random_generation_limit)
	var edges_to_create: int = min(edge_cap, possible_pairs.size())
	for idx in range(edges_to_create):
		var pair = possible_pairs[idx]
		var from_key = pair[0]
		var to_key = pair[1]
		if _rng.randi_range(0, 1) == 0:
			var temp = from_key
			from_key = to_key
			to_key = temp
		var weight = _pick_weight(1.0, weight_limit)
		graph.connect_vertices(from_key, to_key, weight, null, null, null, 0, true)


func _pick_weight(original_weight: float, weight_limit: int) -> float:
	if not randomize_edge_weights:
		return original_weight
	return _rng.randf_range(1.0, float(max(1, weight_limit)))


## Obtiene el grafo construido (construye si es necesario)
func get_graph() -> Graph:
	if graph == null:
		build_graph()
	return graph


## Reconstruye el grafo (útil para hot-reload en el editor)
func rebuild() -> void:
	build_graph()


## Valida que el grafo esté correctamente configurado
func validate() -> Dictionary:
	var result = {
		"valid": true,
		"errors": [],
		"warnings": []
	}
	
	# Verificar nodos duplicados
	var seen_keys = {}
	for node_data in nodes:
		if node_data and node_data.node_key != "":
			if seen_keys.has(node_data.node_key):
				result.valid = false
				result.errors.append("Nodo duplicado: '%s'" % node_data.node_key)
			else:
				seen_keys[node_data.node_key] = true
	
	# Verificar conexiones válidas
	for conn in connections:
		if conn:
			if conn.from_node == "":
				result.errors.append("Conexión con from_node vacío")
				result.valid = false
			elif not seen_keys.has(conn.from_node):
				result.warnings.append("Conexión desde nodo inexistente: '%s'" % conn.from_node)
			
			if conn.to_node == "":
				result.errors.append("Conexión con to_node vacío")
				result.valid = false
			elif not seen_keys.has(conn.to_node):
				result.warnings.append("Conexión hacia nodo inexistente: '%s'" % conn.to_node)
	
	if nodes.size() == 0:
		result.warnings.append("El grafo no tiene nodos")
	
	if connections.size() == 0:
		result.warnings.append("El grafo no tiene conexiones")
	
	return result


## Imprime un resumen del grafo en consola (para debugging)
func debug_print() -> void:
	print("\n=== GraphBuilder Debug ===")
	print("Nodos: %d" % nodes.size())
	for node_data in nodes:
		if node_data:
			print("  - %s (%s)" % [node_data.node_key, node_data.display_name])
	
	print("Conexiones: %d" % connections.size())
	for conn in connections:
		if conn:
			print("  - %s -> %s (weight: %.1f)" % [conn.from_node, conn.to_node, conn.weight])
	
	var validation = validate()
	if not validation.valid:
		print("ERRORES:")
		for err in validation.errors:
			print("  ❌ %s" % err)
	
	if validation.warnings.size() > 0:
		print("ADVERTENCIAS:")
		for warn in validation.warnings:
			print("  ⚠️  %s" % warn)
	
	print("========================\n")
