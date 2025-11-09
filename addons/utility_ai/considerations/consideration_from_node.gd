@tool
##
## Calculate consideration score from a node's property or method.
##
class_name UtilityAiConsiderationFromNode extends UtilityAiConsideration

##
## Node with the property or method holding the value for the consideration.
##
@export var node: Node
# TODO make it a list with all properties in node
## This is name of the property or method with the value to use in the consideration.
## Ideally it should return a value between 0.0 and 1.0. Use max_value in case your value exceeds this range.
## This also accepts boolean returns, where false will be 0.0 and true 1.0.
@export var property_name: String = "";

## By default, the consideration expects a value between
## 0.0 and 1.0. If your value does not fit this range you
## can set what is the max value so it's converted to 1.0
@export var max_value: float = 1.0

## If true, clamp the resulting score to [0, 1] range
@export var clamp_score: bool = true

## If true, cache the last retrieved value (useful for expensive properties)
@export var enable_cache: bool = false

## Time in seconds before cached value expires (0 = never expires)
@export var cache_duration: float = 0.0

var _cached_value: float = 0.0
var _cache_time: float = 0.0
var _error_logged: bool = false


func score() -> float:
	# Check cache validity
	if enable_cache and _is_cache_valid():
		return _cached_value
	
	var raw_score = _get_value_from_node()
	var normalized_score = raw_score / max_value
	
	if clamp_score:
		normalized_score = clampf(normalized_score, 0.0, 1.0)
	
	# Update cache
	if enable_cache:
		_cached_value = normalized_score
		_cache_time = Time.get_ticks_msec() / 1000.0
	
	return normalized_score


func _is_cache_valid() -> bool:
	if cache_duration <= 0.0:
		return true  # Cache never expires
	
	var current_time = Time.get_ticks_msec() / 1000.0
	return (current_time - _cache_time) < cache_duration


##
## Manually invalidate the cache
##
func invalidate_cache() -> void:
	_cache_time = 0.0


func _get_value_from_node() -> float:
	if node == null:
		if not _error_logged:
			push_error("Node not set for consideration '%s' " % self.name)
			_error_logged = true
		return 0.0

	if property_name == "":
		if not _error_logged:
			push_error("Property name not set for consideration '%s' " % self.name)
			_error_logged = true
		return 0.0

	if not (property_name in node):
		if not _error_logged:
			push_error("Couldn't find property or method '%s' for consideration '%s' " % [property_name, self.name])
			_error_logged = true
		return 0.0

	var value = node.call(property_name) if node.has_method(property_name) else node.get(property_name)

	if typeof(value) == TYPE_BOOL:
		return 1.0 if value else 0.0
	
	# Try to convert to float
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return float(value)
	
	if not _error_logged:
		push_warning("Property '%s' in consideration '%s' returned non-numeric value" % [property_name, self.name])
		_error_logged = true
	
	return 0.0


func _get_configuration_warnings():
	var warnings = []

	var considerations = self.get_child_count()

	if node == null:
		warnings.push_back("Target node not set")
	if property_name == "":
		warnings.push_back("Target property name not set")

	return warnings
