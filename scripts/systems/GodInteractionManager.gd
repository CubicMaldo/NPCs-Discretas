class_name GodInteractionManager
extends Node

## System that allows the player to influence the simulation ("God Powers").
## Listens for node selection in the SocialGraphPanel and applies effects.

@export var bless_amount: float = 15.0
@export var curse_amount: float = -15.0

var selected_nodes: Array = []
var social_graph_manager: SocialGraphManager
var log_controller: LogController

func _ready() -> void:
	# Wait for scene to initialize
	await get_tree().process_frame
	
	social_graph_manager = get_tree().get_first_node_in_group("social_graph_manager")
	
	# Find LogController (assuming it's in the scene)
	var unified_panel = get_tree().root.find_child("UnifiedUIPanel", true, false)
	if unified_panel:
		log_controller = unified_panel.log_controller
		# Connect to node selection from unified panel
		if unified_panel.has_signal("node_selected"):
			unified_panel.node_selected.connect(_on_node_selected)
			_log("God Mode active. Select 2 nodes in the graph to influence them.")
	else:
		push_warning("GodInteractionManager: UnifiedUIPanel not found.")

func _input(event: InputEvent) -> void:
	if selected_nodes.size() < 2:
		return
		
	if event.is_action_pressed("ui_accept"): # Enter/Space to Bless
		_apply_influence(bless_amount, "Blessed")
	elif event.is_action_pressed("ui_cancel"): # Esc/Back to Curse (or maybe define custom keys)
		# Using ui_cancel might be risky if it closes menus. Let's use keys directly for now or standard actions.
		# For this prototype, let's say 'B' for Bless and 'C' for Curse if mapped, or just use simple logic.
		pass

func _unhandled_key_input(event: InputEvent) -> void:
	if selected_nodes.size() < 2:
		return
	
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_B:
			_apply_influence(bless_amount, "Blessed")
		elif event.keycode == KEY_C:
			_apply_influence(curse_amount, "Cursed")

func _on_node_selected(node_id) -> void:
	if node_id in selected_nodes:
		selected_nodes.erase(node_id)
		_log("Deselected %s" % str(node_id))
	else:
		selected_nodes.append(node_id)
		_log("Selected %s" % str(node_id))
		
	if selected_nodes.size() > 2:
		var _removed = selected_nodes.pop_front()
		# _log("Deselected %s (limit 2)" % str(removed))
	
	if selected_nodes.size() == 2:
		_log("[color=yellow]Ready to influence: %s <-> %s. Press 'B' to Bless, 'C' to Curse.[/color]" % [str(selected_nodes[0]), str(selected_nodes[1])])

func _apply_influence(amount: float, type: String) -> void:
	if selected_nodes.size() != 2:
		return
		
	var a = selected_nodes[0]
	var b = selected_nodes[1]
	
	if social_graph_manager:
		# Apply mutual influence
		# We need to get current familiarity to add delta, or just use set_familiarity if we want absolute?
		# The prompt implies "influence", so delta is better.
		# But SocialGraphManager doesn't have "update_familiarity_mutual".
		# We can use the NPC's social component if we can find the NPC, OR just use get/set in manager.
		var current_ab = social_graph_manager.get_familiarity(a, b)
		var current_ba = social_graph_manager.get_familiarity(b, a)
		
		social_graph_manager.set_familiarity(a, b, current_ab + amount)
		social_graph_manager.set_familiarity(b, a, current_ba + amount)
		
		# Log it
		var color = "green" if amount > 0 else "red"
		_log("[color=%s]God Power: %s relationship between %s and %s.[/color]" % [color, type, str(a), str(b)])
		
		# Clear selection? Maybe keep it for repeated influence.
		# selected_nodes.clear()

func _log(msg: String) -> void:
	if log_controller:
		log_controller.log_message(msg)
	else:
		print("[GodMode] " + msg)
