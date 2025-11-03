## Metadata tipada específica para aristas de relaciones sociales entre NPCs.
## Extiende EdgeMeta con campos relevantes para simulación social.
class_name SocialEdgeMeta
extends EdgeMeta

## Nivel de confianza normalizado [0..1].
## Representa qué tanto confía A en B. Valores más altos = mayor confianza.
@export_range(0.0, 1.0, 0.01) var trust: float = 0.5

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
## - `p_weight`: Peso inicial de la relación (familiaridad). Default: 50.0
## - `p_trust`: Nivel inicial de confianza [0..1]. Default: 0.5
## - `p_type`: Tipo inicial de relación. Default: "Neutral"
func _init(p_weight: float = 50.0, p_trust: float = 0.5, p_type: String = "Neutral") -> void:
	super._init(p_weight, "social")
	trust = clamp(p_trust, 0.0, 1.0)
	relationship_type = p_type


## Crea una copia profunda de la metadata de relación social.
func duplicate_meta() -> SocialEdgeMeta:
	var copy := SocialEdgeMeta.new(weight, trust, relationship_type)
	copy.id = id
	copy.created_at = created_at
	copy.updated_at = updated_at
	copy.interaction_count = interaction_count
	copy.tags = tags.duplicate()
	copy.hostility = hostility
	copy.custom_data = custom_data.duplicate(true)
	return copy


## Serializa la metadata de relación social a un diccionario.
func to_dict() -> Dictionary:
	var base := super.to_dict()
	base["trust"] = trust
	base["relationship_type"] = relationship_type
	base["interaction_count"] = interaction_count
	base["tags"] = tags.duplicate()
	base["hostility"] = hostility
	return base


## Reconstruye la metadata de relación social desde un diccionario.
static func from_dict(data: Dictionary) -> SocialEdgeMeta:
	var meta := SocialEdgeMeta.new()
	meta.id = int(data.get("id", -1))
	meta.edge_type = str(data.get("edge_type", "social"))
	meta.weight = float(data.get("weight", 50.0))
	meta.created_at = int(data.get("created_at", 0))
	meta.updated_at = int(data.get("updated_at", 0))
	meta.trust = clamp(float(data.get("trust", 0.5)), 0.0, 1.0)
	meta.relationship_type = str(data.get("relationship_type", "Neutral"))
	meta.interaction_count = int(data.get("interaction_count", 0))
	meta.hostility = clamp(float(data.get("hostility", 0.0)), 0.0, 100.0)
	meta.custom_data = data.get("custom_data", {}).duplicate(true)
	
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
## Ajusta confianza, peso, y actualiza contadores.
func update_from_interaction(delta_familiarity: float) -> void:
	interaction_count += 1
	touch()
	
	# Actualizar peso (familiaridad)
	weight = clamp(weight + delta_familiarity, 0.0, 100.0)
	
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
func is_interaction_recent(days: int = 7) -> bool:
	var seconds_per_day = 86400
	return is_recent(days * seconds_per_day)


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
	desc += " | Familiaridad: %.0f" % weight
	desc += " | Confianza: %.0f%%" % (trust * 100.0)
	desc += " | Hostilidad: %.0f" % hostility
	desc += " | Interacciones: %d" % interaction_count
	if tags.size() > 0:
		desc += " | Tags: %s" % str(tags)
	return desc
