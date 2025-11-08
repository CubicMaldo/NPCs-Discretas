class_name NPC
extends CharacterBody2D

## Datos de identidad y configuración
@export var npc_id: int = -1
@export var npc_name: String = ""
@export var personality: Personality
@export var base_emotion: Emotion

## Referencias a componentes
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var social_component: SocialComponent

## Estado actual
var current_state: String = "idle"
var current_emotion: Emotion
var current_position: Vector2 = Vector2.ZERO

## Referencias a sistemas externos (inyección de dependencias)
var social_graph_manager: SocialGraphManager

# Initializes runtime state and ensures component references are ready for use.
func _ready() -> void:
	current_position = global_position
	current_emotion = _instantiate_emotion()
	social_component = _ensure_social_component()
	social_component.owner_id = npc_id
	if social_graph_manager:
		social_component.set_graph_manager(social_graph_manager)

# Maintains a cached copy of the position for systems that poll less frequently.
func _physics_process(_delta: float) -> void:
	current_position = global_position

# Handles a direct interaction with another NPC and forwards it to coordinating systems.
func interact_with(other_npc: NPC) -> void:
	if social_graph_manager and social_graph_manager.has_method("register_interaction"):
		social_graph_manager.register_interaction(self, other_npc)
	
	var familiarity_delta := _evaluate_interaction_delta(other_npc)
	social_component.update_familiarity(other_npc, familiarity_delta)

# Requests an external decision system (provided by an addon) to determine the next action.
func choose_action() -> String:
	# Decision execution is delegated to an external addon; default to idle here.
	current_state = "idle"
	return current_state

# Allows external systems to inject dependencies after the node is instantiated.
func set_systems(graph_manager: SocialGraphManager) -> void:
	social_graph_manager = graph_manager
	if social_component:
		social_component.owner_id = npc_id
		social_component.set_graph_manager(graph_manager)

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
	var existing_familiarity := social_component.get_relationship(other_npc)
	baseline += existing_familiarity * 0.02
	return baseline

# Ensures the NPC always has a social component child to delegate social data access.
func _ensure_social_component() -> SocialComponent:
	var existing := get_node_or_null("SocialComponent")
	if existing:
		return existing as SocialComponent
	var component := SocialComponent.new()
	component.name = "SocialComponent"
	add_child(component)
	return component

## API pública simplificada para acceso a relaciones sociales

# Obtiene la familiaridad con otro NPC (0.0 si no existe relación).
func get_familiarity(partner) -> float:
	return social_component.get_relationship(partner)

# Obtiene todas las relaciones activas.
func get_all_relationships() -> Dictionary:
	return social_component.get_all_relationships()

# Obtiene la relación más fuerte.
func get_strongest_familiarity() -> float:
	return social_component.get_strongest_relationship()

# Obtiene los top N partners por familiaridad.
func get_top_relationships(top_n: int = 3) -> Array:
	return social_component.get_top_relationships(top_n)

# Obtiene amigos con familiaridad por encima de un umbral.
func get_friends_above(threshold: float) -> Array:
	return social_component.get_friends_above(threshold)

# Compatibilidad con código legacy (deprecated, usar get_all_relationships).
func get_relationship_snapshot() -> Dictionary:
	return get_all_relationships()

# Compatibilidad con código legacy (deprecated, usar social_component directamente).
func get_relationship_component() -> SocialComponent:
	return social_component
