class_name RelationshipComponent
extends Node

const Relationship = preload("res://scripts/entities/Relationship.gd")
const SocialGraphManager = preload("res://scripts/systems/SocialGraphManager.gd")

signal relationship_broken(partner_id)

@export var owner_id: int = -1
@export var break_threshold: float = 0.0

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

# Retrieves a single relationship by partner identifier if available.
func get_relationship(partner_id: int) -> Relationship:
	return relationships.get(partner_id, null)

# Stores an externally provided relationship resource, syncing it with the global graph.
func store_relationship(partner_id: int, relationship: Relationship) -> void:
	if owner_id == -1 or partner_id == -1 or relationship == null:
		return
	var stored: Relationship = relationship.duplicate(true)
	if stored.affinity < break_threshold:
		break_relationship(partner_id)
		return
	stored.partner_id = partner_id
	relationships[partner_id] = stored
	_update_graph_affinity(partner_id, stored.affinity)

# Adds or overwrites a relationship entry and synchronizes the global graph.
func add_relationship(partner_id: int, affinity: float) -> void:
	if owner_id == -1 or partner_id == -1:
		return
	if affinity < break_threshold:
		if social_graph_manager:
			social_graph_manager.remove_connection(owner_id, partner_id)
		return
	var relationship: Relationship = _instantiate_relationship(partner_id, affinity)
	relationships[partner_id] = relationship
	_update_graph_affinity(partner_id, affinity)

# Adjusts affinity for an existing relationship and breaks it if it crosses the threshold.
func update_affinity(partner_id: int, delta: float) -> void:
	if not relationships.has(partner_id):
		if delta <= break_threshold:
			return
		add_relationship(partner_id, delta)
		return
	var relationship: Relationship = relationships[partner_id]
	relationship.affinity += delta
	if relationship.affinity < break_threshold:
		break_relationship(partner_id)
		return
	_update_graph_affinity(partner_id, relationship.affinity)

# Removes the relationship, updates the graph, and emits a signal for listeners.
func break_relationship(partner_id: int) -> void:
	if not relationships.has(partner_id):
		return
	relationships.erase(partner_id)
	if social_graph_manager:
		social_graph_manager.remove_connection(owner_id, partner_id)
	emit_signal("relationship_broken", partner_id)

# Internal helper to read the authoritative state from the social graph manager.
func refresh_from_graph() -> void:
	_refresh_from_graph()

func _refresh_from_graph() -> void:
	if not social_graph_manager or owner_id == -1:
		return
	relationships.clear()
	var graph_snapshot: Dictionary = social_graph_manager.get_relationships_for(owner_id)
	for partner_id in graph_snapshot.keys():
		var relationship: Relationship = _instantiate_relationship(partner_id, graph_snapshot[partner_id])
		relationships[partner_id] = relationship

func _instantiate_relationship(partner_id: int, affinity: float) -> Relationship:
	var relationship: Relationship
	if default_relationship_template:
		relationship = default_relationship_template.duplicate(true)
	else:
		relationship = Relationship.new()
	relationship.partner_id = partner_id
	relationship.affinity = affinity
	return relationship

func _update_graph_affinity(partner_id: int, affinity: float) -> void:
	if not social_graph_manager:
		return
	if affinity < break_threshold:
		break_relationship(partner_id)
		return
	social_graph_manager.add_connection(owner_id, partner_id, affinity)
