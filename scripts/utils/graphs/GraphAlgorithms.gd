class_name GraphAlgorithms
const INF := 1.0e18

## Devuelve el peso promedio de todas las aristas del grafo.
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
## Retorna un diccionario con información del recorrido:
## - visited: Array de claves visitadas en orden BFS
## - levels: Dictionary { clave: nivel } indicando la distancia desde el origen
## - parent: Dictionary { clave: padre } para reconstruir caminos
static func bfs(graph: Graph, start_key) -> Dictionary:
	var result := {
		"visited": [],
		"levels": {},
		"parent": {}
	}
	
	if graph == null or start_key == null or not graph.has_vertex(start_key):
		return result
	
	var queue: Array = [start_key]
	var visited: Dictionary = {}
	var levels: Dictionary = {}
	var parent: Dictionary = {}
	
	visited[start_key] = true
	levels[start_key] = 0
	
	while not queue.is_empty():
		var current = queue.pop_front()
		result["visited"].append(current)
		
		var current_level: int = int(levels.get(current, 0))
		var neighbor_weights: Dictionary = graph.get_neighbor_weights(current)
		
		for neighbor in neighbor_weights.keys():
			if visited.has(neighbor):
				continue
			
			visited[neighbor] = true
			levels[neighbor] = current_level + 1
			parent[neighbor] = current
			queue.append(neighbor)
	
	result["levels"] = levels
	result["parent"] = parent
	return result


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
