extends Node

@onready var social_manager: SocialGraphManager = $SocialGraphManager

## Demuestra interacciones básicas entre NPCs utilizando SocialGraphManager.
func example_basic_interaction() -> void:
	var guard := NPC.new()
	guard.npc_id = 1
	guard.npc_name = "Guard"
	var merchant := NPC.new()
	merchant.npc_id = 2
	merchant.npc_name = "Merchant"

	social_manager.ensure_npc(guard, {"faction": "city_watch"})
	social_manager.ensure_npc(merchant, {"faction": "traders_guild"})
	social_manager.register_interaction(guard, merchant, 5.0)
	var affinity = social_manager.social_graph.get_edge(guard, merchant)
	print("Affinity: ", affinity)


## Guarda y carga el grafo social aprovechando compresión opcional.
func example_save_load() -> void:
	var graph := social_manager.social_graph
	var error := graph.save_to_file("user://social_graph.dat", true)
	if error != OK:
		push_error("Failed to save: " + str(error))
		return

	graph.clear()
	error = graph.load_from_file("user://social_graph.dat")
	if error != OK:
		push_error("Failed to load: " + str(error))
		return

	for npc in _get_all_npcs():
		graph.register_loaded_npc(npc)


## Lanza consultas avanzadas sobre el grafo social.
func example_advanced_queries() -> void:
	var guard := social_manager.get_npc_by_id(1)
	var merchant := social_manager.get_npc_by_id(2)
	if guard == null or merchant == null:
		return

	var relations: Dictionary = social_manager.get_relationships_for_ids(guard)
	print("Relationships: ", relations)

	var top: Array = social_manager.social_graph.get_top_relations(guard, 5)
	for relation in top:
		print("Friend: ", relation.get("key"), " Affinity: ", relation.get("weight"))

	var validation: Dictionary = social_manager.validate_graph()
	print("Graph valid: ", validation.get("valid", false))
	print("Validation stats: ", validation.get("stats", {}))


## Demuestra el decaimiento temporal y la limpieza de nodos inválidos.
func example_decay_and_cleanup() -> void:
	social_manager.social_graph.decay_rate_per_second = 2.0
	var decay_stats: Dictionary = social_manager.apply_decay(5.0)
	print("Decay stats: ", decay_stats)
	var removed: int = social_manager.cleanup_invalid_nodes()
	print("Invalid NPCs removed: ", removed)


func _get_all_npcs() -> Array[NPC]:
	var npcs: Array[NPC] = []
	for child in get_tree().get_nodes_in_group("NPCs"):
		if child is NPC:
			npcs.append(child)
	return npcs
