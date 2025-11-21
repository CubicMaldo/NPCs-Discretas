@tool
extends UtilityAiConsideration

class_name SocialDesireConsideration

var _npc: NPC

func _ready() -> void:
	# Traverse up to find the NPC. 
	# Structure: NPC -> UtilityAiAgent -> Action -> Consideration
	var parent = get_parent()
	while parent:
		if parent is NPC:
			_npc = parent
			break
		parent = parent.get_parent()

func score() -> float:
	if not _npc:
		return 0.0
		
	var final_score = 0.5
	
	# Increase if lonely (no recent interactions)
	# (Placeholder for actual memory system)
	
	# Increase based on personality
	# Increase based on personality
	if _npc.personality_component and _npc.personality_component.extraversion > 0.6:
		final_score += 0.2
		
	# Decrease if currently moving to a high priority target?
	
	#print("[%s] SocialDesire Score: %s" % [_npc.name, final_score])
	return clamp(final_score, 0.0, 1.0)
