@tool
extends ActionLeaf

class_name PerformInteraction

func tick(actor: Node, blackboard: Blackboard) -> int:
	var npc = actor as NPC
	if not npc:
		return FAILURE
		
	var target_npc = blackboard.get_value("target_npc", null)
	if not is_instance_valid(target_npc):
		return FAILURE
		
	# Perform interaction
	print("[%s] PerformInteraction: Interacting with %s" % [npc.name, target_npc.name])
	npc.interact_with(target_npc)
	npc.current_state = "interact"
	
	# Mark action as done for the wrapper

	blackboard.set_value("action_done", true)
	
	return SUCCESS
