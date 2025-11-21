## Representa una arista no dirigida entre dos Vertex
## Nombres neutrales (endpoint_a/endpoint_b) evitan implicar direccion
## En redes de flujo:
## - weight: capacidad maxima de la arista
## - flux: flujo actual que pasa por la arista (debe ser <= weight)
class_name Edge

## Vértice extremo A.
var endpoint_a: Vertex = null
## Vértice extremo B.
var endpoint_b: Vertex = null
## Peso de la arista (capacidad máxima en redes de flujo).
var weight: float = 0.0
## Flujo actual en la arista (debe ser <= weight).
var flux: int = 0
var directed: bool = false
var directed_source_key: Variant = null
var directed_target_key: Variant = null

## Metadata asociada a la arista (puede ser Resource o null).
var metadata: Resource = null


## Inicializa la arista.
##
## Argumentos:
## - `_a`: Vértice extremo A.
## - `_b`: Vértice extremo B. 
## - `_weight`: Peso inicial (float, representa capacidad en redes de flujo).
## - `_flux`: Flujo actual en la arista (int, debe ser <= weight en redes de flujo).
## - `_metadata`: Resource opcional con metadata adicional.
func _init(
	 _a: Vertex = null,
	 _b: Vertex = null,
	 _weight: float = 0.0,
	 _flux: int = 0,
	 _metadata: Resource = null
) -> void:
	
	endpoint_a = _a
	endpoint_b = _b
	weight = _weight
	flux = _flux
	metadata = _metadata
	directed = false
	directed_source_key = null
	directed_target_key = null


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


## Configura si la arista es dirigida y qué extremos definen la dirección.
func configure_direction(is_directed: bool, source_key: Variant = null, target_key: Variant = null) -> void:
	directed = is_directed
	if directed:
		directed_source_key = source_key if source_key != null else endpoint_a.key if endpoint_a else null
		directed_target_key = target_key if target_key != null else endpoint_b.key if endpoint_b else null
	else:
		directed_source_key = null
		directed_target_key = null


## Devuelve `true` si el viaje desde `from_key` hacia `neighbor_key` está permitido por la dirección.
func allows_traversal(from_key, neighbor_key) -> bool:
	if not directed:
		return true
	if from_key == directed_source_key and neighbor_key == directed_target_key:
		return true
	return false


## Actualiza referencias de dirección si cambia la clave de un nodo.
func rekey_direction(old_key, new_key) -> void:
	if directed_source_key == old_key:
		directed_source_key = new_key
	if directed_target_key == old_key:
		directed_target_key = new_key


## Devuelve la capacidad residual disponible (capacity - flux).
## Útil para algoritmos de flujo máximo.
func residual_capacity() -> float:
	return weight - float(flux)


## Intenta agregar flujo a la arista.
## Devuelve `true` si se pudo agregar el flujo sin exceder la capacidad.
##
## Argumentos:
## - `amount`: Cantidad de flujo a agregar (puede ser negativo para reducir).
func add_flux(amount: int) -> bool:
	var new_flux = flux + amount
	if new_flux < 0 or float(new_flux) > weight:
		return false
	flux = new_flux
	return true


## Establece el flujo de la arista con validación de capacidad.
## Devuelve `true` si el flujo es válido (0 <= flux <= weight).
##
## Argumentos:
## - `new_flux`: Nuevo valor de flujo.
func set_flux(new_flux: int) -> bool:
	if new_flux < 0 or float(new_flux) > weight:
		return false
	flux = new_flux
	return true


## Resetea el flujo a 0.
func reset_flux() -> void:
	flux = 0


## Devuelve `true` si la arista está saturada (flux == weight).
func is_saturated() -> bool:
	return float(flux) >= weight
