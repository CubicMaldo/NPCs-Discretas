class_name UnifiedUIController
extends Control

## Unified UI panel controller that manages visibility and tab switching.

signal node_selected(node_id)

@onready var panel: Panel = $Panel
@onready var tab_container: TabContainer = $Panel/MarginContainer/VBoxContainer/TabContainer
@onready var log_controller: LogController = $Panel/MarginContainer/VBoxContainer/TabContainer/Log/LogController
@onready var graph_display: Node2D = $Panel/MarginContainer/VBoxContainer/TabContainer/Graph/SubViewportContainer/SubViewport/GraphDisplay
@onready var toggle_button: Button = $ToggleButton

var panel_visible: bool = false
var social_graph_manager: SocialGraphManager

func _ready() -> void:
	# Initialize
	toggle_button.pressed.connect(_on_toggle_pressed)
	
	# Find social graph manager
	social_graph_manager = get_tree().get_first_node_in_group("social_graph_manager")
	
	# Connect graph display signals if available
	if graph_display and graph_display.has_signal("node_selected"):
		graph_display.node_selected.connect(_on_node_selected)

func _on_toggle_pressed() -> void:
	panel_visible = !panel_visible
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	if panel_visible:
		panel.visible = true
		tween.tween_property(panel, "modulate:a", 1.0, 0.3)
		toggle_button.text = "Hide UI"
		_refresh_graph()
	else:
		tween.tween_property(panel, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func(): panel.visible = false)
		toggle_button.text = "Show UI"

func _refresh_graph() -> void:
	if social_graph_manager and social_graph_manager.social_graph and graph_display:
		graph_display.display_graph(social_graph_manager.social_graph)

func _on_node_selected(node_id) -> void:
	node_selected.emit(node_id)
