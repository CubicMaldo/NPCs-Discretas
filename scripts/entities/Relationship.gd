class_name Relationship
extends Resource

## Recurso extendido para representar una relación social entre NPCs.
## Ahora incluye múltiples dimensiones (familiaridad, confianza, hostilidad)
## e historial de interacciones para facilitar decisiones realizadas por sistemas externos (addons).

@export var partner_id: int = -1

## Dimensiones de la relación (0.0 - 1.0 recomendado)
@export_range(0.0, 1.0) var familiarity: float = 0.0
@export_range(0.0, 1.0) var trust: float = 0.5
@export_range(0.0, 1.0) var hostility: float = 0.0

## Historial e interacciones
@export var interaction_count: int = 0
@export var last_interaction_time: float = 0.0
@export var positive_interactions: int = 0
@export var negative_interactions: int = 0

## Metadata adicional (puede ser usado por sistemas específicos)
@export var tags: Array[String] = []
@export var custom_data: Dictionary = {}

## Calcula un score combinado de la calidad de la relación.
## Útil para sistemas de decisión externos (addons): positivo = buena relación, negativo = mala relación.
func get_relationship_quality() -> float:
	return (familiarity * 0.4) + (trust * 0.3) - (hostility * 0.3)

## Determina si esta relación es positiva (más buena que mala).
func is_positive() -> bool:
	return get_relationship_quality() > 0.3

## Determina si esta relación es negativa (más mala que buena).
func is_negative() -> bool:
	return hostility > 0.5 or get_relationship_quality() < -0.2

## Registra una interacción positiva y actualiza las métricas.
func record_positive_interaction(familiarity_delta: float = 0.05, trust_delta: float = 0.02) -> void:
	interaction_count += 1
	positive_interactions += 1
	familiarity = clamp(familiarity + familiarity_delta, 0.0, 1.0)
	trust = clamp(trust + trust_delta, 0.0, 1.0)
	hostility = max(0.0, hostility - 0.01)
	last_interaction_time = Time.get_ticks_msec() / 1000.0

## Registra una interacción negativa y actualiza las métricas.
func record_negative_interaction(familiarity_delta: float = -0.03, hostility_delta: float = 0.05) -> void:
	interaction_count += 1
	negative_interactions += 1
	familiarity = max(0.0, familiarity + familiarity_delta)
	trust = max(0.0, trust - 0.03)
	hostility = clamp(hostility + hostility_delta, 0.0, 1.0)
	last_interaction_time = Time.get_ticks_msec() / 1000.0

## Aplica decaimiento temporal a la relación (memoria que se desvanece).
func apply_decay(delta_time: float, decay_rate: float = 0.001) -> void:
	var decay := delta_time * decay_rate
	familiarity = max(0.0, familiarity - decay)
	trust = lerp(trust, 0.5, decay * 0.5) # Trust tiende a neutral
	hostility = max(0.0, hostility - decay * 2.0) # Hostilidad se olvida más rápido
