extends Node

## Sistema centralizado de eventos del juego.
## Implementa patrón Observer/Event Bus para desacoplar subsistemas.

signal event_registered(event_type: String, event_data: Dictionary, timestamp: float)

## Registro de eventos históricos
var event_history: Array[Dictionary] = []

## Maximum number of events to store (para evitar memory leaks)
const MAX_HISTORY_SIZE: int = 1000

## Suscriptores por tipo de evento: event_type -> Array[Callable]
var subscribers: Dictionary = {}

## Tiempo desde inicio del juego (puede sincronizarse con TimeManager)
var game_time: float = 0.0

func _ready() -> void:
	print("[EventSystem] Inicializado")
	add_to_group("event_system")


func _process(delta: float) -> void:
	game_time += delta


## Registra un evento en el sistema
func register_event(event_type: String, event_data: Dictionary = {}) -> Dictionary:
	var event := {
		"type": event_type,
		"data": event_data,
		"timestamp": game_time,
		"frame": Engine.get_process_frames()
	}
	
	# Añadir a historial
	event_history.append(event)
	
	# Limitar tamaño del historial (FIFO)
	if event_history.size() > MAX_HISTORY_SIZE:
		event_history.pop_front()
	
	# Emitir señal global
	event_registered.emit(event_type, event_data, game_time)
	
	# Notificar suscriptores específicos
	_notify_subscribers(event_type, event)
	
	return event


## Suscribirse a un tipo de evento con un callback
func subscribe(event_type: String, callback: Callable) -> void:
	if not subscribers.has(event_type):
		subscribers[event_type] = []
	
	if not subscribers[event_type].has(callback):
		subscribers[event_type].append(callback)
		print("[EventSystem] Suscrito a evento '%s'" % event_type)


## Desuscribirse de un evento
func unsubscribe(event_type: String, callback: Callable) -> void:
	if not subscribers.has(event_type):
		return
	
	var idx = subscribers[event_type].find(callback)
	if idx != -1:
		subscribers[event_type].remove_at(idx)
		print("[EventSystem] Desuscrito de evento '%s'" % event_type)


## Notifica a los suscriptores de un evento
func _notify_subscribers(event_type: String, event: Dictionary) -> void:
	if not subscribers.has(event_type):
		return
	
	for callback in subscribers[event_type]:
		if callback.is_valid():
			callback.call(event)


## Obtiene el historial de eventos filtrado
func get_event_history(event_type: String = "", since_time: float = 0.0) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []
	
	for event in event_history:
		# Filtrar por tipo si se especifica
		if event_type != "" and event["type"] != event_type:
			continue
		
		# Filtrar por timestamp
		if event["timestamp"] < since_time:
			continue
		
		filtered.append(event)
	
	return filtered


## Cuenta eventos de un tipo específico
func count_events(event_type: String, since_time: float = 0.0) -> int:
	return get_event_history(event_type, since_time).size()


## Limpia el historial de eventos
func clear_history() -> void:
	event_history.clear()
	print("[EventSystem] Historial limpiado")


## DEBUG: Imprime los últimos N eventos
func debug_print_recent(count: int = 10) -> void:
	print("\n[EventSystem] Últimos %d eventos:" % count)
	var recent = event_history.slice(max(0, event_history.size() - count), event_history.size())
	for event in recent:
		print("  [%.2fs] %s: %s" % [event["timestamp"], event["type"], event["data"]])
	print("")


## Stats del sistema
func get_stats() -> Dictionary:
	return {
		"total_events": event_history.size(),
		"subs

criber_types": subscribers.size(),
		"game_time": game_time
	}
