@tool
extends ActionLeaf

class_name PerformFight

func tick(actor: Node, blackboard: Blackboard) -> int:
	var npc = actor as NPC
	if not npc:
		return FAILURE
		
	var target_npc = blackboard.get_value("target_npc", null)
	if not is_instance_valid(target_npc):
		return FAILURE
		
	# Perform fight interaction
	npc.fight_with(target_npc)
	npc.current_state = "fighting"
	
	# Mark action as done
	blackboard.set_value("action_done", true)
	
	return SUCCESS
