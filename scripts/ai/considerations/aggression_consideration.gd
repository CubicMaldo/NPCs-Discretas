@tool
extends UtilityAiConsideration

class_name AggressionConsideration

var _npc: NPC

func _ready() -> void:
	var parent = get_parent()
	while parent:
		if parent is NPC:
			_npc = parent
			break
		parent = parent.get_parent()

func score() -> float:
	if not _npc or not _npc.personality_component:
		return 0.0
		
	var aggression = _npc.personality_component.aggression
	var impulsivity = _npc.personality_component.impulsivity
	
	# Base score on aggression
	var final_score = aggression * 0.5
	
	# Add impulsivity factor
	if randf() < impulsivity * 0.1:
		final_score += 0.3
		
	# Reduce if we have many friends? (Optional)
	
	return clamp(final_score, 0.0, 1.0)
