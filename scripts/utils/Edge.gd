## Representa una arista no dirigida entre dos `Vertex`.
## Nombres neutrales (`endpoint_a`/`endpoint_b`) evitan implicar dirección.
class_name Edge

## Vértice extremo A.
var endpoint_a: Vertex = null
## Vértice extremo B.
var endpoint_b: Vertex = null
## Peso de la arista.
## Nota de dominio: en el grafo social este valor representa la familiaridad/conocimiento (tie strength)
## entre dos actores, típicamente en un rango [0..100].
var weight: float = 0.0
## Atributos adicionales de la arista (multi-atributo):
## Ej.: { "hostility": float, "respect": float, ... }
var meta: Dictionary = {}


## Inicializa la arista.
##
## Argumentos:
## - `_a`: Vértice extremo A.
## - `_b`: Vértice extremo B.
## - `_weight`: Peso inicial (float).
func _init(_a: Vertex = null, _b: Vertex = null, _weight: float = 0.0, _meta: Dictionary = {}):
	endpoint_a = _a
	endpoint_b = _b
	weight = _weight
	meta = _meta.duplicate(true) if _meta else {}


## Devuelve un Array con los dos vértices extremos: [endpoint_a, endpoint_b].
## Devuelve: Array
func endpoints() -> Array:
	return [endpoint_a, endpoint_b]


## Dado un endpoint (Vertex o clave), devuelve la clave del otro extremo.
##
## Argumentos:
## - `endpoint`: Vertex o clave del endpoint conocido.
##
## Devuelve la clave del otro extremo o `null` si no encaja.
func other(endpoint) -> Variant:
	var key_a = endpoint_a.key if endpoint_a else null
	var key_b = endpoint_b.key if endpoint_b else null
	var q = endpoint
	if endpoint is Vertex:
		q = endpoint.key
	if q == key_a:
		return key_b
	if q == key_b:
		return key_a
	return null


## Devuelve `true` si este Edge tiene `endpoint` (Vertex o clave) como uno de sus extremos.
##
## Argumentos:
## - `endpoint`: Vertex o clave a comprobar.
##
## Devuelve `bool`.
func has_endpoint(endpoint) -> bool:
	var q = endpoint
	if endpoint is Vertex:
		q = endpoint.key
	return (endpoint_a and endpoint_a.key == q) or (endpoint_b and endpoint_b.key == q)
