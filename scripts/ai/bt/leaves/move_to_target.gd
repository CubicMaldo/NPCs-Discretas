@tool
extends ActionLeaf

class_name MoveToTarget

func tick(actor: Node, blackboard: Blackboard) -> int:
	var npc = actor as NPC
	if not npc:
		return FAILURE
		
	var target_pos = blackboard.get_value("target_position", null)
	
	# If target is an NPC, update position dynamically
	var target_npc = blackboard.get_value("target_npc", null)
	if is_instance_valid(target_npc):
		target_pos = target_npc.global_position
		
	if target_pos == null:
		print("[%s] MoveToTarget: No target position!" % npc.name)
		return FAILURE
		
	# Check distance
	var dist = npc.global_position.distance_to(target_pos)
	if dist < 40.0: # Interaction range
		print("[%s] MoveToTarget: Reached destination (dist: %s)." % [npc.name, dist])
		npc.stop_moving()
		return SUCCESS
	
	# Check if we are already moving to this target
	if not npc.is_moving() or npc.navigation_agent.target_position != target_pos:
		npc.move_to(target_pos)
		npc.current_state = "walk"
		
	return RUNNING
