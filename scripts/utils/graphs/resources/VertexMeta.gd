## Metadata tipada para vértices del grafo.
## Extiende Resource para permitir serialización y tipado fuerte.
class_name VertexMeta
extends Resource

## Identificador único del vértice (si aplica).
@export var id: int = -1

## Nombre legible del vértice.
@export var display_name: String = ""

## Tipo o categoría del vértice.
@export var vertex_type: String = ""

## Datos adicionales específicos del dominio.
## Usar con moderación; preferir exportar propiedades tipadas.
@export var custom_data: Dictionary = {}


func _init(_id: int = -1, _name: String = "", _type: String = "") -> void:
	id = _id
	display_name = _name
	vertex_type = _type


## Crea una copia profunda de la metadata.
func duplicate_meta() -> VertexMeta:
	var copy := VertexMeta.new(id, display_name, vertex_type)
	copy.custom_data = custom_data.duplicate(true)
	return copy


## Serializa la metadata a un diccionario simple.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"vertex_type": vertex_type,
		"custom_data": custom_data.duplicate(true)
	}


## Reconstruye la metadata desde un diccionario.
static func from_dict(data: Dictionary) -> VertexMeta:
	var meta := VertexMeta.new()
	meta.id = int(data.get("id", -1))
	meta.display_name = str(data.get("display_name", ""))
	meta.vertex_type = str(data.get("vertex_type", ""))
	meta.custom_data = data.get("custom_data", {}).duplicate(true)
	return meta
