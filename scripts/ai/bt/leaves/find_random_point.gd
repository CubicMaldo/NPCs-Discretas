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
	
	# Snap to navigation map to ensure reachability
	var map = npc.get_world_2d().navigation_map
	var closest_point = NavigationServer2D.map_get_closest_point(map, target_pos)
	
	blackboard.set_value("target_position", closest_point)
	return SUCCESS
