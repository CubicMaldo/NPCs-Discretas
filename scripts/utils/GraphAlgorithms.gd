class_name GraphAlgorithms

const INF := 1.0e18

## Devuelve la familiaridad (afinidad/conocimiento) promedio de todas las aristas del grafo.
static func average_affinity(graph: Graph) -> float:
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


## Camino más corto clásico (Dijkstra-like) sobre pesos interpretados como costos.
##
## IMPORTANTE: Este algoritmo respeta la direccionalidad del grafo. Solo puede encontrar
## caminos que sigan las aristas en su dirección correcta (A→B).
##
## Parámetros:
## - graph: Grafo dirigido que expone vecinos y pesos (costos). Los pesos más altos incrementan la distancia total.
## - source, target: claves de vértice (ids o llaves internas) presentes en el grafo.
##
## Retorna (Dictionary):
## - reachable: bool indicando si existe ruta dirigida desde source hasta target.
## - distance: float con la suma de pesos a lo largo de la ruta encontrada.
## - path: Array con las claves de vértice que forman la ruta (incluye source y target).
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


## Bellman-Ford: camino más corto con soporte para pesos negativos.
##
## Uso: cuando pueden existir aristas con pesos negativos. Detecta ciclos negativos alcanzables.
## Nota: Ahora soporta grafos dirigidos. Solo relaja aristas en la dirección que existen.
##
## Parámetros:
## - graph: Grafo dirigido que expone get_edges() y get_nodes().
## - source, target: claves de vértices.
##
## Retorna (Dictionary):
## - reachable: bool si existe ruta (sin considerar ciclos negativos).
## - distance: float con la mejor distancia hallada.
## - path: Array con la ruta reconstruida.
## - negative_cycle: bool si se detectó un ciclo negativo alcanzable tras relajaciones.
static func shortest_path_bellman_ford(graph: Graph, source, target) -> Dictionary:
	var result := {
		"reachable": false,
		"distance": 0.0,
		"path": [],
		"negative_cycle": false
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

	var nodes_dict: Dictionary = graph.get_nodes()
	var vertices: Array = nodes_dict.keys()
	var dist: Dictionary = {}
	var prev: Dictionary = {}
	for v in vertices:
		dist[v] = INF
	dist[source] = 0.0

	var edges: Array = graph.get_edges()
	var n: int = max(vertices.size(), 1)

	# Relaja V-1 veces
	for _i in range(n - 1):
		var updated := false
		for e in edges:
			var u = e.get("source")
			var v = e.get("target")
			var w: float = float(e.get("weight", 0.0))
			# Relajar u -> v (grafo dirigido)
			var du: float = float(dist.get(u, INF))
			var dv: float = float(dist.get(v, INF))
			if du + w < dv:
				dist[v] = du + w
				prev[v] = u
				updated = true
		if not updated:
			break

	# Detección de ciclo negativo alcanzable
	for e in edges:
		var u2 = e.get("source")
		var v2 = e.get("target")
		var w2: float = float(e.get("weight", 0.0))
		var du2: float = float(dist.get(u2, INF))
		var dv2: float = float(dist.get(v2, INF))
		if du2 + w2 < dv2:
			result["negative_cycle"] = true
			break

	if dist.get(target, INF) >= INF:
		return result

	# Reconstrucción de ruta
	var path: Array = []
	var cursor = target
	var guard := 0
	while guard < vertices.size():
		path.insert(0, cursor)
		if cursor == source:
			break
		cursor = prev.get(cursor, null)
		if cursor == null:
			path.clear()
			return result
		guard += 1

	result["reachable"] = true
	result["distance"] = float(dist.get(target, 0.0))
	result["path"] = path
	return result

## Strongest path (máximo producto de familiaridades a lo largo del camino).
##
## IMPORTANTE: Este algoritmo respeta la direccionalidad del grafo. Busca el camino dirigido
## más fuerte desde source hasta target siguiendo solo las aristas en su dirección correcta.
##
## Semántica:
## - Los pesos del grafo representan familiaridades/conocimiento (tie strength) en [0..100].
## - Se normalizan a [0..1] y se busca maximizar el producto acumulado (confianza/probabilidad compuesta).
##
## Parámetros:
## - graph: Grafo dirigido con pesos como familiaridades.
## - source, target: claves de vértice.
##
## Retorna (Dictionary):
## - reachable: bool indicando si hay camino dirigido.
## - strength: float en [0..1] con el producto máximo de afinidades.
## - path: Array de claves de vértice con el camino encontrado.
static func strongest_path_dijkstra(graph: Graph, source, target) -> Dictionary:
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
			result["strength"] = 1.0
		return result
	if not graph.has_vertex(source) or not graph.has_vertex(target):
		return result

	var strength: Dictionary = {}
	var previous: Dictionary = {}
	var pending: Array = [source]
	var visited: Dictionary = {}
	strength[source] = 1.0

	while not pending.is_empty():
		var current = _pop_strongest(pending, strength)
		if visited.has(current):
			continue
		visited[current] = true
		if current == target:
			break

		var neighbor_weights: Dictionary = graph.get_neighbor_weights(current)
		for neighbor in neighbor_weights.keys():
			if visited.has(neighbor):
				continue
			var w: float = float(neighbor_weights[neighbor])
			if w <= 0.0:
				continue
			var aff: float = clamp(w / 100.0, 0.0, 1.0)
			var current_strength: float = float(strength.get(current, 0.0))
			var candidate_strength: float = current_strength * aff
			var existing: float = float(strength.get(neighbor, 0.0))
			if candidate_strength > existing:
				strength[neighbor] = candidate_strength
				previous[neighbor] = current
				if not pending.has(neighbor):
					pending.append(neighbor)

	if not strength.has(target):
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
	result["strength"] = float(strength.get(target, 0.0))
	result["path"] = path
	return result

## Alias conveniente para el camino más fuerte (equivale a strongest_path_dijkstra).
static func strongest_path(graph: Graph, source, target) -> Dictionary:
	return strongest_path_dijkstra(graph, source, target)

## Extrae y remueve de la cola el nodo con mayor "strength" (uso interno de strongest_path).
## Parámetros: queue (Array de claves), strengths (Dict clave->float)
## Retorna: clave del mejor nodo según strength.
static func _pop_strongest(queue: Array, strengths: Dictionary):
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


## Métricas de amistad mutua entre dos actores.
##
## IMPORTANTE: En un grafo dirigido, este algoritmo busca vecinos que ambos actores "conocen"
## (tienen aristas salientes hacia ellos). Para relaciones bidireccionales completas,
## ambas aristas deben existir explícitamente.
##
## Parámetros:
## - graph: grafo social dirigido.
## - a, b: claves de vértices a comparar.
## - min_weight: umbral mínimo de familiaridad para considerar a un vecino como conexión válida.
##
## Retorna (Dictionary):
## - count: número de vecinos mutuos por encima del umbral.
## - entries: Array de diccionarios con detalle por vecino (neighbor, weight_a, weight_b, average_weight).
## - average_weight: media de las afinidades promedio entre a y b hacia los mutuos.
## - jaccard_index: similitud entre conjuntos de vecinos salientes (0..1).
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


## Simula la propagación de un rumor/influencia desde un actor semilla.
##
## IMPORTANTE: En un grafo dirigido, la influencia solo se propaga siguiendo las aristas
## en su dirección correcta (A→B). Los rumores NO se propagan hacia atrás.
##
## Semántica:
## - En cada paso, la influencia se propaga a vecinos salientes con: propagated = strength * attenuation * normalized(weight),
##   donde weight es la familiaridad normalizada a [0..1].
## - Se ignoran propagaciones por debajo de min_strength.
##
## Parámetros:
## - graph: grafo social dirigido.
## - seed_key: clave del actor inicial.
## - steps: pasos de propagación (profundidad máxima).
## - attenuation: factor de atenuación por salto (0..1).
## - min_strength: umbral mínimo para considerar una propagación.
##
## Retorna (Dictionary):
## - seed: clave semilla.
## - steps: pasos simulados.
## - reached: claves alcanzadas siguiendo aristas dirigidas (Array).
## - influence: Dict clave->float con influencia máxima registrada en cada nodo.
static func propagate_rumor(graph: Graph, seed_key, steps: int, attenuation: float, min_strength: float) -> Dictionary:
	var result := {
		"seed": seed_key,
		"steps": steps,
		"reached": [],
		"influence": {}
	}
	if graph == null or seed_key == null or not graph.has_vertex(seed_key):
		return result
	var influence: Dictionary = {}
	influence[seed_key] = 1.0
	var frontier: Array = [{"key": seed_key, "strength": 1.0}]
	for step in range(max(steps, 0)):
		if frontier.is_empty():
			break
		var next_frontier_map: Dictionary = {}
		for entry in frontier:
			var current = entry.get("key")
			var strength: float = float(entry.get("strength", 0.0))
			if strength <= 0.0:
				continue
			var neighbor_weights: Dictionary = graph.get_neighbor_weights(current)
			for neighbor in neighbor_weights.keys():
				if neighbor == current:
					continue
				var weight: float = float(neighbor_weights[neighbor])
				var propagated: float = strength * attenuation * _normalized_weight(weight)
				if propagated < min_strength:
					continue
				var existing: float = float(influence.get(neighbor, 0.0))
				if propagated > existing:
					influence[neighbor] = propagated
				if step < steps - 1 and propagated >= min_strength:
					var queued: float = float(next_frontier_map.get(neighbor, 0.0))
					if propagated > queued:
						next_frontier_map[neighbor] = propagated
		frontier = []
		for neighbor in next_frontier_map.keys():
			frontier.append({"key": neighbor, "strength": next_frontier_map[neighbor]})
	result["influence"] = influence
	result["reached"] = influence.keys()
	return result


## Extrae y remueve de la cola el nodo con menor distancia (uso interno de shortest_path).
## Parámetros: queue (Array de claves), distances (Dict clave->float)
## Retorna: clave del mejor nodo según distancia.
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


## Índice de Jaccard entre dos conjuntos (listas) de claves.
## Retorna un float en [0..1]. 0 si ambos vacíos.
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


## Normaliza un peso de familiaridad en [0..100] a [0..1].
## Pesos <= 0 retornan 0.0.
static func _normalized_weight(weight: float) -> float:
	if weight <= 0.0:
		return 0.0
	return clamp(weight / 100.0, 0.0, 1.0)
