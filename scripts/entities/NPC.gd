class_name NPC
extends CharacterBody2D

@export var npc_id: int = -1
@export var npc_name: String = ""
@export var personality: Personality
@export var base_emotion: Emotion
@export var relationship_archetype: Relationship

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var relationship_component: RelationshipComponent = _ensure_relationship_component()

var current_state: String = "idle"
var current_emotion: Emotion
var current_position: Vector2 = Vector2.ZERO

var social_graph_manager: SocialGraphManager
var behavior_system: BehaviorSystem

# Initializes runtime state and ensures component references are ready for use.
func _ready() -> void:
	current_position = global_position
	current_emotion = _instantiate_emotion()
	relationship_component.owner_id = npc_id
	relationship_component.set_default_relationship(relationship_archetype)
	if social_graph_manager:
		relationship_component.set_graph_manager(social_graph_manager)
	update_relationships()

# Maintains a cached copy of the position for systems that poll less frequently.
func _physics_process(_delta: float) -> void:
	current_position = global_position

# Handles a direct interaction with another NPC and forwards it to coordinating systems.
func interact_with(other_npc: NPC) -> void:
	if social_graph_manager and social_graph_manager.has_method("register_interaction"):
		social_graph_manager.register_interaction(self, other_npc)
	if behavior_system and behavior_system.has_method("notify_interaction"):
		behavior_system.notify_interaction(self, other_npc)
	var familiarity_delta := _evaluate_interaction_delta(other_npc)
	relationship_component.update_familiarity(other_npc.npc_id, familiarity_delta)
	relationship_component.refresh_from_graph()

# Refreshes the local cache of relationship data using the SocialGraphManager as the source of truth.
func update_relationships() -> void:
	if social_graph_manager and social_graph_manager.has_method("get_relationships_for"):
		relationship_component.refresh_from_graph()

# Requests the BehaviorSystem to determine the next action, storing the resulting state for later use.
func choose_action() -> String:
	if behavior_system:
		current_state = behavior_system.choose_action_for(self)
	else:
		current_state = "idle"
	return current_state

# Allows external systems to inject dependencies after the node is instantiated.
func set_systems(graph_manager: SocialGraphManager, behavior: BehaviorSystem) -> void:
	social_graph_manager = graph_manager
	behavior_system = behavior
	if relationship_component:
		relationship_component.owner_id = npc_id
		relationship_component.set_graph_manager(graph_manager)
		relationship_component.refresh_from_graph()

# Registers or updates a specific relationship entry within the local cache.
func set_relationship(target_id: int, relationship: Relationship) -> void:
	if not relationship_component:
		return
	relationship_component.store_relationship(target_id, relationship)

# Creates a mutable emotion instance so the NPC can adjust feelings over time without touching the template.
func _instantiate_emotion() -> Emotion:
	if base_emotion:
		return base_emotion.duplicate(true)
	return Emotion.new()

# Derives an interaction delta leveraging current emotions and any existing familiarity data.
func _evaluate_interaction_delta(other_npc: NPC) -> float:
	var baseline := 0.05
	if current_emotion:
		baseline += current_emotion.intensity * 0.05
	var existing := relationship_component.get_relationship(other_npc.npc_id)
	if existing:
		baseline += existing.familiarity * 0.02
	return baseline

# Ensures the NPC always has a relationship component child to delegate social data storage.
func _ensure_relationship_component() -> RelationshipComponent:
	var existing := get_node_or_null("RelationshipComponent")
	if existing:
		return existing as RelationshipComponent
	var component := RelationshipComponent.new()
	component.name = "RelationshipComponent"
	add_child(component)
	return component

# Exposes a snapshot of relationships for systems that consume social context.
func get_relationship_snapshot() -> Dictionary:
	return relationship_component.get_relationships()

# Provides the active relationship component instance.
func get_relationship_component() -> RelationshipComponent:
	return relationship_component
