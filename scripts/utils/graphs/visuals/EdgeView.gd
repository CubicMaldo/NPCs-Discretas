extends Node2D
## EdgeView: visual representation of a graph edge
## Draws lines between nodes and updates when nodes move
## Supports weight-based thickness and directional arrows

var source_id = null
var target_id = null
var weight: float = 1.0
var flux: int = 0
var source_node: Node2D = null
var target_node: Node2D = null
var label_mode: String = "none"
var show_direction: bool = false

# Estimated visual radius for NodeView hit/visual area (matches NodeView._unhandled_input)
const NODE_VISUAL_RADIUS := 36.0
const BASE_WIDTH := 3.0
const MAX_WIDTH := 10.0
const ARROW_DISTANCE_FROM_TARGET := 25.0  # Distance from target node to place arrow


func _compute_clipped_endpoints() -> Dictionary:
	# Returns world-space positions {"start":Vector2, "end":Vector2, "dir":Vector2, "dist":float}
	var out := {}
	if not source_node or not target_node:
		return out

	var start_pos = source_node.global_position
	var end_pos = target_node.global_position
	var dir = end_pos - start_pos
	var dist = max(0.001, dir.length())
	var ndir = dir / dist

	var r_start = NODE_VISUAL_RADIUS
	var r_end = NODE_VISUAL_RADIUS

	if dist <= (r_start + r_end + 4.0):
		var p1 = start_pos + ndir * (dist * 0.25)
		var p2 = start_pos + ndir * (dist * 0.75)
		out.start = p1
		out.end = p2
		out.dir = ndir
		out.dist = dist
		return out

	out.start = start_pos + ndir * r_start
	out.end = end_pos - ndir * r_end
	out.dir = ndir
	out.dist = dist
	return out


func setup(data) -> void:
	if typeof(data) == TYPE_DICTIONARY:
		source_id = data.get("source", data.get("from", data.get("from_id", null)))
		target_id = data.get("target", data.get("to", data.get("to_id", null)))
		weight = float(data.get("weight", 1.0))
		flux = int(data.get("flux", 0))
	elif typeof(data) == TYPE_ARRAY and data.size() >= 2:
		source_id = data[0]
		target_id = data[1]
		weight = float(data[2]) if data.size() > 2 else 1.0
		flux = int(data[3]) if data.size() > 3 else 0
	
	# Adjust line width based on weight
	if has_node("Line2D"):
		var line: Line2D = $Line2D
		line.width = BASE_WIDTH + min(weight * 0.5, MAX_WIDTH - BASE_WIDTH)
	
	_update_label()


func set_node_references(source: Node2D, target: Node2D) -> void:
	source_node = source
	target_node = target
	update_line()


func update_line() -> void:
	if not source_node or not target_node:
		return
	
	if not has_node("Line2D"):
		return
	
	var line: Line2D = $Line2D

	var pts = _compute_clipped_endpoints()
	if not pts.has("start"):
		return
	var local_start = to_local(pts.start)
	var local_end = to_local(pts.end)
	line.points = PackedVector2Array([local_start, local_end])


func set_state(new_state: String) -> void:
	if not has_node("Line2D"):
		return
	
	var line: Line2D = $Line2D
	var new_color: Color
	match new_state:
		"visited":
			new_color = Color(0.4, 0.8, 0.4, 0.9)
		"active":
			new_color = Color(1.0, 0.8, 0.0, 1.0)
		"highlighted":
			new_color = Color(1.0, 0.5, 0.0, 1.0)
		_:
			new_color = Color(0.5, 0.5, 0.5, 0.8)
	
	line.default_color = new_color
	
	# Update arrow color to match
	if has_node("Arrow"):
		$Arrow.color = new_color


func set_label_mode(mode: String) -> void:
	label_mode = mode
	_update_label()


func set_show_direction(enabled: bool) -> void:
	show_direction = enabled
	if has_node("Arrow"):
		$Arrow.visible = enabled
	_update_arrow()


func _update_label() -> void:
	if not has_node("Label"):
		return
	
	var label: Label = $Label
	match label_mode:
		"none":
			label.visible = false
		"weight":
			label.visible = true
			label.text = "%.1f" % weight
		"flux":
			label.visible = true
			label.text = "%d" % flux
		"both":
			label.visible = true
			label.text = "%d/%.1f" % [flux, weight]
		_:
			label.visible = false
	
	_update_label_position()


func _update_label_position() -> void:
	if not has_node("Label") or not source_node or not target_node:
		return
	
	var label: Label = $Label
	var pts = _compute_clipped_endpoints()
	if not pts.has("start"):
		return

	var midpoint = (pts.start + pts.end) / 2.0
	label.global_position = midpoint - Vector2(label.size.x / 2.0, label.size.y / 2.0)


func _update_arrow() -> void:
	if not has_node("Arrow") or not show_direction:
		return
	
	if not source_node or not target_node:
		return
	
	var arrow: Polygon2D = $Arrow
	var pts = _compute_clipped_endpoints()
	if not pts.has("start"):
		return

	var direction = pts.dir
	# Position arrow slightly before the target border
	var arrow_pos = pts.end - direction * min(12.0, pts.dist * 0.1)
	arrow.global_position = arrow_pos

	# Rotate arrow to point in the direction of the edge
	arrow.rotation = direction.angle()
	
	# Match arrow color with line color
	if has_node("Line2D"):
		arrow.color = $Line2D.default_color


func _process(_delta: float) -> void:
	# Update line position each frame if nodes exist
	if source_node and target_node:
		update_line()
		if label_mode != "none":
			_update_label_position()
		if show_direction:
			_update_arrow()
