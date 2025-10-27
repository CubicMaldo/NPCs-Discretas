class_name RelationshipComponent
extends Node

signal relationship_broken(partner_id)

@export var owner_id: int = -1
@export var break_threshold: float = 0.0

# Store relationships keyed by either NPC object (preferred) or int id.
var relationships: Dictionary = {}
var social_graph_manager: SocialGraphManager
var default_relationship_template: Relationship

# Allows dependency injection for the global social graph manager.
func set_graph_manager(manager: SocialGraphManager) -> void:
	social_graph_manager = manager
	_refresh_from_graph()

# Sets the default template used when instantiating new relationships.
func set_default_relationship(template: Relationship) -> void:
	default_relationship_template = template

# Returns a shallow copy, preserving encapsulation of internal structures.
func get_relationships() -> Dictionary:
	return relationships.duplicate()

func _owner_key():
	var p = get_parent()
	if p is NPC:
		return p
	if owner_id != -1:
		return owner_id
	return null

func _partner_key_for(partner) -> Variant:
	if partner is NPC:
		return partner
	if typeof(partner) == TYPE_INT:
		return int(partner)
	push_error("RelationshipComponent: partner must be NPC object with npc_id or int id")
	return null

func _partner_id_from_key(k) -> int:
	if k is NPC:
		return int(k.npc_id)
	elif typeof(k) == TYPE_INT:
		return int(k)
	return -1

# Retrieves a single relationship by partner reference or id if available.
func get_relationship(partner) -> Relationship:
	var k = _partner_key_for(partner)
	if k == null:
		return null
	return relationships.get(k, null)

# Stores an externally provided relationship resource, syncing it with the global graph.
func store_relationship(partner, relationship: Relationship) -> void:
	var k = _partner_key_for(partner)
	var owner_key = _owner_key()
	if relationship == null or k == null or owner_key == null:
		return
	var stored: Relationship = relationship.duplicate(true)
	if stored.affinity < break_threshold:
		break_relationship(k)
		return
	stored.partner_id = _partner_id_from_key(k)
	relationships[k] = stored
	_update_graph_affinity(k, stored.affinity)

# Adds or overwrites a relationship entry and synchronizes the global graph.
func add_relationship(partner, affinity: float) -> void:
	var k = _partner_key_for(partner)
	var owner_key = _owner_key()
	if k == null or owner_key == null:
		return
	if affinity < break_threshold:
		if social_graph_manager:
			social_graph_manager.remove_connection(owner_key, k)
		return
	var relationship: Relationship = _instantiate_relationship(k, affinity)
	relationships[k] = relationship
	_update_graph_affinity(k, affinity)

# Adjusts affinity for an existing relationship and breaks it if it crosses the threshold.
func update_affinity(partner, delta: float) -> void:
	var k = _partner_key_for(partner)
	if k == null:
		return
	if not relationships.has(k):
		if delta <= break_threshold:
			return
		add_relationship(k, delta)
		return
	var relationship: Relationship = relationships[k]
	relationship.affinity += delta
	if relationship.affinity < break_threshold:
		break_relationship(k)
		return
	_update_graph_affinity(k, relationship.affinity)

# Removes the relationship, updates the graph, and emits a signal for listeners.
func break_relationship(partner) -> void:
	var k = _partner_key_for(partner)
	if k == null or not relationships.has(k):
		return
	relationships.erase(k)
	var owner_key = _owner_key()
	if social_graph_manager and owner_key != null:
		social_graph_manager.remove_connection(owner_key, k)
	emit_signal("relationship_broken", _partner_id_from_key(k))

# Internal helper to read the authoritative state from the social graph manager.
func refresh_from_graph() -> void:
	_refresh_from_graph()

func _refresh_from_graph() -> void:
	if not social_graph_manager:
		return
	var owner_key = _owner_key()
	if owner_key == null:
		return
	relationships.clear()
	var graph_snapshot: Dictionary = social_graph_manager.get_relationships_for(owner_key)
	for partner_id in graph_snapshot.keys():
		var relationship: Relationship = _instantiate_relationship(partner_id, graph_snapshot[partner_id])
		relationships[partner_id] = relationship

func _instantiate_relationship(partner_key, affinity: float) -> Relationship:
	var relationship: Relationship
	if default_relationship_template:
		relationship = default_relationship_template.duplicate(true)
	else:
		relationship = Relationship.new()
	relationship.partner_id = _partner_id_from_key(partner_key)
	relationship.affinity = affinity
	return relationship

func _update_graph_affinity(partner_key, affinity: float) -> void:
	if not social_graph_manager:
		return
	if affinity < break_threshold:
		break_relationship(partner_key)
		return
	var owner_key = _owner_key()
	if owner_key == null:
		return
	social_graph_manager.add_connection(owner_key, partner_key, affinity)
