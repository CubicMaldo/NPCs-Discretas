@tool
@icon("../icons/consideration.svg")
##
## Base consideration. Should be extend for implementing custom score logic.
## i.e calculate escore based in some global state.
##
class_name UtilityAiConsideration extends UtilityAi

##
## The curve to be applied to the raw score.
##
@export var curve: Curve:
	set(value):
		curve = value
		update_configuration_warnings()

## If true, clamp the raw score before applying the curve
@export var clamp_input: bool = true

## If true, clamp the final score after applying the curve
@export var clamp_output: bool = true

var _curve_error_logged: bool = false


func calculate_score() -> float:
	var raw_score = score()
	
	if clamp_input:
		raw_score = clampf(raw_score, 0.0, 1.0)
	
	return _apply_curve(raw_score)


func _apply_curve(score: float) -> float:
	if curve == null:
		if not _curve_error_logged:
			push_error("'curve' not defined for '%s' consideration." % self.name)
			_curve_error_logged = true
		return 0.0

	var result = curve.sample_baked(score)
	
	if clamp_output:
		result = clampf(result, 0.0, 1.0)
	
	return result

##
## This method should be overwritten by the child class. Return value should be between 0.0 and 1.0 inclusive.
##
func score() -> float:
	return 0.0


func _get_configuration_warnings():
	var warnings = []

	var current_script = get_script().get_path()
	# not sure if there is a better way to validate if script was extended
	# instead of relying on the actual path.
	if current_script == "res://addons/utility_ai/considerations/consideration.gd":
		warnings.push_back("Consideration script needs to be extended and 'score' method implemented")

	if curve == null:
		warnings.push_back("Curve not set")

	return warnings
