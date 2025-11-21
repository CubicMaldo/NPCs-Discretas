extends Node2D
## GraphDisplay: Modular visual bridge between Graph.gd (model) and node/edge views
## Uses composition pattern - coordinates GraphLayout, NodeView, and EdgeView components
## Responsibilities:
## - Instantiate NodeView and EdgeView for each vertex/edge
## - Apply layout algorithms to position nodes
## - Provide high-level methods for visual state updates
## - React to EventBus signals for visualization feedback

@export var node_scene: PackedScene
@export var edge_scene: PackedScene
@export_enum("circular", "grid", "force_directed", "hierarchical") var layout_type: String = "hierarchical"
@export var layout_radius: float = 250.0
@export var layout_spacing: float = 150.0
@export_enum("none", "weight", "flux", "both") var edge_label_mode: String = "none"
@export var show_edge_direction: bool = false

var graph = null
var node_views := {}
var edge_views := []
var edge_view_map := {}
var layout_component: GraphLayout = null

# Containers for organization in the scene tree
var _nodes_container: Node2D = null
var _edges_container: Node2D = null

signal node_selected(node_key)


## Display a Graph instance (model) on screen with automatic layout
func display_graph(g) -> void:
	graph = g
	_clear()
	_ensure_containers()
	if not graph:
		return
	
	# Step 1: Spawn nodes
	var node_keys: Array = []
	if graph.has_method("get_nodes"):
		var nodes_dict: Dictionary = graph.get_nodes()
		for key in nodes_dict.keys():
			node_keys.append(key)
			var meta = nodes_dict[key]
			var node_data := {"id": key, "meta": meta}
			_spawn_node(node_data)
	
	# Step 2: Apply layout algorithm to position nodes
	_apply_layout(node_keys)
	
	# Step 3: Spawn edges and link to nodes
	if graph.has_method("get_edges"):
		for e in graph.get_edges():
			_spawn_edge(e)
	
	# Step 4: Emit graph displayed signal
	#EventBus.graph_displayed.emit(graph)


## Update the visual state of a specific node by key
func set_node_state(node_key, state: String) -> void:
	if node_views.has(node_key):
		var node_view = node_views[node_key]
		if node_view and node_view.has_method("set_state"):
			node_view.set_state(state)


## Show a clue on a specific node
func show_node_clue(node_key, clue_text: String) -> void:
	if node_views.has(node_key):
		var node_view = node_views[node_key]
		if node_view and node_view.has_method("show_clue"):
			node_view.show_clue(clue_text)


## Highlight a node (legacy method for mission controllers)
func highlight_node(node_key) -> void:
	set_node_state(node_key, "current")


func _clear() -> void:
	# Clear node view instances under the nodes container (if present)
	if _nodes_container and is_instance_valid(_nodes_container):
		for child in _nodes_container.get_children():
			if is_instance_valid(child):
				child.queue_free()
		node_views.clear()
	# Clear edge view instances under the edges container (if present)
	if _edges_container and is_instance_valid(_edges_container):
		for child in _edges_container.get_children():
			if is_instance_valid(child):
				child.queue_free()
		edge_views.clear()
		edge_view_map.clear()
	# Keep containers in place for reuse
	return


func _ensure_containers() -> void:
	# Create or find dedicated containers for nodes and edges to keep the scene tree organized
	if not _edges_container or not is_instance_valid(_edges_container):
		_edges_container = get_node_or_null("Edges")
		if not _edges_container:
			_edges_container = Node2D.new()
			_edges_container.name = "Edges"
			add_child(_edges_container)
	if not _nodes_container or not is_instance_valid(_nodes_container):
		_nodes_container = get_node_or_null("Nodes")
		if not _nodes_container:
			_nodes_container = Node2D.new()
			_nodes_container.name = "Nodes"
			add_child(_nodes_container)


func _spawn_node(v_data) -> Node:
	var inst: Node = null
	if node_scene:
		inst = node_scene.instantiate()
		# add under Nodes container for organization
		_ensure_containers()
		_nodes_container.add_child(inst)
		if inst.has_method("setup"):
			inst.setup(v_data)
	else:
		inst = Node2D.new()
		_ensure_containers()
		_nodes_container.add_child(inst)
	
	var key = ""
	if typeof(v_data) == TYPE_DICTIONARY and v_data.has("id"):
		key = v_data.id
	else:
		key = str(v_data)
	node_views[key] = inst
	if inst and inst.has_signal("node_selected"):
		inst.node_selected.connect(_on_node_view_selected)
	return inst


func _spawn_edge(e_data) -> Node:
	var inst: Node = null
	if edge_scene:
		inst = edge_scene.instantiate()
		_ensure_containers()
		_edges_container.add_child(inst)
		if inst.has_method("setup"):
			inst.setup(e_data)
		
		# Link edge to node views for dynamic positioning
		var source_key = e_data.get("source", e_data.get("from"))
		var target_key = e_data.get("target", e_data.get("to"))
		
		if node_views.has(source_key) and node_views.has(target_key):
			var source_node = node_views[source_key]
			var target_node = node_views[target_key]
			if inst.has_method("set_node_references"):
				inst.set_node_references(source_node, target_node)
		
		# Configure edge label display mode
		if inst.has_method("set_label_mode"):
			inst.set_label_mode(edge_label_mode)
		
		# Configure edge direction display
		if inst.has_method("set_show_direction"):
			inst.set_show_direction(show_edge_direction)
	else:
		inst = Node2D.new()
		_ensure_containers()
		_edges_container.add_child(inst)
	
	var edge_source = e_data.get("source", e_data.get("from"))
	var edge_target = e_data.get("target", e_data.get("to"))
	var key = _edge_key(edge_source, edge_target)
	if key != "":
		edge_view_map[key] = inst
		var reverse_key = _edge_key(edge_target, edge_source)
		if reverse_key != key:
			edge_view_map[reverse_key] = inst
	edge_views.append(inst)
	return inst


func update_edge_label_mode(mode: String) -> void:
	edge_label_mode = mode
	for edge_view in edge_views:
		if edge_view and edge_view.has_method("set_label_mode"):
			edge_view.set_label_mode(mode)


func reset_visual_states(default_node_state: String = "unvisited", default_edge_state: String = "default") -> void:
	for key in node_views.keys():
		set_node_state(key, default_node_state)
	for edge_view in edge_views:
		if edge_view and edge_view.has_method("set_state"):
			edge_view.set_state(default_edge_state)


func _apply_layout(node_keys: Array) -> void:
	if node_keys.size() == 0:
		return
	var positions := {}

	# ensure we have a layout component instance (composed component)
	if layout_component == null:
		# instantiate and attach so it will appear in the scene tree (optional)
		layout_component = GraphLayout.new()
	
	match layout_type:
		"circular":
			var pos_array = layout_component.circular_layout(node_keys.size(), layout_radius, global_position)
			for i in range(node_keys.size()):
				positions[node_keys[i]] = pos_array[i]
		
		"grid":
			var pos_array = layout_component.grid_layout(node_keys.size(), 4, layout_spacing, global_position)
			for i in range(node_keys.size()):
				positions[node_keys[i]] = pos_array[i]
		
		"force_directed":
			var edges = graph.get_edges() if graph.has_method("get_edges") else []
			positions = layout_component.force_directed_layout(
				node_keys, edges, 150, 280000, 0.6, 0.9, global_position
			)
		
		"hierarchical":
			var root_key = node_keys[0] if node_keys.size() > 0 else null
			if root_key:
				var edges = graph.get_edges() if graph.has_method("get_edges") else []
				positions = layout_component.hierarchical_layout(
					node_keys, edges, root_key, 120.0, 100.0, global_position
				)
	
	# Apply positions to node views
	for key in positions.keys():
		if node_views.has(key):
			node_views[key].global_position = positions[key]


func set_edge_state(a, b, state: String) -> void:
	var view = _get_edge_view(a, b)
	if view and view.has_method("set_state"):
		view.set_state(state)


func _get_edge_view(a, b):
	var key = _edge_key(a, b)
	return edge_view_map.get(key)


func _edge_key(a, b) -> String:
	if a == null or b == null:
		return ""
	return "%s|%s" % [str(a), str(b)]


func _on_node_view_selected(node_key) -> void:
	if not node_views.has(node_key):
		return
	node_selected.emit(node_key)
