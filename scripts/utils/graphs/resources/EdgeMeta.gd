## Metadata base para aristas del grafo.
## Extiende Resource para permitir serialización y tipado fuerte.
## Clases especializadas deben heredar de esta para agregar campos específicos del dominio.
class_name EdgeMeta
extends Resource

## Identificador único de la arista (opcional).
@export var id: int = -1

## Tipo o categoría de la arista.
@export var edge_type: String = ""

## Peso o intensidad de la conexión.
@export var weight: float = 0.0

## Timestamp de creación (Unix time).
@export var created_at: int = 0

## Timestamp de última actualización (Unix time).
@export var updated_at: int = 0

## Datos adicionales específicos del dominio.
## Usar con moderación; preferir exportar propiedades tipadas en subclases.
@export var custom_data: Dictionary = {}


func _init(_weight: float = 0.0, _type: String = "") -> void:
	weight = _weight
	edge_type = _type
	var current_time = int(Time.get_unix_time_from_system())
	created_at = current_time
	updated_at = current_time


## Crea una copia profunda de la metadata.
func duplicate_meta() -> EdgeMeta:
	var copy := EdgeMeta.new(weight, edge_type)
	copy.id = id
	copy.created_at = created_at
	copy.updated_at = updated_at
	copy.custom_data = custom_data.duplicate(true)
	return copy


## Serializa la metadata a un diccionario simple.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"edge_type": edge_type,
		"weight": weight,
		"created_at": created_at,
		"updated_at": updated_at,
		"custom_data": custom_data.duplicate(true)
	}


## Reconstruye la metadata desde un diccionario.
static func from_dict(data: Dictionary) -> EdgeMeta:
	var meta := EdgeMeta.new()
	meta.id = int(data.get("id", -1))
	meta.edge_type = str(data.get("edge_type", ""))
	meta.weight = float(data.get("weight", 0.0))
	meta.created_at = int(data.get("created_at", 0))
	meta.updated_at = int(data.get("updated_at", 0))
	meta.custom_data = data.get("custom_data", {}).duplicate(true)
	return meta


## Actualiza el timestamp de última modificación.
func touch() -> void:
	updated_at = int(Time.get_unix_time_from_system())


## Verifica si la arista fue actualizada recientemente.
## [br]
## Argumentos:
## - `seconds`: Número de segundos para considerar "reciente". Default: 3600 (1 hora)
func is_recent(seconds: int = 3600) -> bool:
	var current_time = Time.get_unix_time_from_system()
	return (current_time - updated_at) < seconds
