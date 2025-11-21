class_name NPC
extends CharacterBody2D

## Datos de identidad y configuración
@export var npc_id: int = -1
@export var npc_name: String = ""
@export var personality_component: PersonalityComponent
@export var base_emotion: Emotion

## Configuración de interacciones
@export var interaction_config: InteractionConfig

## Referencias a componentes
@onready var sprite: Sprite2D = $Sprite2D
@onready var utility_label: Label = $UtilityLabel
@onready var social_component: SocialComponent

## Estado actual
var current_state: String = "idle"
var current_emotion: Emotion
var current_position: Vector2 = Vector2.ZERO

## Referencias a sistemas externos (inyección de dependencias)
var social_graph_manager: SocialGraphManager

# Constructor-friendly initializer: allow passing key fields at `NPC.new(...)` time.
func _init(_npc_id: int = -1, _npc_name: String = "", _social_graph_manager: SocialGraphManager = null) -> void:
	# Safe to set these early; _ready() will still run later to finish setup.
	npc_id = _npc_id
	npc_name = _npc_name
	social_graph_manager = _social_graph_manager

static func instantiate(parent: Node, _npc_id: int = -1, _npc_name: String = "", _social_graph_manager: SocialGraphManager = null) -> NPC:
	# Convenience helper that creates, injects systems, adds to `parent`, waits a frame and returns the ready NPC.
	var npc: NPC = NPC.new(_npc_id, _npc_name, _social_graph_manager)
	parent.add_child(npc)
	await parent.get_tree().process_frame
	if _social_graph_manager and _social_graph_manager.has_method("ensure_npc"):
		_social_graph_manager.ensure_npc(npc)
	return npc

# Initializes runtime state and ensures component references are ready for use.
func _ready() -> void:
	current_position = global_position
	current_emotion = _instantiate_emotion()
	social_component = _ensure_social_component()
	personality_component = _ensure_personality_component()
	social_component.owner_id = npc_id
	if social_graph_manager:
		social_component.set_graph_manager(social_graph_manager)
	
	# Load default config if none provided
	if not interaction_config:
		interaction_config = InteractionConfig.new()
	
	setup_ai()


# Maintains a cached copy of the position for systems that poll less frequently.
func _physics_process(_delta: float) -> void:
	current_position = global_position
	
	if _is_moving:
		if navigation_agent.is_navigation_finished():
			_is_moving = false
			velocity = Vector2.ZERO
			#print("[%s] Navigation finished." % name)
			return

		var next_path_position: Vector2 = navigation_agent.get_next_path_position()
		var current_agent_position: Vector2 = global_position
		var new_velocity: Vector2 = (next_path_position - current_agent_position).normalized() * movement_speed
		
		if navigation_agent.avoidance_enabled:
			navigation_agent.set_velocity(new_velocity)
		else:
			velocity = new_velocity
			move_and_slide()


# Handles a direct interaction with another NPC and forwards it to coordinating systems.
func interact_with(other_npc: NPC) -> void:
	if social_graph_manager and social_graph_manager.has_method("register_interaction"):
		social_graph_manager.register_interaction(self, other_npc)
	
	var familiarity_delta := _evaluate_interaction_delta(other_npc)
	social_component.update_familiarity(other_npc, familiarity_delta)

func talk_to(other_npc: NPC) -> void:
	if not other_npc: return
	
	# Simple talk logic: boost familiarity slightly based on compatibility
	var compatibility = 0.5
	if personality_component and other_npc.personality_component:
		compatibility = personality_component.calculate_compatibility(other_npc.personality_component)
	
	var delta = interaction_config.talk_familiarity_gain * compatibility
	var is_bad = randf() < interaction_config.bad_talk_chance
	
	if is_bad:
		delta = interaction_config.talk_familiarity_loss
		# print("[%s] Talked to %s (Bad outcome)" % [name, other_npc.name])
	else:
		# print("[%s] Talked to %s (Good outcome)" % [name, other_npc.name])
		pass
		
	social_component.update_familiarity(other_npc, delta)
	if social_graph_manager and social_graph_manager.has_method("register_interaction"):
		social_graph_manager.register_interaction(self, other_npc, delta, {"type": "talk", "result": "bad" if is_bad else "good"})

func fight_with(other_npc: NPC) -> void:
	if not other_npc: return
	
	# print("[%s] Fighting with %s!" % [name, other_npc.name])
	# Fighting drastically reduces familiarity
	var delta = interaction_config.fight_familiarity_loss
	social_component.update_familiarity(other_npc, delta)
	
	if social_graph_manager and social_graph_manager.has_method("register_interaction"):
		social_graph_manager.register_interaction(self, other_npc, delta, {"type": "fight"})

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
	var existing := $SocialComponent
	if existing:
		return existing as SocialComponent
	var component := SocialComponent.new()
	component.name = "SocialComponent"
	add_child(component)
	return component

func _ensure_personality_component() -> PersonalityComponent:
	var existing := $PersonalityComponent
	if existing:
		return existing as PersonalityComponent
	var component := PersonalityComponent.new()
	component.name = "PersonalityComponent"
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

# --- Movement & AI Integration ---

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var utility_agent: UtilityAiAgent = $UtilityAiAgent

var movement_speed: float = 100.0
var _is_moving: bool = false

func is_moving() -> bool:
	return _is_moving


func move_to(target_position: Vector2) -> void:
	if navigation_agent:
		navigation_agent.target_position = target_position
		_is_moving = true
	else:
		push_warning("NPC: No NavigationAgent2D found. Cannot move.")

func stop_moving() -> void:
	_is_moving = false
	velocity = Vector2.ZERO
	if navigation_agent:
		navigation_agent.target_position = global_position

func has_reached_destination() -> bool:
	if not navigation_agent:
		return true
	return navigation_agent.is_navigation_finished()

func setup_ai() -> void:
	# Initialize UtilityAI or Beehave if needed dynamically
	if utility_agent:
		utility_agent.enabled = true

		if not utility_agent.top_score_action_changed.is_connected(_on_utility_action_changed):
			utility_agent.top_score_action_changed.connect(_on_utility_action_changed)

func _on_utility_action_changed(action_id: String) -> void:
	# print("NPC %s: Action changed to %s" % [name, action_id])
	if utility_label:
		utility_label.text = action_id
