class_name GraphLayout

const TAU := PI * 2.0

## GraphLayout: algoritmos de posicionamiento para nodos del grafo
## Proporciona layouts: circular, grid, force-directed y jerárquico
func circular_layout(node_count: int, radius: float, center: Vector2) -> Array:
	var positions: Array = []
	if node_count <= 0:
		return positions
	for i in range(node_count):
		var ang = TAU * float(i) / float(node_count)
		var p = center + Vector2(cos(ang), sin(ang)) * radius
		positions.append(p)
	return positions


func grid_layout(node_count: int, cols: int, spacing: float, center: Vector2) -> Array:
	var positions: Array = []
	if node_count <= 0:
		return positions
	cols = max(1, cols)
	var rows = int(ceil(float(node_count) / float(cols)))
	var total_width = (cols - 1) * spacing
	var total_height = (rows - 1) * spacing
	var start_x = center.x - total_width * 0.5
	var start_y = center.y - total_height * 0.5
	for i in range(node_count):
		var r = int(floor(float(i) / float(cols)))
		var c = int(i % cols)
		var p = Vector2(start_x + c * spacing, start_y + r * spacing)
		positions.append(p)
	return positions


func force_directed_layout(node_keys: Array, edges: Array, iterations: int, area: float, repulsion: float, damping: float, center: Vector2) -> Dictionary:
	# Fruchterman-Reingold layout with cooling and boundary clamping.
	var positions := {}
	var n := node_keys.size()
	if n == 0:
		return positions

	var effective_area: float = max(area, float(n) * 400.0)
	var width: float = sqrt(effective_area)
	var height: float = width
	var half_width: float = width * 0.5
	var half_height: float = height * 0.5
	var rnd = RandomNumberGenerator.new()
	rnd.randomize()

	for key in node_keys:
		var offset = Vector2(
			rnd.randf_range(-half_width, half_width),
			rnd.randf_range(-half_height, half_height)
		)
		positions[key] = center + offset

	var edge_pairs: Array = []
	for e in edges:
		var a = e.get("from", e.get("source", null))
		var b = e.get("to", e.get("target", null))
		if a == null or b == null:
			continue
		if a == b:
			continue
		edge_pairs.append([a, b])

	var k := sqrt((width * height) / max(1, n))
	var max_iterations: int = max(1, iterations)
	var cooling: float = clamp(damping, 0.01, 0.99)
	var temperature: float = max(half_width, half_height)
	var repulsion_scale: float = max(0.01, repulsion)

	for _step in range(max_iterations):
		var displacements := {}
		for v in node_keys:
			displacements[v] = Vector2.ZERO

		# Repulsive forces
		for i in range(n):
			var v = node_keys[i]
			for j in range(i + 1, n):
				var u = node_keys[j]
				var delta = positions[v] - positions[u]
				var dist = max(0.001, delta.length())
				var force = ((k * k) / dist) * repulsion_scale
				var dir = delta / dist
				displacements[v] += dir * force
				displacements[u] -= dir * force

		# Attractive forces
		for pair in edge_pairs:
			var a = pair[0]
			var b = pair[1]
			if not positions.has(a) or not positions.has(b):
				continue
			var delta = positions[a] - positions[b]
			var dist = max(0.001, delta.length())
			var force = (dist * dist) / k
			var dir = delta / dist
			displacements[a] -= dir * force
			displacements[b] += dir * force

		# Apply displacements with temperature limit
		for v in node_keys:
			var disp: Vector2 = displacements[v]
			if disp == Vector2.ZERO:
				continue
			var disp_len = disp.length()
			var limited = disp / disp_len * min(disp_len, temperature)
			positions[v] += limited
			positions[v].x = clamp(positions[v].x, center.x - half_width, center.x + half_width)
			positions[v].y = clamp(positions[v].y, center.y - half_height, center.y + half_height)

		temperature *= cooling
		if temperature < 0.5:
			break

	return positions


func hierarchical_layout(node_keys: Array, edges: Array, root_key, level_gap: float, sibling_spacing: float, center: Vector2) -> Dictionary:
	# Simple BFS-based layering. Returns Dictionary key->Vector2
	var positions := {}
	if node_keys.size() == 0:
		return positions

	# Build adjacency
	var adj := {}
	for k in node_keys:
		adj[k] = []
	for e in edges:
		var a = e.get("from", e.get("source", null))
		var b = e.get("to", e.get("target", null))
		if a != null and b != null and adj.has(a) and adj.has(b):
			adj[a].append(b)
			adj[b].append(a)

	# BFS
	var queue := []
	var level := {}
	for k in node_keys:
		level[k] = -1
	if not level.has(root_key):
		root_key = node_keys[0]
	level[root_key] = 0
	queue.append(root_key)
	while queue.size() > 0:
		var v = queue.pop_front()
		for nb in adj[v]:
			if level[nb] == -1:
				level[nb] = level[v] + 1
				queue.append(nb)

	# Group by levels
	var groups := {}
	for k in node_keys:
		var l = level[k]
		if l < 0:
			l = max(0, level[root_key] + 1) # orphan nodes
		if not groups.has(l):
			groups[l] = []
		groups[l].append(k)

	# Assign positions per level
	var levels_sorted = groups.keys()
	levels_sorted.sort()
	for li in range(levels_sorted.size()):
		var lvl = levels_sorted[li]
		var nodes_here = groups[lvl]
		var row_width = (nodes_here.size() - 1) * sibling_spacing
		var start_x = center.x - row_width * 0.5
		var y = center.y + li * level_gap
		for i in range(nodes_here.size()):
			var k = nodes_here[i]
			positions[k] = Vector2(start_x + i * sibling_spacing, y)

	return positions
