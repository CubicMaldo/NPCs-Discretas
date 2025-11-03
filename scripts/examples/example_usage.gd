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

	# Crear metadata tipada para los NPCs
	var guard_meta := NPCVertexMeta.new()
	guard_meta.id = 1
	guard_meta.display_name = "Guard"
	guard_meta.role = "warrior"
	guard_meta.faction = "city_watch"
	guard_meta.level = 10
	
	var merchant_meta := NPCVertexMeta.new()
	merchant_meta.id = 2
	merchant_meta.display_name = "Merchant"
	merchant_meta.role = "trader"
	merchant_meta.faction = "traders_guild"
	merchant_meta.level = 5
	
	social_manager.ensure_npc(guard, guard_meta)
	social_manager.ensure_npc(merchant, merchant_meta)
	social_manager.register_interaction(guard, merchant, 5.0)
	var affinity = social_manager.social_graph.get_edge(guard, merchant)
	print("Affinity: ", affinity)
	
	# Acceder a metadata del vértice
	var guard_vertex = social_manager.social_graph.get_vertex_by_npc(guard)
	if guard_vertex and guard_vertex.meta:
		var meta := guard_vertex.meta as NPCVertexMeta
		print("Guard faction: ", meta.faction, " Level: ", meta.level)


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


## Demuestra el uso de metadata personalizada con custom_data.
func example_custom_metadata() -> void:
	var hero := NPC.new()
	hero.npc_id = 10
	hero.npc_name = "Hero"
	
	# Metadata con campos custom adicionales
	var hero_meta := NPCVertexMeta.new()
	hero_meta.id = 10
	hero_meta.display_name = "Hero"
	hero_meta.role = "adventurer"
	hero_meta.faction = "freelance"
	hero_meta.level = 25
	hero_meta.custom_data["reputation"] = 85
	hero_meta.custom_data["quest_count"] = 15
	hero_meta.custom_data["gold"] = 5000
	
	social_manager.ensure_npc(hero, hero_meta)
	
	# Recuperar y usar custom_data
	var vertex = social_manager.social_graph.get_vertex_by_npc(hero)
	if vertex and vertex.meta:
		var meta := vertex.meta as NPCVertexMeta
		print("Hero - Reputation: ", meta.custom_data.get("reputation", 0))
		print("Hero - Quests completed: ", meta.custom_data.get("quest_count", 0))
		print("Hero - Gold: ", meta.custom_data.get("gold", 0))


## Demuestra serialización y deserialización de metadata.
func example_metadata_persistence() -> void:
	var graph := social_manager.social_graph
	
	# Crear NPCs con metadata rica
	var npc1_meta := NPCVertexMeta.new()
	npc1_meta.id = 100
	npc1_meta.display_name = "King"
	npc1_meta.role = "ruler"
	npc1_meta.faction = "royal_court"
	npc1_meta.level = 50
	
	var npc2_meta := NPCVertexMeta.new()
	npc2_meta.id = 101
	npc2_meta.display_name = "Advisor"
	npc2_meta.role = "counselor"
	npc2_meta.faction = "royal_court"
	npc2_meta.level = 40
	
	graph.ensure_npc(100, npc1_meta)
	graph.ensure_npc(101, npc2_meta)
	
	# Crear metadata para la arista con confianza y tipo de relación
	var edge_meta := SocialEdgeMeta.new(95.0, 0.9, "Professional")
	edge_meta.add_tag("royal_court")
	edge_meta.add_tag("advisor_relationship")
	
	graph.connect_npcs(100, 101, 95.0, edge_meta)
	
	# Serializar
	var serialized := graph.serialize()
	print("Serialized vertex metadata: ", serialized["nodes"][0]["meta"])
	print("Serialized edge metadata: ", serialized["edges"][0]["metadata"])
	
	# Deserializar en nuevo grafo
	var new_graph := SocialGraph.new()
	new_graph.deserialize(serialized)
	
	# Verificar que metadata se restauró
	var restored_vertex = new_graph.get_vertex(100)
	if restored_vertex and restored_vertex.meta:
		var meta := restored_vertex.meta as NPCVertexMeta
		print("Restored - Name: ", meta.display_name)
		print("Restored - Role: ", meta.role)
		print("Restored - Faction: ", meta.faction)
		print("Restored - Level: ", meta.level)
		print("Restored - Loaded from save: ", meta.loaded_from_save)


## Demuestra el uso de SocialEdgeMeta para metadata de relaciones.
func example_edge_metadata() -> void:
	var graph := social_manager.social_graph
	
	# Crear NPCs
	graph.ensure_npc(50)
	graph.ensure_npc(51)
	
	# Crear metadata de relación con trust, tipo y tags
	var friendship_meta := SocialEdgeMeta.new(75.0, 0.8, "Friendship")
	friendship_meta.add_tag("childhood_friends")
	friendship_meta.add_tag("same_guild")
	friendship_meta.interaction_count = 150
	
	graph.connect_npcs(50, 51, 75.0, friendship_meta)
	
	# Recuperar metadata de la arista
	var edge = graph.get_edge_resource(50, 51)
	if edge and edge.metadata:
		var meta := edge.metadata as SocialEdgeMeta
		print("Edge metadata:")
		print("  - Relationship type: ", meta.relationship_type)
		print("  - Trust level: ", meta.trust)
		print("  - Interactions: ", meta.interaction_count)
		print("  - Tags: ", meta.tags)
		print("  - Description: ", meta.get_description())
		print("  - Is trusted: ", meta.is_trusted(0.7))
		print("  - Is hostile: ", meta.is_hostile())
	
	# Actualizar metadata basándose en nueva interacción
	if edge and edge.metadata:
		var meta := edge.metadata as SocialEdgeMeta
		meta.update_from_interaction(10.0)  # Interacción positiva
		print("After positive interaction:")
		print("  - New weight: ", edge.weight)
		print("  - New trust: ", meta.trust)
		print("  - Interaction count: ", meta.interaction_count)


func _get_all_npcs() -> Array[NPC]:
	var npcs: Array[NPC] = []
	for child in get_tree().get_nodes_in_group("NPCs"):
		if child is NPC:
			npcs.append(child)
	return npcs
