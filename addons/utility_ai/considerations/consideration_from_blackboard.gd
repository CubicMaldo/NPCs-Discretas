@tool
##
## Calculate consideration score from a blackboard value.
##
class_name UtilityAiConsiderationFromBlackboard extends UtilityAiConsideration

##
## The blackboard to read from
##
@export var blackboard: Node  # UtilityAiBlackboard

##
## Key in the blackboard to read the value from
##
@export var key: String = ""

## By default, the consideration expects a value between
## 0.0 and 1.0. If your value does not fit this range you
## can set what is the max value so it's converted to 1.0
@export var max_value: float = 1.0

## Value to return if the key doesn't exist in the blackboard
@export var default_value: float = 0.0

## If true, clamp the resulting score to [0, 1] range
@export var clamp_score: bool = true


func score() -> float:
	if blackboard == null:
		push_error("Blackboard not set for consideration '%s'" % self.name)
		return 0.0
	
	if key == "":
		push_error("Key not set for consideration '%s'" % self.name)
		return 0.0
	
	var value = blackboard.get_value(key, default_value)
	
	# Handle boolean values
	if typeof(value) == TYPE_BOOL:
		return 1.0 if value else 0.0
	
	# Convert to float and normalize
	var score_value = float(value) / max_value
	
	if clamp_score:
		score_value = clampf(score_value, 0.0, 1.0)
	
	return score_value


func _get_configuration_warnings():
	var warnings = []
	
	if blackboard == null:
		warnings.push_back("Blackboard not set")
	if key == "":
		warnings.push_back("Key not set")
	
	return warnings
