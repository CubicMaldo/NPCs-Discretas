class_name PersonalityComponent
extends Node

## Componente que gestiona los rasgos de personalidad de un NPC.
## Permite ajustar valores desde el inspector y proporciona métodos para consultar la personalidad.

# Rasgos de personalidad (Big Five / OCEAN model simplificado o personalizado)
@export_range(0.0, 1.0) var openness: float = 0.5
@export_range(0.0, 1.0) var conscientiousness: float = 0.5
@export_range(0.0, 1.0) var extraversion: float = 0.5
@export_range(0.0, 1.0) var agreeableness: float = 0.5
@export_range(0.0, 1.0) var neuroticism: float = 0.5

# Rasgos adicionales específicos del juego
@export_range(0.0, 1.0) var aggression: float = 0.2
@export_range(0.0, 1.0) var impulsivity: float = 0.3

func _ready() -> void:
	pass

## Devuelve un diccionario con todos los rasgos.
func get_traits() -> Dictionary:
	return {
		"openness": openness,
		"conscientiousness": conscientiousness,
		"extraversion": extraversion,
		"agreeableness": agreeableness,
		"neuroticism": neuroticism,
		"aggression": aggression,
		"impulsivity": impulsivity
	}

## Modifica un rasgo específico.
func set_trait(trait_name: String, value: float) -> void:
	match trait_name:
		"openness": openness = clamp(value, 0.0, 1.0)
		"conscientiousness": conscientiousness = clamp(value, 0.0, 1.0)
		"extraversion": extraversion = clamp(value, 0.0, 1.0)
		"agreeableness": agreeableness = clamp(value, 0.0, 1.0)
		"neuroticism": neuroticism = clamp(value, 0.0, 1.0)
		"aggression": aggression = clamp(value, 0.0, 1.0)
		"impulsivity": impulsivity = clamp(value, 0.0, 1.0)
		_:
			push_warning("PersonalityComponent: Trait '%s' not found." % trait_name)

## Calcula la compatibilidad con otra personalidad (simple distancia euclidiana o similar).
## Retorna un valor entre 0.0 (incompatible) y 1.0 (muy compatible).
func calculate_compatibility(other: PersonalityComponent) -> float:
	if not other:
		return 0.0
	
	var diff_sum = 0.0
	diff_sum += abs(openness - other.openness)
	diff_sum += abs(conscientiousness - other.conscientiousness)
	diff_sum += abs(extraversion - other.extraversion)
	diff_sum += abs(agreeableness - other.agreeableness)
	diff_sum += abs(neuroticism - other.neuroticism)
	
	# Normalizar: suma máxima de diferencias es 5.0.
	# Invertir para que 0 diferencia sea 1.0 compatibilidad.
	var compatibility = 1.0 - (diff_sum / 5.0)
	return clamp(compatibility, 0.0, 1.0)
