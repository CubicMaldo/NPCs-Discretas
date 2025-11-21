class_name GraphAlgorithms
const INF := 1.0e18

## Utilidades sobre grafos: medidas y algoritmos (Dijkstra, BFS, DFS, MST, MaxFlow)
static func average_weight(graph: Graph) -> float:
	if graph == null:
		return 0.0
	var total_weight: float = 0.0
	var edge_count: int = 0
	for edge_info in graph.get_edges():
		total_weight += float(edge_info.get("weight", 0.0))
		edge_count += 1
	if edge_count == 0:
		return 0.0
	return total_weight / float(edge_count)


static func shortest_path(graph: Graph, source, target) -> Dictionary:
	var result := {
		"reachable": false,
		"distance": 0.0,
		"path": []
	}
	if graph == null or source == null or target == null:
		return result
	if source == target:
		if graph.has_vertex(source):
			result["reachable"] = true
			result["path"] = [source]
			result["distance"] = 0.0
		return result
	if not graph.has_vertex(source) or not graph.has_vertex(target):
		return result
	var dist: Dictionary = {}
	var previous: Dictionary = {}
	var pending: Array = [source]
	dist[source] = 0.0
	var visited: Dictionary = {}
	while not pending.is_empty():
		var current = _pop_lowest(pending, dist)
		if visited.has(current):
			continue
		visited[current] = true
		if current == target:
			break
		var neighbor_weights: Dictionary = graph.get_neighbor_weights(current)
		for neighbor in neighbor_weights.keys():
			if visited.has(neighbor):
				continue
			var weight: float = float(neighbor_weights[neighbor])
			if weight < 0.0:
				continue
			var current_dist: float = float(dist.get(current, INF))
			var candidate: float = current_dist + weight
			var existing: float = float(dist.get(neighbor, INF))
			if candidate < existing:
				dist[neighbor] = candidate
				previous[neighbor] = current
				if not pending.has(neighbor):
					pending.append(neighbor)
	if not dist.has(target):
		return result
	var path: Array = []
	var cursor = target
	while true:
		path.insert(0, cursor)
		if cursor == source:
			break
		cursor = previous.get(cursor, null)
		if cursor == null:
			path.clear()
			return result
	result["reachable"] = true
	result["distance"] = float(dist.get(target, 0.0))
	result["path"] = path
	return result


## Encuentra el camino "más fuerte" entre dos nodos en un grafo dirigido.
## En lugar de buscar el camino de menor costo (suma), busca el de mayor confianza (producto).
## Útil para encontrar la cadena de relaciones más confiable entre NPCs.
##
## Algoritmo: Dijkstra modificado maximizando producto de pesos en lugar de minimizar suma.
## Asume que los pesos representan confianza/familiaridad en escala [0-100].
##
## Retorna:
## - reachable: bool - Si existe camino de source a target
## - strength: float - Fuerza acumulada del camino (producto de pesos normalizados)
## - path: Array - Secuencia de nodos desde source hasta target
static func strongest_path(graph: Graph, source, target) -> Dictionary:
	var result := {
		"reachable": false,
		"strength": 0.0,
		"path": []
	}
	
	if graph == null or source == null or target == null:
		return result
	
	if source == target:
		if graph.has_vertex(source):
			result["reachable"] = true
			result["path"] = [source]
			result["strength"] = 1.0 # Producto neutro
		return result
	
	if not graph.has_vertex(source) or not graph.has_vertex(target):
		return result
	
	# Para maximizar producto, trabajamos con logaritmos (max producto = max suma de logs)
	# strength[node] = producto acumulado de pesos normalizados
	var strength: Dictionary = {}
	var previous: Dictionary = {}
	var pending: Array = [source]
	strength[source] = 1.0 # Producto neutro
	var visited: Dictionary = {}
	
	while not pending.is_empty():
		var current = _pop_highest(pending, strength)
		
		if visited.has(current):
			continue
		visited[current] = true
		
		if current == target:
			break
		
		var neighbor_weights: Dictionary = graph.get_neighbor_weights(current)
		for neighbor in neighbor_weights.keys():
			if visited.has(neighbor):
				continue
			
			var weight: float = float(neighbor_weights[neighbor])
			
			# Normalizar peso [0-100] a [0-1]
			var normalized_weight: float = clamp(weight / 100.0, 0.0, 1.0)
			
			# Manejar peso 0 (sin confianza) - no propagar
			if normalized_weight <= 0.0:
				continue
			
			var current_strength: float = float(strength.get(current, 0.0))
			var candidate: float = current_strength * normalized_weight
			var existing: float = float(strength.get(neighbor, 0.0))
			
			# Maximizar en lugar de minimizar
			if candidate > existing:
				strength[neighbor] = candidate
				previous[neighbor] = current
				if not pending.has(neighbor):
					pending.append(neighbor)
	
	# Si no alcanzamos el target
	if not strength.has(target) or strength[target] <= 0.0:
		return result
	
	# Reconstruir camino
	var path: Array = []
	var cursor = target
	while true:
		path.insert(0, cursor)
		if cursor == source:
			break
		cursor = previous.get(cursor, null)
		if cursor == null:
			path.clear()
			return result
	
	result["reachable"] = true
	result["strength"] = float(strength.get(target, 0.0))
	result["path"] = path
	return result


## Helper para _pop_highest: extrae el nodo con mayor strength de la cola.
static func _pop_highest(queue: Array, strengths: Dictionary):
	var best_index := 0
	var best_key = queue[0]
	var best_strength: float = float(strengths.get(best_key, 0.0))
	
	for i in range(1, queue.size()):
		var candidate = queue[i]
		var candidate_strength: float = float(strengths.get(candidate, 0.0))
		if candidate_strength > best_strength:
			best_strength = candidate_strength
			best_key = candidate
			best_index = i
	
	queue.remove_at(best_index)
	return best_key


static func mutual_metrics(graph: Graph, a, b, min_weight: float = 0.0) -> Dictionary:
	var result := {
		"count": 0,
		"entries": [],
		"average_weight": 0.0,
		"jaccard_index": 0.0
	}
	if graph == null or a == null or b == null:
		return result
	var weights_a: Dictionary = graph.get_neighbor_weights(a)
	var weights_b: Dictionary = graph.get_neighbor_weights(b)
	var entries: Array = []
	var total_avg: float = 0.0
	for neighbor in weights_a.keys():
		if neighbor == a or neighbor == b:
			continue
		if not weights_b.has(neighbor):
			continue
		var weight_a: float = float(weights_a[neighbor])
		var weight_b: float = float(weights_b[neighbor])
		if weight_a < min_weight or weight_b < min_weight:
			continue
		var avg_weight: float = (weight_a + weight_b) * 0.5
		total_avg += avg_weight
		entries.append({
			"neighbor": neighbor,
			"weight_a": weight_a,
			"weight_b": weight_b,
			"average_weight": avg_weight
		})
	var count := entries.size()
	result["entries"] = entries
	result["count"] = count
	result["average_weight"] = total_avg / float(count) if count > 0 else 0.0
	result["jaccard_index"] = _jaccard_index(weights_a.keys(), weights_b.keys())
	return result


## Realiza un recorrido BFS (Breadth-First Search) desde un nodo inicial.
## Por defecto respeta la dirección de las aristas; pasa `respect_direction=false`  envisolo si el grafo fuera no dirigido.
## Retorna un diccionario con información del recorrido:
## - visited: Array de claves visitadas en orden BFS
## - levels: Dictionary { clave: nivel } indicando la distancia desde el origen
## - parent: Dictionary { clave: padre } para reconstruir caminos
static func bfs(graph: Graph, start_key, respect_direction: bool = true) -> Dictionary:
	var result := {
		"visited": [],
		"levels": {},
		"parent": {}
	}
	
	if graph == null or start_key == null or not graph.has_vertex(start_key):
		return result
	
	var queue: Array = [start_key]
	var visited: Dictionary = {start_key: true}
	
	result["levels"][start_key] = 0
	
	while not queue.is_empty():
		var current = queue.pop_front()
		result["visited"].append(current)
		
		var current_level: int = result["levels"][current]
		var neighbor_weights: Dictionary
		if respect_direction:
			neighbor_weights = graph.get_outgoing_neighbor_weights(current)
		else:
			neighbor_weights = graph.get_neighbor_weights(current)
		
		for neighbor in neighbor_weights.keys():
			if visited.has(neighbor):
				continue
			
			visited[neighbor] = true
			result["levels"][neighbor] = current_level + 1
			result["parent"][neighbor] = current
			queue.append(neighbor)
	
	return result


## Realiza un recorrido DFS (Depth-First Search) iterativo desde un nodo inicial.
## Por defecto respeta la dirección de las aristas; establece `respect_direction=false` únicamente para grafos no dirigidos.
## Retorna un diccionario con información del recorrido similar a BFS:
## - visited: Array con el orden de visitas (preorder)
## - levels: Dictionary { clave: nivel }
## - parent: Dictionary { clave: padre }
static func dfs(graph: Graph, start_key, respect_direction: bool = true) -> Dictionary:
	var result := {
		"visited": [],
		"levels": {},
		"parent": {}
	}

	if graph == null or start_key == null or not graph.has_vertex(start_key):
		return result

	var stack: Array = [start_key]
	var visited: Dictionary = {}
	
	result["levels"][start_key] = 0

	while not stack.is_empty():
		var current = stack.pop_back()
		
		if visited.has(current):
			continue
		
		visited[current] = true
		result["visited"].append(current)
		
		var current_level: int = result["levels"][current]
		var neighbor_weights: Dictionary
		if respect_direction:
			neighbor_weights = graph.get_outgoing_neighbor_weights(current)
		else:
			neighbor_weights = graph.get_neighbor_weights(current)
		
		# Convertir a array y procesar en orden inverso para mantener
		# el orden de exploración consistente con DFS recursivo
		var neighbors: Array = neighbor_weights.keys()
		for i in range(neighbors.size() - 1, -1, -1):
			var neighbor = neighbors[i]
			if visited.has(neighbor):
				continue
			
			# Solo establecer nivel y padre si aún no se han establecido
			if not result["levels"].has(neighbor):
				result["levels"][neighbor] = current_level + 1
				result["parent"][neighbor] = current
				stack.append(neighbor)
	
	return result


static func minimum_spanning_tree(graph: Graph, method: String = "kruskal", start_key = null) -> Dictionary:
	var result := {
		"edges": [],
		"cost": 0.0,
		"components": 0
	}
	if graph == null:
		return result
	var nodes_dict: Dictionary = graph.get_nodes()
	var node_keys: Array = nodes_dict.keys()
	if node_keys.is_empty():
		return result
	var normalized_method = method.to_lower()
	if normalized_method == "prim":
		return _mst_prim(graph, start_key)
	return _mst_kruskal(graph)


static func _mst_kruskal(graph: Graph) -> Dictionary:
	var nodes_dict: Dictionary = graph.get_nodes()
	var parent := {}
	var rank := {}
	for key in nodes_dict.keys():
		parent[key] = key
		rank[key] = 0
	var edges: Array = graph.get_edges()
	var compare = func(a, b):
		return float(a.get("weight", 0.0)) < float(b.get("weight", 0.0))
	edges.sort_custom(compare)
	var mst_edges: Array = []
	var total_cost := 0.0
	var components := nodes_dict.size()
	for edge in edges:
		var a = edge.get("source")
		var b = edge.get("target")
		if a == null or b == null:
			continue
		var set_a = _find_set(a, parent)
		var set_b = _find_set(b, parent)
		if set_a == set_b:
			continue
		mst_edges.append(edge)
		total_cost += float(edge.get("weight", 0.0))
		_union_sets(set_a, set_b, parent, rank)
		components -= 1
	var result := {
		"edges": mst_edges,
		"cost": total_cost,
		"components": max(components, 0)
	}
	return result


static func _mst_prim(graph: Graph, start_key) -> Dictionary:
	var nodes_dict: Dictionary = graph.get_nodes()
	var node_keys: Array = nodes_dict.keys()
	if node_keys.is_empty():
		return {"edges": [], "cost": 0.0, "components": 0}
	var visited := {}
	var pending_edges: Array = []
	var mst_edges: Array = []
	var total_cost := 0.0
	var components := 0
	var compare = func(a, b):
		return float(a.get("weight", 0.0)) < float(b.get("weight", 0.0))

	var enqueue_edges = func(from_key):
		if from_key == null:
			return
		var neighbor_weights: Dictionary = graph.get_neighbor_weights(from_key)
		for neighbor in neighbor_weights.keys():
			if visited.has(neighbor):
				continue
			pending_edges.append({
				"source": from_key,
				"target": neighbor,
				"weight": float(neighbor_weights[neighbor])
			})
		pending_edges.sort_custom(compare)

	var initial_start = start_key if start_key != null and graph.has_vertex(start_key) else null
	var node_queue: Array = node_keys.duplicate()
	while visited.size() < node_keys.size():
		var current_start = initial_start
		initial_start = null
		if current_start == null or visited.has(current_start):
			current_start = _next_unvisited(node_queue, visited)
		if current_start == null:
			break
		if visited.has(current_start):
			continue
		components += 1
		visited[current_start] = true
		enqueue_edges.call(current_start)
		while not pending_edges.is_empty():
			var edge = pending_edges.pop_front()
			var a = edge.get("source")
			var b = edge.get("target")
			var a_visited = visited.has(a)
			var b_visited = visited.has(b)
			if a_visited and b_visited:
				continue
			var next_node = b if not b_visited else a
			mst_edges.append(edge)
			total_cost += float(edge.get("weight", 0.0))
			visited[next_node] = true
			enqueue_edges.call(next_node)
		# Cuando no queden aristas, el bucle principal buscará un nuevo componente
	return {
		"edges": mst_edges,
		"cost": total_cost,
		"components": components
	}


static func _next_unvisited(nodes: Array, visited: Dictionary):
	for key in nodes:
		if not visited.has(key):
			return key
	return null


static func _find_set(key, parent: Dictionary):
	var root = key
	while parent.get(root, root) != root:
		root = parent[root]
	var current = key
	while parent.get(current, current) != root:
		var next_key = parent[current]
		parent[current] = root
		current = next_key
	return root


static func _union_sets(a, b, parent: Dictionary, rank: Dictionary) -> void:
	var root_a = _find_set(a, parent)
	var root_b = _find_set(b, parent)
	if root_a == root_b:
		return
	var rank_a: int = rank.get(root_a, 0)
	var rank_b: int = rank.get(root_b, 0)
	if rank_a < rank_b:
		parent[root_a] = root_b
	elif rank_b < rank_a:
		parent[root_b] = root_a
	else:
		parent[root_b] = root_a
		rank[root_a] = rank_a + 1


static func _pop_lowest(queue: Array, distances: Dictionary):
	var best_index := 0
	var best_key = queue[0]
	var best_distance: float = float(distances.get(best_key, INF))
	for i in range(1, queue.size()):
		var candidate = queue[i]
		var candidate_distance: float = float(distances.get(candidate, INF))
		if candidate_distance < best_distance:
			best_distance = candidate_distance
			best_key = candidate
			best_index = i
	queue.remove_at(best_index)
	return best_key


static func _jaccard_index(keys_a: Array, keys_b: Array) -> float:
	if keys_a.is_empty() and keys_b.is_empty():
		return 0.0
	var set_a: Dictionary = {}
	for key in keys_a:
		set_a[key] = true
	var union_map: Dictionary = set_a.duplicate(true)
	var intersection := 0
	for key in keys_b:
		if set_a.has(key):
			intersection += 1
		union_map[key] = true
	var union_size := float(union_map.size())
	if union_size <= 0.0:
		return 0.0
	return float(intersection) / union_size


# ============================================================================
# ALGORITMOS DE FLUJO MÁXIMO (MAXIMUM FLOW)
# ============================================================================

## Calcula el flujo máximo entre dos nodos usando el algoritmo de Edmonds-Karp (BFS).
## Este algoritmo modifica el grafo, estableciendo el flujo en cada arista.
##
## Retorna un diccionario con:
## - max_flow: int - El flujo máximo alcanzado
## - flow_paths: Array - Caminos aumentantes encontrados
## - saturated_edges: Array - Aristas saturadas (flux == capacity)
##
## Argumentos:
## - graph: El grafo (se modificarán los valores de flux en las aristas)
## - source: Nodo fuente
## - sink: Nodo sumidero
## - reset_flux: Si true, resetea todos los flujos antes de calcular (por defecto true)
static func max_flow_edmonds_karp(graph: Graph, source, sink, reset_flux: bool = true) -> Dictionary:
	if graph == null or source == null or sink == null:
		return {"max_flow": 0, "flow_paths": [], "saturated_edges": []}
	if not graph.has_vertex(source) or not graph.has_vertex(sink):
		return {"max_flow": 0, "flow_paths": [], "saturated_edges": []}
	if source == sink:
		return {"max_flow": 0, "flow_paths": [], "saturated_edges": []}
	if reset_flux:
		graph.reset_all_flux()
	var max_flow := 0
	var augmentations: Array = []
	while true:
		var path_info = _find_augmenting_path_bfs(graph, source, sink)
		var path: Array = path_info.get("path", [])
		if path.is_empty():
			break
		var bottleneck_value: int = int(round(path_info.get("bottleneck", 0)))
		if bottleneck_value <= 0:
			break
		for i in range(path.size() - 1):
			var u = path[i]
			var v = path[i + 1]
			graph.add_edge_flux(u, v, bottleneck_value)
		max_flow += bottleneck_value
		augmentations.append({
			"path": path.duplicate(),
			"flow": bottleneck_value,
			"method": "edmonds_karp"
		})
	return _compose_flow_result(graph, max_flow, augmentations)


## Construye una representación no dirigida del grafo a partir de get_edges().
## Esto unifica la vista para Graph (no dirigido) y SocialGraph (dirigido),
## combinando aristas opuestas promediando sus pesos cuando ambos sentidos existen.
static func _build_undirected_adjacency(graph: Graph) -> Dictionary:
	var directed: Dictionary = {}
	for e in graph.get_edges():
		var a = e.get("source")
		var b = e.get("target")
		var w: float = float(e.get("weight", 0.0))
		if a == null or b == null:
			continue
		if not directed.has(a):
			directed[a] = {}
		directed[a][b] = w

	var undirected: Dictionary = {}
	for a in directed.keys():
		for b in directed[a].keys():
			if a == b:
				continue
			# Evitar duplicados
			if undirected.has(a) and undirected[a].has(b):
				continue
			var wab: float = float(directed[a][b])
			var wba = null
			if directed.has(b) and directed[b].has(a):
				wba = directed[b][a]
			var final_w: float = wab
			if wba != null:
				final_w = (wab + float(wba)) * 0.5
			if not undirected.has(a):
				undirected[a] = {}
			if not undirected.has(b):
				undirected[b] = {}
			undirected[a][b] = final_w
			undirected[b][a] = final_w

	# Asegurar que vértices aislados estén presentes
	if graph.has_method("get_nodes"):
		for v in graph.get_nodes().keys():
			if not undirected.has(v):
				undirected[v] = {}

	return undirected
	
## Algoritmo de Prim para encontrar el Árbol de Expansión Mínima (MST).
## Retorna un diccionario con:
## - total_weight: Peso total del MST
## - reachable: true si se pudo construir el MST completo
static func prim_mst(graph: Graph, start_key = null) -> Dictionary:
	var result := {
		"edges": [],
		"total_weight": 0.0,
		"reachable": false
	}
	
	if graph == null:
		return result
	
	# Obtener la lista de vértices de forma compatible con Graph/SocialGraph
	# Graph no implementa get_vertices(), usar get_nodes() y tomar las claves
	var vertices: Array = []
	if graph.has_method("get_nodes"):
		vertices = graph.get_nodes().keys()
	elif graph.has_method("get_vertex") and graph.has_method("get_neighbor_weights"):
		# fallback: intentar usar la propiedad pública 'vertices' si existe
		if typeof(graph) == TYPE_OBJECT and graph.has("vertices"):
			vertices = (graph.vertices.keys() if graph.vertices else [])
		else:
			vertices = []
	if vertices.is_empty():
		return result
	
	# Si no se especifica inicio, usar el primer vértice
	if start_key == null:
		start_key = vertices[0]
	
	if not graph.has_vertex(start_key):
		return result
	
	var visited: Dictionary = {}
	var mst_edges: Array = []
	var total_weight: float = 0.0
	# Construir vista no dirigida del grafo a partir de get_edges()
	# Esto permite usar SocialGraph (dirigido) y Graph (no dirigido) de forma uniforme.
	var undirected_adj: Dictionary = _build_undirected_adjacency(graph)
	
	# Priority queue (min heap) - Array de diccionarios { weight, node, parent }
	var min_heap: Array = []
	min_heap.append({"weight": 0.0, "node": start_key, "parent": null})

	while not min_heap.is_empty() and mst_edges.size() < vertices.size() - 1:
		# Ordenar por peso ascendente y obtener la arista de menor peso
		min_heap.sort_custom(func(a, b): return a["weight"] < b["weight"])
		var current: Dictionary = min_heap.pop_front()

		if visited.has(current["node"]):
			continue

		visited[current["node"]] = true

		# Agregar arista al MST (excepto el primer nodo)
		if current["parent"] != null:
			mst_edges.append({
				"from": current["parent"],
				"to": current["node"],
				"weight": current["weight"]
			})
			total_weight += current["weight"]

		# Agregar todas las aristas desde el nodo actual a vecinos no visitados (uso la vista no dirigida)
		var neighbors: Dictionary = undirected_adj.get(current["node"], {})
		for neighbor in neighbors.keys():
			if visited.has(neighbor):
				continue
			var weight: float = float(neighbors[neighbor])
			min_heap.append({"weight": weight, "node": neighbor, "parent": current["node"]})
	
	result["edges"] = mst_edges
	result["total_weight"] = total_weight
	result["reachable"] = (mst_edges.size() == vertices.size() - 1)
	
	return result

static func max_flow_ford_fulkerson(graph: Graph, source, sink, reset_flux: bool = true) -> Dictionary:
	if graph == null or source == null or sink == null:
		return {"max_flow": 0, "flow_paths": [], "saturated_edges": []}
	if not graph.has_vertex(source) or not graph.has_vertex(sink):
		return {"max_flow": 0, "flow_paths": [], "saturated_edges": []}
	if source == sink:
		return {"max_flow": 0, "flow_paths": [], "saturated_edges": []}
	if reset_flux:
		graph.reset_all_flux()
	var max_flow := 0
	var augmentations: Array = []
	while true:
		var visited := {}
		var path_info = _find_augmenting_path_dfs(graph, source, sink, visited)
		var path: Array = path_info.get("path", [])
		if path.is_empty():
			break
		var bottleneck_value: int = int(round(path_info.get("bottleneck", 0)))
		if bottleneck_value <= 0:
			break
		for i in range(path.size() - 1):
			var u = path[i]
			var v = path[i + 1]
			graph.add_edge_flux(u, v, bottleneck_value)
		max_flow += bottleneck_value
		augmentations.append({
			"path": path.duplicate(),
			"flow": bottleneck_value,
			"method": "ford_fulkerson"
		})
	return _compose_flow_result(graph, max_flow, augmentations)


## Encuentra un camino aumentante usando BFS (para Edmonds-Karp).
## Retorna un diccionario con el camino y el cuello de botella.
static func _find_augmenting_path_bfs(graph: Graph, source, sink) -> Dictionary:
	var result := {
		"path": [],
		"bottleneck": 0
	}
	
	var queue: Array = [source]
	var visited: Dictionary = {source: true}
	var parent: Dictionary = {}
	var found := false
	
	# BFS para encontrar camino con capacidad residual
	while not queue.is_empty() and not found:
		var current = queue.pop_front()
		
		if current == sink:
			found = true
			break
		
		var neighbor_weights = graph.get_neighbor_weights(current)
		for neighbor in neighbor_weights.keys():
			if visited.has(neighbor):
				continue
			
			# Verificar si hay capacidad residual
			var residual = graph.get_edge_residual_capacity(current, neighbor)
			if residual > 0.0:
				visited[neighbor] = true
				parent[neighbor] = current
				queue.append(neighbor)
	
	if not found:
		return result
	
	# Reconstruir camino
	var path: Array = []
	var cursor = sink
	while cursor != source:
		path.insert(0, cursor)
		cursor = parent.get(cursor, null)
		if cursor == null:
			return result
	path.insert(0, source)
	
	# Calcular cuello de botella (mínima capacidad residual)
	var bottleneck := INF
	for i in range(path.size() - 1):
		var u = path[i]
		var v = path[i + 1]
		var residual = graph.get_edge_residual_capacity(u, v)
		bottleneck = min(bottleneck, residual)
	
	result["path"] = path
	result["bottleneck"] = int(bottleneck)
	return result


static func _find_augmenting_path_dfs(graph: Graph, current, sink, visited: Dictionary) -> Dictionary:
	var result := {
		"path": [],
		"bottleneck": 0
	}
	if current == null or sink == null:
		return result
	if current == sink:
		result["path"] = [sink]
		result["bottleneck"] = INF
		return result
	visited[current] = true
	var neighbor_weights = graph.get_neighbor_weights(current)
	for neighbor in neighbor_weights.keys():
		if visited.has(neighbor):
			continue
		var residual = graph.get_edge_residual_capacity(current, neighbor)
		if residual <= 0.0:
			continue
		var sub = _find_augmenting_path_dfs(graph, neighbor, sink, visited)
		var sub_path: Array = sub.get("path", [])
		if sub_path.is_empty():
			continue
		var bottleneck = min(residual, float(sub.get("bottleneck", 0)))
		sub_path.insert(0, current)
		result["path"] = sub_path
		result["bottleneck"] = bottleneck
		return result
	return result


static func _compose_flow_result(graph: Graph, max_flow: int, augmentations: Array) -> Dictionary:
	var saturated: Array = []
	var flow_edges = graph.get_flow_edges()
	for edge_info in flow_edges:
		if edge_info.get("residual", 0.0) <= 0.0:
			saturated.append({
				"source": edge_info.get("source"),
				"target": edge_info.get("target"),
				"capacity": edge_info.get("capacity", 0.0)
			})
	return {
		"max_flow": max_flow,
		"flow_paths": augmentations,
		"saturated_edges": saturated
	}


## Calcula el corte mínimo después de ejecutar un algoritmo de flujo máximo.
## Devuelve los conjuntos de nodos alcanzables desde la fuente (S) y el resto (T).
##
## IMPORTANTE: Ejecuta max_flow_edmonds_karp antes de llamar a esta función.
##
## Retorna:
## - reachable_from_source: Array - Nodos alcanzables desde source usando aristas no saturadas
## - cut_edges: Array - Aristas del corte mínimo
## - cut_capacity: float - Suma de capacidades de las aristas del corte
static func min_cut(graph: Graph, source) -> Dictionary:
	var result := {
		"reachable_from_source": [],
		"cut_edges": [],
		"cut_capacity": 0.0
	}
	
	if graph == null or source == null or not graph.has_vertex(source):
		return result
	
	# BFS usando solo aristas con capacidad residual > 0
	var queue: Array = [source]
	var reachable: Dictionary = {source: true}
	
	while not queue.is_empty():
		var current = queue.pop_front()
		result["reachable_from_source"].append(current)
		
		var neighbor_weights = graph.get_neighbor_weights(current)
		for neighbor in neighbor_weights.keys():
			if reachable.has(neighbor):
				continue
			
			var residual = graph.get_edge_residual_capacity(current, neighbor)
			if residual > 0.0:
				reachable[neighbor] = true
				queue.append(neighbor)
	
	# Encontrar aristas del corte (de S a T)
	var cut_capacity := 0.0
	for node in result["reachable_from_source"]:
		var neighbor_weights = graph.get_neighbor_weights(node)
		for neighbor in neighbor_weights.keys():
			if not reachable.has(neighbor):
				var edge = graph.get_edge_resource(node, neighbor)
				if edge:
					result["cut_edges"].append({
						"source": node,
						"target": neighbor,
						"capacity": edge.weight,
						"flux": edge.flux
					})
					cut_capacity += edge.weight
	
	result["cut_capacity"] = cut_capacity
	return result
