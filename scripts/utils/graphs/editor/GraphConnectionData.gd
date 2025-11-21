## GraphConnectionData: Datos de una conexión/arista del grafo
## Resource que representa una conexión entre dos nodos
## Usa EdgeMeta para almacenar metadata adicional de la arista
class_name GraphConnectionData
extends Resource

## Nodo origen (debe coincidir con el node_key de un GraphNodeData)
@export var from_node: String = ""

## Nodo destino (debe coincidir con el node_key de un GraphNodeData)
@export var to_node: String = ""

## Peso de la conexión (capacidad en redes de flujo)
@export var weight: float = 1.0

## Flujo inicial de la arista (para modelado de redes)
@export var flux: int = 0

## Indica si la conexión debe tratarse como dirigida. El sistema asume que todas son dirigidas.
@export var directed: bool = true

## Metadata de la arista (EdgeMeta o cualquier subclase)
## Opcional - si no se proporciona, se crea EdgeMeta básico
@export var edge_meta: EdgeMeta = null


## Obtiene la metadata de la arista (crea una por defecto si no existe)
func get_edge_metadata() -> EdgeMeta:
	if edge_meta == null:
		# Crear EdgeMeta básico por defecto
		edge_meta = EdgeMeta.new()
	return edge_meta


## Valida que la conexión tenga los datos mínimos
func is_valid() -> bool:
	return from_node != "" and to_node != ""


func _to_string() -> String:
	return "Connection(%s <-> %s, w=%.1f)" % [from_node, to_node, weight]
