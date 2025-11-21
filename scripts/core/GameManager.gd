extends Node

## Sistema central de gestión del juego.
## Coordina subsistemas, gestiona el ciclo de vida del juego, y mantiene el estado global.

signal game_started
signal game_paused
signal game_resumed
signal game_over

## Estados del juego
enum GameState {
	LOADING, # Cargando recursos iniciales
	MENU, # En menú principal
	PLAYING, # Gameplay activo
	PAUSED, # Juego pausado
	GAME_OVER # Partida terminada
}

@export var auto_start: bool = false
@export var initial_npc_count: int = 10

## Estado actual del juego
var current_state: GameState = GameState.LOADING

## Referencias a sistemas clave (inyectadas en _ready)
var social_graph_manager: SocialGraphManager
var time_manager: Node # TimeManager (a implementar)
var event_system: Node # EventSystem

## Configuración global
var game_config: Dictionary = {
	"simulation_speed": 1.0,
	"enable_decay": true,
	"enable_dunbar_limit": true,
	"debug_mode": false
}

## Estadísticas globales
var game_stats: Dictionary = {
	"total_interactions": 0,
	"total_npcs_spawned": 0,
	"game_time_seconds": 0.0,
	"current_day": 0
}

func _ready() -> void:
	print("[GameManager] Inicializando...")
	_inject_dependencies()
	_initialize_subsystems()
	
	if auto_start:
		start_game()


## Inyecta referencias a subsistemas
func _inject_dependencies() -> void:
	# Buscar Social Graph Manager
	social_graph_manager = get_tree().get_first_node_in_group("social_graph_manager")
	if not social_graph_manager:
		push_warning("GameManager: SocialGraphManager not found")
	
	# Buscar EventSystem (futuro)
	event_system = get_node_or_null("/root/EventSystem")
	
	# Buscar TimeManager (futuro)
	time_manager = get_node_or_null("/root/TimeManager")


## Inicializa subsistemas
func _initialize_subsystems() -> void:
	if social_graph_manager:
		# Conectar señales del social graph
		if social_graph_manager.has_signal("interaction_registered"):
			social_graph_manager.interaction_registered.connect(_on_interaction_registered)
	
	# Inicializar EventSystem si existe
	if event_system and event_system.has_method("initialize"):
		event_system.initialize()
	
	print("[GameManager] Subsistemas inicializados")


## Inicia el juego
func start_game() -> void:
	if current_state == GameState.PLAYING:
		return
	
	print("[GameManager] Iniciando juego...")
	current_state = GameState.PLAYING
	game_stats["game_time_seconds"] = 0.0
	game_started.emit()
	
	# Puede spawnar NPCs iniciales si es necesario
	if initial_npc_count > 0:
		_spawn_initial_npcs()


## Pausa el juego
func pause_game() -> void:
	if current_state != GameState.PLAYING:
		return
	
	current_state = GameState.PAUSED
	get_tree().paused = true
	game_paused.emit()
	print("[GameManager] Juego pausado")


## Reanuda el juego
func resume_game() -> void:
	if current_state != GameState.PAUSED:
		return
	
	current_state = GameState.PLAYING
	get_tree().paused = false
	game_resumed.emit()
	print("[GameManager] Juego reanudado")


## Termina el juego
func end_game() -> void:
	if current_state == GameState.GAME_OVER:
		return
	
	current_state = GameState.GAME_OVER
	game_over.emit()
	print("[GameManager] Juego terminado")
	print("  Total interacciones: ", game_stats["total_interactions"])
	print("  Total NPCs: ", game_stats["total_npcs_spawned"])
	print("  Tiempo de juego: %.1f segundos" % game_stats["game_time_seconds"])


## Actualiza el tiempo de juego
func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		game_stats["game_time_seconds"] += delta * game_config["simulation_speed"]


## Callback para interacciones sociales
func _on_interaction_registered(a_key, b_key, new_familiarity: float, _options: Dictionary) -> void:
	game_stats["total_interactions"] += 1
	
	# Opcional: registrar en EventSystem
	if event_system and event_system.has_method("register_event"):
		event_system.register_event("interaction", {
			"actor_a": a_key,
			"actor_b": b_key,
			"familiarity": new_familiarity
		})


## Spawn NPCs iniciales (placeholder - a expandir)
func _spawn_initial_npcs() -> void:
	print("[GameManager] Spawning %d NPCs iniciales..." % initial_npc_count)
	# TODO: Implementar lógica de spawn
	# Por ahora solo registrarlos en el grafo si existen en escena
	var npcs = get_tree().get_nodes_in_group("npc")
	for npc in npcs:
		if social_graph_manager:
			social_graph_manager.ensure_npc(npc)
			game_stats["total_npcs_spawned"] += 1


## Actualiza una configuración global
func set_config(key: String, value: Variant) -> void:
	if game_config.has(key):
		game_config[key] = value
		print("[GameManager] Config actualizada: %s = %s" % [key, value])
	else:
		push_warning("GameManager: Config key '%s' no existe" % key)


## Obtiene una estadística
func get_stat(key: String) -> Variant:
	return game_stats.get(key, null)


## Reinicia las estadísticas
func reset_stats() -> void:
	game_stats = {
		"total_interactions": 0,
		"total_npcs_spawned": 0,
		"game_time_seconds": 0.0,
		"current_day": 0
	}
	print("[GameManager] Estadísticas reiniciadas")
