class_name SocialGraphManager
extends "res://scripts/utils/Graph.gd"

# Optionally emit when interactions are registered for analytics/UI hooks.
signal interaction_registered(a_id, b_id, new_affinity)

func _ready() -> void:
	# ensure Graph node lifecycle continues to work
	pass

# Registers a high-level interaction between two NPCs (or ids).
# This implementation tries to compute a small affinity delta using NPC
# helpers if available and updates the bidirectional affinity accordingly.
func register_interaction(_npc_a, _npc_b) -> void:
	var a_meta: Dictionary = {}
	var b_meta: Dictionary = {}

	var ka = _key_for(_npc_a)
	var kb = _key_for(_npc_b)
	if ka == null or kb == null or ka == kb:
		return

	# If objects provided, collect meta
	if typeof(_npc_a) == TYPE_OBJECT and _npc_a != null:
		if _npc_a.has_variable("npc_name"):
			a_meta["name"] = _npc_a.npc_name
		if _npc_a.has_variable("current_position"):
			a_meta["pos"] = _npc_a.current_position
		a_meta["ref"] = _npc_a

	if typeof(_npc_b) == TYPE_OBJECT and _npc_b != null:
		if _npc_b.has_variable("npc_name"):
			b_meta["name"] = _npc_b.npc_name
		if _npc_b.has_variable("current_position"):
			b_meta["pos"] = _npc_b.current_position
		b_meta["ref"] = _npc_b

	ensure_node(ka, a_meta)
	ensure_node(kb, b_meta)

	# compute affinity delta using NPC helpers when present
	var delta_a: float = 0.05
	var delta_b: float = 0.05
	if typeof(_npc_a) == TYPE_OBJECT and _npc_a != null and _npc_a.has_method("_evaluate_interaction_delta"):
		delta_a = float(_npc_a._evaluate_interaction_delta(_npc_b))
	if typeof(_npc_b) == TYPE_OBJECT and _npc_b != null and _npc_b.has_method("_evaluate_interaction_delta"):
		delta_b = float(_npc_b._evaluate_interaction_delta(_npc_a))

	# current affinity (0 if none)
	var existing_val = get_edge(ka, kb)
	var existing: float = 0.0
	if existing_val != null:
		existing = float(existing_val)

	var new_affinity: float = existing + ((delta_a + delta_b) / 2.0)

	add_connection(ka, kb, new_affinity)
	emit_signal("interaction_registered", ka, kb, new_affinity)
