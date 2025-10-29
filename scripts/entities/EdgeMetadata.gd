## Metadata estructurada para aristas del grafo social entre NPCs.
##
## Esta clase extiende Resource para proporcionar type safety y validación automática
## de los atributos de las relaciones sociales. Cada arista dirigida A→B tiene su propia
## instancia de EdgeMetadata que describe la naturaleza y estado de esa relación.
class_name EdgeMetadata extends Resource

## Nivel de confianza normalizado [0..1].
## Representa qué tanto confía A en B. Valores más altos = mayor confianza.
@export_range(0.0, 1.0, 0.01) var trust: float = 0.5

## Timestamp de última interacción (Unix time).
## Se actualiza automáticamente cada vez que los NPCs interactúan.
@export var last_interaction: int = 0

## Tipo de relación entre los NPCs.
## Define la naturaleza social de la conexión.
@export_enum("Neutral", "Friendship", "Rivalry", "Family", "Professional", "Romantic") 
var relationship_type: String = "Neutral"

## Número total de interacciones entre estos NPCs.
## Se incrementa con cada llamada a register_interaction().
@export var interaction_count: int = 0

## Tags personalizados para categorización adicional.
## Útil para marcar relaciones especiales (ej: "quest_related", "guild_member", etc.)
@export var tags: Array[String] = []

## Nivel de hostilidad [0..100] (opcional).
## Valores altos indican conflicto o enemistad activa.
@export_range(0.0, 100.0, 1.0) var hostility: float = 0.0


## Constructor con valores por defecto configurables.
## [br]
## Argumentos:
## - `p_trust`: Nivel inicial de confianza [0..1]. Default: 0.5
## - `p_type`: Tipo inicial de relación. Default: "Neutral"
func _init(p_trust: float = 0.5, p_type: String = "Neutral") -> void:
	trust = clamp(p_trust, 0.0, 1.0)
	relationship_type = p_type
	last_interaction = int(Time.get_unix_time_from_system())


## Serializa la metadata a Dictionary para guardar en JSON.
## [br]
## Retorna un Dictionary con todos los campos serializables.
func to_dict() -> Dictionary:
	return {
		"trust": trust,
		"last_interaction": last_interaction,
		"relationship_type": relationship_type,
		"interaction_count": interaction_count,
		"tags": tags.duplicate(),
		"hostility": hostility
	}


## Reconstruye EdgeMetadata desde un Dictionary cargado de JSON.
## [br]
## Argumentos:
## - `data`: Dictionary con los datos serializados.
## [br]
## Retorna una nueva instancia de EdgeMetadata.
static func from_dict(data: Dictionary) -> EdgeMetadata:
	var meta = EdgeMetadata.new()
	meta.trust = clamp(float(data.get("trust", 0.5)), 0.0, 1.0)
	meta.last_interaction = int(data.get("last_interaction", 0))
	meta.relationship_type = str(data.get("relationship_type", "Neutral"))
	meta.interaction_count = int(data.get("interaction_count", 0))
	meta.hostility = clamp(float(data.get("hostility", 0.0)), 0.0, 100.0)
	
	# Restaurar tags
	var tags_data = data.get("tags", [])
	if tags_data is Array:
		meta.tags = tags_data.duplicate()
	
	return meta


## Actualiza metadata basándose en una interacción.
## [br]
## Argumentos:
## - `delta_familiarity`: Cambio en familiaridad [-100..100].
## [br]
## Ajusta confianza y actualiza contadores.
func update_from_interaction(delta_familiarity: float) -> void:
	interaction_count += 1
	last_interaction = int(Time.get_unix_time_from_system())
	
	# Ajustar confianza basándose en cambio de familiaridad
	# Cambios positivos aumentan confianza, negativos la reducen
	var trust_delta = (delta_familiarity / 100.0) * 0.1  # 10% del cambio normalizado
	trust = clamp(trust + trust_delta, 0.0, 1.0)
	
	# Ajustar hostilidad inversamente a familiaridad
	if delta_familiarity < 0:
		hostility = clamp(hostility + abs(delta_familiarity) * 0.5, 0.0, 100.0)
	else:
		hostility = clamp(hostility - delta_familiarity * 0.3, 0.0, 100.0)


## Verifica si la relación es reciente (menos de X días).
## [br]
## Argumentos:
## - `days`: Número de días para considerar "reciente". Default: 7
## [br]
## Retorna `true` si la última interacción fue hace menos de `days` días.
func is_recent(days: int = 7) -> bool:
	var current_time = Time.get_unix_time_from_system()
	var seconds_per_day = 86400
	return (current_time - last_interaction) < (days * seconds_per_day)


## Verifica si la relación es hostil (hostilidad > umbral).
## [br]
## Argumentos:
## - `threshold`: Umbral de hostilidad. Default: 50.0
## [br]
## Retorna `true` si la hostilidad supera el umbral.
func is_hostile(threshold: float = 50.0) -> bool:
	return hostility >= threshold


## Verifica si la relación es de confianza (trust > umbral).
## [br]
## Argumentos:
## - `threshold`: Umbral de confianza. Default: 0.7
## [br]
## Retorna `true` si la confianza supera el umbral.
func is_trusted(threshold: float = 0.7) -> bool:
	return trust >= threshold


## Añade un tag a la relación si no existe ya.
## [br]
## Argumentos:
## - `tag`: String con el tag a añadir.
func add_tag(tag: String) -> void:
	if not tags.has(tag):
		tags.append(tag)


## Elimina un tag de la relación.
## [br]
## Argumentos:
## - `tag`: String con el tag a eliminar.
func remove_tag(tag: String) -> void:
	tags.erase(tag)


## Verifica si la relación tiene un tag específico.
## [br]
## Argumentos:
## - `tag`: String con el tag a buscar.
## [br]
## Retorna `true` si el tag existe.
func has_tag(tag: String) -> bool:
	return tags.has(tag)


## Obtiene una descripción textual del estado de la relación.
## [br]
## Útil para debugging y UI.
func get_description() -> String:
	var desc = "Tipo: %s" % relationship_type
	desc += " | Confianza: %.0f%%" % (trust * 100.0)
	desc += " | Hostilidad: %.0f" % hostility
	desc += " | Interacciones: %d" % interaction_count
	if tags.size() > 0:
		desc += " | Tags: %s" % str(tags)
	return desc
