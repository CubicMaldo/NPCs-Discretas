extends Node2D

@onready var social_graph_manager: SocialGraphManager = $SocialGraphManager
@onready var camera: Camera2D = $Camera2D

func _ready() -> void:
	# Ensure the manager is ready
	if not social_graph_manager:
		push_error("Main: SocialGraphManager node is missing!")
		return
		
	print("[Main] Initializing simulation...")
	
	# Find all existing NPCs in the scene and inject dependencies
	var _npcs = get_tree().get_nodes_in_group("npc") # Assuming NPCs are in this group, or we iterate children

	
	# If not using groups, iterate children
	for child in get_children():
		if child is NPC:
			_setup_npc(child)
			
	# Connect to future spawns if you have a spawner
	# ...
	
	var btn = $CanvasLayer/DebugButton
	if btn:
		btn.pressed.connect(_on_debug_button_pressed)

func _on_debug_button_pressed() -> void:
	print("\n--- SOCIAL GRAPH CONNECTIONS ---")
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		var neighbors = social_graph_manager.get_cached_neighbors(npc)
		print("NPC: %s" % npc.name)
		if neighbors.is_empty():
			print("  -> No connections.")
		else:
			for neighbor in neighbors:
				var score = social_graph_manager.get_familiarity(npc, neighbor)
				print("  -> Connected to %s (Familiarity: %.2f)" % [neighbor.name, score])
	print("--------------------------------\n")

func _setup_npc(npc: NPC) -> void:
	print("[Main] Setting up NPC: ", npc.name)
	npc.set_systems(social_graph_manager)
	
	# Optional: Randomize position if they are all at 0,0
	# if npc.global_position == Vector2.ZERO:
	# 	npc.global_position = Vector2(randf_range(100, 500), randf_range(100, 300))
