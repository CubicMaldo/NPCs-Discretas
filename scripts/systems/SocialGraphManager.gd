class_name SocialGraphManager
extends Node

var adjacency: Dictionary = {}

# Registers high-level interaction events; can be expanded for analytics or decay logic.
func register_interaction(_npc_a, _npc_b) -> void:
	pass

# Returns the neighbor dictionary for a given NPC id.
func get_relationships_for(npc_id: int) -> Dictionary:
	if not adjacency.has(npc_id):
		return {}
	return adjacency[npc_id].duplicate()

# Adds or updates a bidirectional connection; negative weights remove the edge.
func add_connection(a_id: int, b_id: int, affinity: float) -> void:
	if a_id == b_id:
		return
	if affinity < 0.0:
		remove_connection(a_id, b_id)
		return
	_adj_insert(a_id, b_id, affinity)
	_adj_insert(b_id, a_id, affinity)

# Removes a bidirectional connection from the graph.
func remove_connection(a_id: int, b_id: int) -> void:
	if adjacency.has(a_id):
		adjacency[a_id].erase(b_id)
		if adjacency[a_id].is_empty():
			adjacency.erase(a_id)
	if adjacency.has(b_id):
		adjacency[b_id].erase(a_id)
		if adjacency[b_id].is_empty():
			adjacency.erase(b_id)

# Internal helper to insert an edge endpoint.
func _adj_insert(source_id: int, target_id: int, affinity: float) -> void:
	if not adjacency.has(source_id):
		adjacency[source_id] = {}
	adjacency[source_id][target_id] = affinity
