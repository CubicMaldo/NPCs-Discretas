## Representa un vértice en el grafo.
## Extiende `RefCounted` para permitir gestión de memoria explícita.
class_name Vertex
extends RefCounted

## Clave original usada por el grafo (Variant). Puede ser int, String, Object, etc.
var key: Variant = null
## Diccionario de aristas adyacentes: { neighbor_key: Edge }
var edges: Dictionary[Variant, Edge] = {}

## Identificador entero opcional (útil para indexación rápida).
var id: int = -1
## Metadata arbitraria asociada al vértice (puede ser cualquier Resource o null).
var meta: Resource = null


## Inicializa el vértice.
##
## Argumentos:
## - `_key`: Clave del vértice (no puede ser null).
## - `_id`: Identificador entero (opcional).
## - `_meta`: Resource opcional con metadata (ej: VertexMeta, NPCVertexMeta, o cualquier Resource personalizado).
func _init(_key: Variant = null, _id: int = -1, _meta: Resource = null):
	assert(_key != null, "Vertex key cannot be null")
	key = _key
	id = _id
	edges = {}
	meta = _meta


## Devuelve las claves de los vecinos conectados a este vértice.
## Devuelve: Array de claves (Variant).
func get_neighbor_keys() -> Array:
	return edges.keys()


## Devuelve un diccionario { neighbor_key: weight } con los pesos de las aristas.
## Devuelve: Dictionary
func get_neighbor_weights() -> Dictionary:
	var out: Dictionary = {}
	for n in edges.keys():
		out[n] = (edges[n] as Edge).weight
	return out


## Devuelve el grado (número de aristas) de este vértice.
## Devuelve: int
func degree() -> int:
	return edges.size()


## Obtiene el objeto `Edge` que conecta con `neighbor_key`, o `null` si no existe.
##
## Argumentos:
## - `neighbor_key`: Clave del vecino.
##
## Devuelve `Edge` o `null` si no existe la conexión.
func get_edge_to(neighbor_key) -> Edge:
	return edges.get(neighbor_key, null)


## Rompe referencias cruzadas y limpia las aristas para permitir la recolección.
## Esto borra la referencia en el vértice opuesto y pone los endpoints de la arista en `null`.
func dispose() -> void:
	for n in edges.keys():
		var e: Edge = edges[n]
		if e == null:
			continue
		var other_vertex: Vertex = null
		if e.endpoint_a == self:
			other_vertex = e.endpoint_b
		elif e.endpoint_b == self:
			other_vertex = e.endpoint_a
		if other_vertex:
			other_vertex.edges.erase(key)
		e.endpoint_a = null
		e.endpoint_b = null
	edges.clear()
