class_name SocialGraphManager
extends Node

const SocialGraph = preload("res://scripts/systems/SocialGraph.gd")
var social_graph : SocialGraph

# Optionally emit when interactions are registered for analytics/UI hooks.
signal interaction_registered(a_id, b_id, new_affinity)

func _ready() -> void:
	social_graph = SocialGraph.new()

# This implementation tries to compute a small affinity delta using NPC
func register_interaction(_npc_a, _npc_b) -> void:
	var a_meta: Dictionary = {}
	var b_meta: Dictionary = {}

	var ka = social_graph._key_for(_npc_a)
	var kb = social_graph._key_for(_npc_b)
	if ka == null or kb == null or ka == kb:
		return

	# If objects provided, collect meta
	if _npc_a is NPC:
		a_meta["name"] = _npc_a.npc_name
		a_meta["pos"] = _npc_a.current_position
		a_meta["ref"] = _npc_a

	if _npc_b is NPC:
		b_meta["name"] = _npc_b.npc_name
		b_meta["pos"] = _npc_b.current_position
		b_meta["ref"] = _npc_b

	social_graph.ensure_node(ka, a_meta)
	social_graph.ensure_node(kb, b_meta)

	# compute affinity delta using NPC helpers when present
	var delta_a: float = 0.05
	var delta_b: float = 0.05
	if _npc_a is NPC:
		delta_a = float(_npc_a._evaluate_interaction_delta(_npc_b))
	if _npc_b is NPC:
		delta_b = float(_npc_b._evaluate_interaction_delta(_npc_a))

	# current affinity (0 if none)
	var existing_val = social_graph.get_edge(ka, kb)
	var existing: float = 0.0
	if existing_val != null:
		existing = float(existing_val)

	var new_affinity: float = existing + ((delta_a + delta_b) / 2.0)

	social_graph.add_connection(ka, kb, new_affinity)

	interaction_registered.emit(ka, kb, new_affinity)


func get_relationships_for(npc_or_id) -> Dictionary:
	# Manager-level convenience: returns neighbor map keyed by npc_id when possible.
	var raw: Dictionary = social_graph.get_neighbor_weights(npc_or_id)
	var out: Dictionary = {}
	for neighbor in raw.keys():
		var out_key = neighbor
		if neighbor is NPC:
			out_key = int(neighbor.npc_id)
		out[out_key] = raw[neighbor]
	return out
