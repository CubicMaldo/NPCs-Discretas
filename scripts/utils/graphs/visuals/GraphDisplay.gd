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

## Auto-zoom and pan controls (TreeCamera-inspired for Node2D)
@export var enable_auto_zoom: bool = true
@export var min_zoom: float = 0.1 # Changed from 0.5 to allow more zoom out
@export var max_zoom: float = 5.0 # Changed from 3.0 to allow more zoom in
@export var zoom_step: float = 0.15
@export var zoom_smooth_speed: float = 8.0
@export var pan_speed: float = 1.0
@export var enable_mouse_pan: bool = true
@export var enable_mouse_zoom: bool = true

var graph = null
var node_views := {}
var edge_views := []
var edge_view_map := {}
var layout_component: GraphLayout = null

# Camera/viewport controls (TreeCamera-inspired, adapted for Node2D)
var drag_active: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO
var camera_offset: Vector2 = Vector2.ZERO
var zoom_factor: float = 1.0
var target_zoom: float = 1.0

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
	
	# Step 4: Apply auto-zoom and center (deferred to ensure layout is complete)
	if enable_auto_zoom:
		print("[GraphDisplay] Scheduling auto-zoom for %d nodes" % node_keys.size())
		call_deferred("_apply_auto_zoom_deferred", node_keys.size())
	
	# Step 5: Emit graph displayed signal
	#EventBus.graph_displayed.emit(graph)


## Deferred auto-zoom application
func _apply_auto_zoom_deferred(node_count: int) -> void:
	print("[GraphDisplay] Applying deferred auto-zoom for %d nodes" % node_count)
	_apply_auto_zoom(node_count)
	_center_graph()


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
	if not _nodes_container:
		_nodes_container = Node2D.new()
		_nodes_container.name = "NodesContainer"
		add_child(_nodes_container)
	
	if not _edges_container:
		_edges_container = Node2D.new()
		_edges_container.name = "EdgesContainer"
		add_child(_edges_container)
		# Move edges behind nodes visually
		move_child(_edges_container, 0)


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


## Apply auto-zoom based on node count
func _apply_auto_zoom(node_count: int) -> void:
	if node_count == 0:
		return
	
	# Calculate appropriate zoom based on node count
	var calculated_zoom: float
	if node_count <= 5:
		calculated_zoom = 1.0
	elif node_count <= 10:
		calculated_zoom = 0.8
	elif node_count <= 20:
		calculated_zoom = 0.6
	elif node_count <= 50:
		calculated_zoom = 0.5
	else:
		calculated_zoom = 0.4
	
	target_zoom = clamp(calculated_zoom, min_zoom, max_zoom)
	zoom_factor = target_zoom # Set immediately for auto-zoom
	
	if _nodes_container:
		_nodes_container.scale = Vector2.ONE * zoom_factor
	if _edges_container:
		_edges_container.scale = Vector2.ONE * zoom_factor
	
	print("[GraphDisplay] Auto-zoom set to: %.2f for %d nodes" % [zoom_factor, node_count])


## Center the graph in the viewport
func _center_graph() -> void:
	if node_views.is_empty():
		return
	
	# Calculate bounding box of all nodes
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	
	for node_view in node_views.values():
		if not is_instance_valid(node_view):
			continue
		var pos = node_view.position # Local position in container
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
	
	# Calculate center point
	var graph_center = (min_pos + max_pos) / 2.0
	var viewport_size = get_viewport_rect().size
	var viewport_center = viewport_size / 2.0
	
	print("[GraphDisplay] Graph center: %s, Viewport center: %s" % [graph_center, viewport_center])
	
	# Calculate offset to center the graph
	var offset = viewport_center - graph_center * zoom_factor
	
	if _nodes_container:
		_nodes_container.position = offset
	if _edges_container:
		_edges_container.position = offset
	
	camera_offset = offset
	print("[GraphDisplay] Centered at offset: %s" % camera_offset)


## Handle mouse input for pan and zoom (Node2D with TreeCamera approach)
func _input(event: InputEvent) -> void:
	if not enable_mouse_pan and not enable_mouse_zoom:
		return
	
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and drag_active:
		_handle_mouse_drag(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	# Mouse wheel zoom
	if enable_mouse_zoom:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_change_zoom(1)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_change_zoom(-1)
			get_viewport().set_input_as_handled()
	
	# Drag with left or middle mouse button
	if enable_mouse_pan:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				drag_active = true
				last_mouse_pos = get_local_mouse_position()
				print("[GraphDisplay] Started dragging")
				get_viewport().set_input_as_handled()
			else:
				drag_active = false
				print("[GraphDisplay] Stopped dragging")


func _handle_mouse_drag(event: InputEventMouseMotion) -> void:
	if not drag_active:
		return
	
	var current_pos = get_local_mouse_position()
	var delta = current_pos - last_mouse_pos
	last_mouse_pos = current_pos
	
	_apply_pan(delta)
	get_viewport().set_input_as_handled()


func _apply_pan(delta: Vector2) -> void:
	camera_offset += delta
	
	if _nodes_container:
		_nodes_container.position += delta
	
	if _edges_container:
		_edges_container.position += delta


func _change_zoom(direction: int) -> void:
	var new_zoom = target_zoom + direction * zoom_step
	target_zoom = clamp(new_zoom, min_zoom, max_zoom)
	print("[GraphDisplay] Target zoom: %.2f" % target_zoom)


func _process(delta: float) -> void:
	# Smooth zoom interpolation
	if abs(target_zoom - zoom_factor) > 0.001:
		_apply_smooth_zoom(delta)


func _apply_smooth_zoom(delta: float) -> void:
	var old_zoom = zoom_factor
	zoom_factor = lerp(zoom_factor, target_zoom, zoom_smooth_speed * delta)
	
	if abs(target_zoom - zoom_factor) < 0.001:
		zoom_factor = target_zoom
	
	_apply_zoom_transform(old_zoom)


func _apply_zoom_transform(old_zoom: float) -> void:
	if _nodes_container == null or _edges_container == null:
		return
	
	var zoom_ratio = zoom_factor / old_zoom
	var viewport_size = get_viewport_rect().size
	var viewport_center = viewport_size / 2.0
	var offset_before = _nodes_container.position - viewport_center
	
	# Apply zoom
	_nodes_container.scale = Vector2.ONE * zoom_factor
	_edges_container.scale = Vector2.ONE * zoom_factor
	
	# Adjust position to zoom towards center
	var offset_after = offset_before * zoom_ratio
	_nodes_container.position = viewport_center + offset_after
	_edges_container.position = _nodes_container.position


func _ready() -> void:
	# Enable input processing and _process for smooth zoom
	set_process_input(true)
	set_process(true)

## Reset view to default zoom and center
func reset_view() -> void:
	if node_views.size() > 0:
		_apply_auto_zoom(node_views.size())
		_center_graph()
	else:
		zoom_factor = 1.0
		target_zoom = 1.0
		camera_offset = Vector2.ZERO
		if _nodes_container:
			_nodes_container.scale = Vector2.ONE
			_nodes_container.position = Vector2.ZERO
		if _edges_container:
			_edges_container.scale = Vector2.ONE
			_edges_container.position = Vector2.ZERO


func _on_node_view_selected(node_key) -> void:
	if not node_views.has(node_key):
		return
	node_selected.emit(node_key)
