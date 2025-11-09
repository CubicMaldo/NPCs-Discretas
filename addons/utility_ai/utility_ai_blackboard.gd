##
## Shared data storage for Utility AI systems.
## 
## The blackboard allows actions and considerations to share data without tight coupling.
## It emits signals when values change, enabling reactive considerations.
##
class_name UtilityAiBlackboard extends Node

## Emitted when any value changes
signal value_changed(key: String, new_value: Variant, old_value: Variant)
## Emitted when a specific key changes (connect with key as parameter)
signal key_changed(key: String, new_value: Variant)

var _data: Dictionary = {}
var _change_listeners: Dictionary = {}  # key -> Array of Callables


##
## Set a value in the blackboard
## @param key: The key to store the value under
## @param value: The value to store
##
func set_value(key: String, value: Variant) -> void:
	var old_value = _data.get(key, null)
	
	# Only emit if value actually changed
	if old_value == value:
		return
	
	_data[key] = value
	value_changed.emit(key, value, old_value)
	
	# Notify specific listeners
	if _change_listeners.has(key):
		for callback in _change_listeners[key]:
			callback.call(value, old_value)


##
## Get a value from the blackboard
## @param key: The key to retrieve
## @param default_value: Value to return if key doesn't exist
## @return: The stored value or default_value
##
func get_value(key: String, default_value: Variant = null) -> Variant:
	return _data.get(key, default_value)


##
## Check if a key exists in the blackboard
##
func has_value(key: String) -> bool:
	return _data.has(key)


##
## Remove a value from the blackboard
##
func erase_value(key: String) -> void:
	if _data.has(key):
		var old_value = _data[key]
		_data.erase(key)
		value_changed.emit(key, null, old_value)


##
## Clear all values from the blackboard
##
func clear() -> void:
	_data.clear()
	_change_listeners.clear()


##
## Get all keys in the blackboard
##
func get_keys() -> Array:
	return _data.keys()


##
## Register a callback to be called when a specific key changes
## @param key: The key to watch
## @param callback: Callable to invoke when key changes (receives new_value, old_value)
##
func watch_key(key: String, callback: Callable) -> void:
	if not _change_listeners.has(key):
		_change_listeners[key] = []
	_change_listeners[key].append(callback)


##
## Unregister a callback for a specific key
##
func unwatch_key(key: String, callback: Callable) -> void:
	if _change_listeners.has(key):
		_change_listeners[key].erase(callback)
		if _change_listeners[key].is_empty():
			_change_listeners.erase(key)


##
## Increment a numeric value
## @param key: The key to increment
## @param amount: Amount to add (default 1)
##
func increment(key: String, amount: float = 1.0) -> void:
	var current = get_value(key, 0.0)
	set_value(key, current + amount)


##
## Decrement a numeric value
## @param key: The key to decrement
## @param amount: Amount to subtract (default 1)
##
func decrement(key: String, amount: float = 1.0) -> void:
	increment(key, -amount)


##
## Set a value with clamping
## @param key: The key to store the value under
## @param value: The value to store
## @param min_value: Minimum allowed value
## @param max_value: Maximum allowed value
##
func set_value_clamped(key: String, value: float, min_value: float, max_value: float) -> void:
	set_value(key, clampf(value, min_value, max_value))


##
## Export blackboard data as a dictionary (useful for saving/debugging)
##
func to_dict() -> Dictionary:
	return _data.duplicate()


##
## Import data from a dictionary
##
func from_dict(data: Dictionary) -> void:
	for key in data.keys():
		set_value(key, data[key])
