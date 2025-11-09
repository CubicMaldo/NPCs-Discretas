@icon("../icons/aggregation.svg")
@tool
class_name UtilityAiAggregation extends UtilityAi

enum AGGREGATION {
	AVG,        ## Average of all child scores
	MULT,       ## Multiply all child scores
	SUM,        ## Sum of all child scores
	MAX,        ## Maximum child score
	MIN,        ## Minimum child score
	WEIGHTED    ## Weighted average based on child order or weights
}

@export var aggregation_type: AGGREGATION = AGGREGATION.MULT

## If true, clamp the final score to [0, 1] range
@export var clamp_result: bool = true

## Weights for WEIGHTED aggregation (if empty, uses equal weights)
## Order matches child node order
@export var weights: Array[float] = []

## For MULT aggregation, use compensation factor to reduce impact of low scores
## Formula: (score * (1 - compensation_factor)) + (compensation_factor)
@export_range(0.0, 1.0) var multiplication_compensation: float = 0.0

var aggregation_handler = {
	AGGREGATION.MULT: _multiply,
	AGGREGATION.SUM: _sum,
	AGGREGATION.AVG: _average,
	AGGREGATION.MAX: _max,
	AGGREGATION.MIN: _min,
	AGGREGATION.WEIGHTED: _weighted_average,
}

var _warned_invalid_child: Dictionary = {}


func calculate_score() -> float:
	var result = aggregation_handler[aggregation_type].call()
	
	if clamp_result:
		result = clampf(result, 0.0, 1.0)
	
	return result


func _sum():
	var scores := 0.0
	for consideration in get_children():
		if not _is_valid_child(consideration):
			continue
		scores += consideration.calculate_score()

	return scores


func _multiply():
	var number_of_considerations := 0
	var scores := 1.0
	for consideration in get_children():
		if not _is_valid_child(consideration):
			continue
		number_of_considerations += 1
		var score = consideration.calculate_score()
		
		# Apply compensation factor to reduce impact of very low scores
		if multiplication_compensation > 0.0:
			score = (score * (1.0 - multiplication_compensation)) + multiplication_compensation
		
		scores *= score

	if number_of_considerations == 0:
		return 0.0

	return scores


func _average():
	var number_of_considerations := 0
	var sum_of_scores := 0.0
	for consideration in get_children():
		if not _is_valid_child(consideration):
			continue
		number_of_considerations += 1
		sum_of_scores += consideration.calculate_score()

	if number_of_considerations == 0:
		return 0.0

	return sum_of_scores / number_of_considerations


func _max():
	var max_score := 0.0
	for consideration in get_children():
		if not _is_valid_child(consideration):
			continue
		max_score = max(consideration.calculate_score(), max_score)
	return max_score


func _min():
	var min_score := 9999.0
	for consideration in get_children():
		if not _is_valid_child(consideration):
			continue
		min_score = min(consideration.calculate_score(), min_score)

	return min_score if min_score != 9999.0 else 0.0


func _weighted_average():
	var number_of_considerations := 0
	var weighted_sum := 0.0
	var total_weight := 0.0
	var children = get_children()
	
	for i in range(children.size()):
		var consideration = children[i]
		if not _is_valid_child(consideration):
			continue
		
		var weight = 1.0
		if i < weights.size() and weights[i] > 0.0:
			weight = weights[i]
		
		number_of_considerations += 1
		weighted_sum += consideration.calculate_score() * weight
		total_weight += weight
	
	if number_of_considerations == 0 or total_weight == 0.0:
		return 0.0
	
	return weighted_sum / total_weight


func _is_valid_child(consideration):
	if not (consideration is UtilityAiConsideration or consideration is UtilityAiAggregation):
		# Only warn once per child
		if not _warned_invalid_child.has(consideration):
			push_warning("aggregation '%s' has a child that is not a consideration: %s" % [self.name, consideration.name])
			_warned_invalid_child[consideration] = true
		return false
	return true


func _get_configuration_warnings():
	var warnings = []
	var considerations = self.get_child_count()

	if considerations == 0:
		warnings.push_back("Aggregation node has no child consideration")

	for consideration in self.get_children():
		if not (consideration is UtilityAiConsideration or consideration is UtilityAiAggregation):
			warnings.push_back("Child needs to be a UtilityAiConsideration or UtilityAiAggregation")

	return warnings
