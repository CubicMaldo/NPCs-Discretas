@tool
extends ActionLeaf

class_name FindRandomPoint

func tick(actor: Node, blackboard: Blackboard) -> int:
	var npc = actor as NPC
	if not npc:
		return FAILURE
		
	var radius = 200.0
	var random_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(50, radius)
	var target_pos = npc.global_position + random_offset
	
	blackboard.set_value("target_position", target_pos)
	return SUCCESS
