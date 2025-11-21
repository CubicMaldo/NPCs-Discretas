extends Node2D
## NodeView: visual representation of a graph vertex
## Supports multiple states (unvisited, current, visited, root) with color coding
## Modular component that reacts to state changes independently of mission logic

signal node_selected(node_id)

var node_id = null
var node_meta = null
var current_state: String = "unvisited"

# State colors
const STATE_COLORS := {
	"unvisited": Color(0.2, 0.6, 0.8, 1.0),     # Azul
	"current": Color(1.0, 0.8, 0.0, 1.0),       # Amarillo
	"visited": Color(0.4, 0.8, 0.4, 1.0),       # Verde
	"root": Color(0.9, 0.2, 0.2, 1.0),          # Rojo
	"candidate": Color(0.45, 0.55, 1.0, 1.0),   # Azul brillante (nodo sugerido)
	"candidate_secondary": Color(0.45, 0.55, 1.0, 1.0), # Igual que candidate para mantener la intriga
	"highlighted": Color(1.0, 0.5, 0.0, 1.0),   # Naranja
	"source": Color(0.75, 0.35, 1.0, 1.0),      # Lila para nodo fuente
	"sink": Color(0.25, 1.0, 0.7, 1.0),         # Verde aqua para sumidero
	"flow": Color(0.2, 0.9, 0.95, 1.0),         # Cian para nodos en rutas de flujo
	"saturated": Color(1.0, 0.3, 0.3, 1.0)      # Rojo saturado para nodos en corte
}


func setup(data) -> void:
	# data may be a Dictionary {"id":..., "meta":...} or a simple value
	if typeof(data) == TYPE_DICTIONARY:
		node_id = data.get("id", null)
		node_meta = data.get("meta", null)
	else:
		node_id = data
	
	# Set label text
	var display_text = str(node_id)
	if node_meta:
		if typeof(node_meta) == TYPE_OBJECT:
			# node_meta is a Resource (VertexMeta) or Object with property display_name
			if str(node_meta.display_name) != "":
				display_text = node_meta.display_name
		elif typeof(node_meta) == TYPE_DICTIONARY and node_meta.has("display_name"):
			if str(node_meta["display_name"]) != "":
				display_text = str(node_meta["display_name"])
		%Label.text = display_text
	
	# Initialize visual state
	set_state("unvisited")


func set_state(new_state: String) -> void:
	if new_state == current_state:
		return
	
	current_state = new_state
	var color = STATE_COLORS.get(new_state, STATE_COLORS["unvisited"])
	
	# Update circle color
	# Support multiple possible shape node names (Circle / Octagon) or fallback to modulate
	if has_node("Circle"):
		$Circle.color = color
	elif has_node("Octagon"):
		$Octagon.color = color
	else:
		# fallback: tint the root Node2D or first CanvasItem child
		if has_method("set_modulate"):
			self.modulate = color
			return
		for child in get_children():
			if typeof(child) == TYPE_OBJECT and child is CanvasItem:
				child.modulate = color
				break
	
	# Add scale animation for emphasis
	if new_state == "current" or new_state == "root" or new_state == "candidate":
		_animate_pulse()


func show_clue(clue_text: String) -> void:
	if has_node("ClueLabel"):
		$ClueLabel.text = clue_text
		$ClueLabel.visible = true


func hide_clue() -> void:
	if has_node("ClueLabel"):
		$ClueLabel.visible = false


func _animate_pulse() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.3)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)


func _unhandled_input(event) -> void:
	if node_id == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_pos: Vector2 = to_local(event.position)
		if local_pos.length() <= 36.0:
			emit_signal("node_selected", node_id)
