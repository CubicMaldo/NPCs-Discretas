@tool
extends UtilityAiConsideration


class_name FixedScoreConsideration

@export var base_score: float = 0.1

func score() -> float:
	# print("FixedScore: %s" % base_score)
	return base_score
