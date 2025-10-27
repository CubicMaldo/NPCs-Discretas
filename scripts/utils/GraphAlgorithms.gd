class_name GraphAlgorithms

## Devuelve la afinidad promedio de todas las aristas del grafo.
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
