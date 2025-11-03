## Metadata tipada específica para vértices de NPCs en el grafo social.
## Extiende VertexMeta con campos relevantes para simulación social.
class_name NPCVertexMeta
extends VertexMeta

## Rol o profesión del NPC.
@export var role: String = ""

## Facción o grupo al que pertenece.
@export var faction: String = ""

## Nivel o rango jerárquico.
@export var level: int = 1

## Marcador para indicar si fue cargado desde archivo.
@export var loaded_from_save: bool = false

## Timestamp de última actualización.
@export var last_update_time: float = 0.0


func _init(_id: int = -1, _name: String = "", _role: String = "") -> void:
	super._init(_id, _name, "npc")
	role = _role


## Crea una copia profunda de la metadata de NPC.
func duplicate_meta() -> NPCVertexMeta:
	var copy := NPCVertexMeta.new(id, display_name, role)
	copy.faction = faction
	copy.level = level
	copy.loaded_from_save = loaded_from_save
	copy.last_update_time = last_update_time
	copy.custom_data = custom_data.duplicate(true)
	return copy


## Serializa la metadata de NPC a un diccionario.
func to_dict() -> Dictionary:
	var base := super.to_dict()
	base["role"] = role
	base["faction"] = faction
	base["level"] = level
	base["loaded_from_save"] = loaded_from_save
	base["last_update_time"] = last_update_time
	return base


## Reconstruye la metadata de NPC desde un diccionario.
static func from_dict(data: Dictionary) -> NPCVertexMeta:
	var meta := NPCVertexMeta.new()
	meta.id = int(data.get("id", -1))
	meta.display_name = str(data.get("display_name", ""))
	meta.vertex_type = str(data.get("vertex_type", "npc"))
	meta.role = str(data.get("role", ""))
	meta.faction = str(data.get("faction", ""))
	meta.level = int(data.get("level", 1))
	meta.loaded_from_save = bool(data.get("loaded_from_save", false))
	meta.last_update_time = float(data.get("last_update_time", 0.0))
	meta.custom_data = data.get("custom_data", {}).duplicate(true)
	return meta
