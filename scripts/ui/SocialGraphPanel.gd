extends Control

@onready var sub_viewport = $Panel/SubViewportContainer/SubViewport
@onready var graph_display = $Panel/SubViewportContainer/SubViewport/GraphDisplay
@onready var panel = $Panel

var is_visible: bool = false

func _ready() -> void:
	panel.visible = false
	
func toggle_visibility() -> void:
	is_visible = !is_visible
	panel.visible = is_visible
	
	if is_visible:
		_refresh_graph()

func _refresh_graph() -> void:
	# Find the SocialGraphManager in the scene
	var graph_manager = get_tree().get_first_node_in_group("social_graph_manager")
	if graph_manager and graph_manager.social_graph:
		graph_display.display_graph(graph_manager.social_graph)
	else:
		print("SocialGraphPanel: No SocialGraphManager found.")
