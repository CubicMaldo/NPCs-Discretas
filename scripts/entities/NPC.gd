class_name NPC
extends CharacterBody2D

@export var npc_id: int = -1
@export var npc_name: String = ""
@export var personality: Personality
@export var base_emotion: Emotion
@export var relationship_archetype: Relationship

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var relationship_component: RelationshipComponent = _ensure_relationship_component()

# State machine: store a Resource-based state (NPCState) instance
@export var default_state: Resource
var current_state = null
var state_elapsed: float = 0.0
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
	# set default state: prefer assigned Resource, otherwise idle
	if default_state:
		set_state(default_state)
	else:
		set_state_by_name("idle")

# Maintains a cached copy of the position for systems that poll less frequently.
func _physics_process(_delta: float) -> void:
	current_position = global_position
	# Delegate to current state
	if current_state and current_state.has_method("physics_process"):
		current_state.physics_process(self, _delta)
		# track how long we've been in this state
		state_elapsed += _delta
		# allow state to suggest next state
		if current_state.has_method("evaluate"):
			var suggestion = current_state.evaluate(self)
			if suggestion and suggestion != current_state:
				try_set_state(suggestion)
			elif suggestion == null and behavior_system:
				# Pull: ask BehaviorSystem for next state suggestion
				var next_state = behavior_system.choose_state_for(self)
				if next_state:
					try_set_state(next_state)

# Handles a direct interaction with another NPC and forwards it to coordinating systems.
func interact_with(other_npc: NPC) -> void:
	if social_graph_manager and social_graph_manager.has_method("register_interaction"):
		social_graph_manager.register_interaction(self, other_npc)
	if behavior_system and behavior_system.has_method("notify_interaction"):
		behavior_system.notify_interaction(self, other_npc)
	var affinity_delta := _evaluate_interaction_delta(other_npc)
	relationship_component.update_affinity(other_npc.npc_id, affinity_delta)
	relationship_component.refresh_from_graph()

# Refreshes the local cache of relationship data using the SocialGraphManager as the source of truth.
func update_relationships() -> void:
	if social_graph_manager and social_graph_manager.has_method("get_relationships_for"):
		relationship_component.refresh_from_graph()

# Requests the BehaviorSystem to determine the next action, storing the resulting state for later use.
func choose_action() -> String:
	if behavior_system:
		return behavior_system.choose_action_for(self)
	return "idle"

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

# Derives an interaction delta leveraging current emotions and any existing affinity data.
func _evaluate_interaction_delta(other_npc: NPC) -> float:
	var baseline := 0.05
	if current_emotion:
		baseline += current_emotion.intensity * 0.05
	var existing := relationship_component.get_relationship(other_npc.npc_id)
	if existing:
		baseline += existing.affinity * 0.02
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


# Set state by passing a Resource instance or a pre-initialized state.
func set_state(new_state: Resource) -> void:
	if not new_state:
		return
	var instance = new_state
	# Duplicate Resource to avoid shared mutable state between NPCs
	if instance is Resource:
		instance = new_state.duplicate(true)
	if current_state and current_state.has_method("exit"):
		current_state.exit(self)
	current_state = instance
	if current_state and current_state.has_method("enter"):
		current_state.enter(self)
	# reset elapsed time for cooldowns
	state_elapsed = 0.0

func try_set_state(new_state: Resource, force: bool = false) -> void:
	if not new_state:
		return
	# prepare instance
	var instance = new_state
	if instance is Resource:
		instance = new_state.duplicate(true)
	# determine priorities
	var new_prio: int = 0
	if instance and instance.has_property("priority"):
		new_prio = int(instance.priority)
	var cur_prio: int = 0
	if current_state and current_state.has_property("priority"):
		cur_prio = int(current_state.priority)
	# respect priority unless forced
	if current_state and not force:
		if new_prio < cur_prio:
			return
		# check min_duration if present
		if current_state.has_property("min_duration"):
			var elapsed: float = state_elapsed
			var min_d: float = float(current_state.min_duration)
			if elapsed < min_d:
				return
	# apply state
	set_state(instance)

func set_state_by_name(state_name: String) -> void:
	match state_name:
		"idle":
			var s = preload("res://scripts/states/IdleState.gd").new()
			set_state(s)
		"walk":
			var s = preload("res://scripts/states/WalkState.gd").new()
			set_state(s)
		"interact":
			var s = preload("res://scripts/states/InteractState.gd").new()
			set_state(s)
		_: # fallback
			var s = preload("res://scripts/states/IdleState.gd").new()
			set_state(s)
