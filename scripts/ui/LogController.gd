class_name LogController
extends Control

@onready var rich_text_label: RichTextLabel = $ScrollContainer/RichTextLabel

var social_graph_manager: SocialGraphManager

func _ready() -> void:
	# Find the manager if not injected
	if not social_graph_manager:
		social_graph_manager = get_tree().get_first_node_in_group("social_graph_manager")
	
	if social_graph_manager:
		social_graph_manager.interaction_registered.connect(_on_interaction)
		social_graph_manager.interaction_registered_ids.connect(_on_interaction_ids)
		log_message("[color=yellow]System initialized.[/color]")
	else:
		log_message("[color=red]Error: SocialGraphManager not found.[/color]")

func log_message(bbcode: String) -> void:
	if not rich_text_label:
		return
	
	var time = Time.get_time_string_from_system()
	rich_text_label.append_text("[color=gray][%s][/color] %s\n" % [time, bbcode])

func _on_interaction(a, b, new_familiarity, options = {}) -> void:
	var a_name = str(a)
	var b_name = str(b)
	
	if a is NPC: a_name = a.npc_name
	if b is NPC: b_name = b.npc_name
	
	var type = options.get("type", "interacted")
	var result = options.get("result", "")
	
	var color = "white"
	if type == "fight": color = "red"
	elif type == "talk":
		color = "green" if result != "bad" else "orange"
	
	var msg = "[color=%s]%s %s with %s[/color]" % [color, a_name, type, b_name]
	if result == "bad":
		msg += " (Bad outcome)"
	
	msg += ". New fam: %.1f" % new_familiarity
	log_message(msg)

func _on_interaction_ids(a_id, b_id, new_familiarity, options = {}) -> void:
	# Fallback for ID-based signals
	var type = options.get("type", "interacted")
	log_message("Interaction (%s) between IDs %s and %s. New fam: %.1f" % [type, a_id, b_id, new_familiarity])
