## GraphNodeData: Datos de un nodo del grafo editables desde el Inspector
## Resource que representa la configuración de un nodo
## Usa VertexMeta (o subclases) para almacenar la metadata del nodo
class_name GraphNodeData
extends Resource

## Identificador único del nodo (usado como key en el grafo)
@export var node_key: String = ""

## Metadata del nodo (VertexMeta o cualquier subclase como NetworkNodeMeta)
## El diseñador puede crear un nuevo Resource o cargar uno existente
@export var vertex_meta: VertexMeta = null


## Obtiene la metadata del nodo (crea una por defecto si no existe)
func get_metadata() -> VertexMeta:
	if vertex_meta == null:
		# Crear VertexMeta básico por defecto
		vertex_meta = VertexMeta.new()
		vertex_meta.display_name = node_key
	return vertex_meta


## Valida que los datos del nodo sean correctos
func is_valid() -> bool:
	return node_key != ""


func _to_string() -> String:
	var meta_type = vertex_meta.get_class() if vertex_meta else "null"
	return "GraphNodeData(%s, meta: %s)" % [node_key, meta_type]
