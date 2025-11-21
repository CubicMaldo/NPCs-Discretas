extends Control

@onready var sub_viewport = $Panel/VBoxContainer/SubViewportContainer/SubViewport
@onready var graph_display = $Panel/VBoxContainer/SubViewportContainer/SubViewport/GraphDisplay
@onready var panel = $Panel

var is_panel_visible: bool = false

func _ready() -> void:
	# Initialize panel off-screen (right side)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = 0
	panel.offset_right = 400 # Width of panel
	
func toggle_visibility() -> void:
	is_panel_visible = !is_panel_visible
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	if is_panel_visible:
		_refresh_graph()
		# Slide in: move anchor_left to 1.0 - (400 / screen_width) roughly, 
		# or just use fixed offsets relative to right anchor
		tween.tween_property(panel, "offset_left", -400.0, 0.4)
	else:
		# Slide out
		tween.tween_property(panel, "offset_left", 0.0, 0.4)


func _refresh_graph() -> void:
	# Find the SocialGraphManager in the scene
	var graph_manager = get_tree().get_first_node_in_group("social_graph_manager")
	if graph_manager and graph_manager.social_graph:
		print("SocialGraphPanel: Found SocialGraphManager. Displaying graph...")
		graph_display.display_graph(graph_manager.social_graph)
	else:
		print("SocialGraphPanel: No SocialGraphManager found (or no graph).")
