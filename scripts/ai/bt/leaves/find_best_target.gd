@tool
extends ActionLeaf


class_name FindBestTarget

func tick(actor: Node, blackboard: Blackboard) -> int:
	var npc = actor as NPC
	if not npc:
		return FAILURE

	var social_manager = npc.social_graph_manager
	if not social_manager:
		print("[%s] FindBestTarget: No SocialManager!" % npc.name)
		return FAILURE
		
	# Get neighbors from graph
	var neighbors = social_manager.get_cached_neighbors(npc)

	
	# Discovery Logic: Check InteractionZone for new NPCs
	var interaction_zone = npc.get_node_or_null("InteractionZone")
	if interaction_zone:
		for body in interaction_zone.get_overlapping_bodies():
			if body is NPC and body != npc:
				# If not in graph (or not neighbors), add connection/relationship
				if not social_manager.has_connection(npc, body):
					# Auto-introduce
					npc.social_component.set_relationship(body, 0.1)
					print("[%s] Discovered %s!" % [npc.name, body.name])
					# Refresh neighbors list
					neighbors = social_manager.get_cached_neighbors(npc)

	if neighbors.is_empty():
		print("[%s] FindBestTarget: No neighbors found (Graph empty & no one in InteractionZone)." % npc.name)
		return FAILURE


	var best_target = null
	var best_score = -100.0
	
	for neighbor in neighbors:
		if neighbor == npc: continue
		
		var score = 0.0
		# 1. Familiarity
		score += npc.get_familiarity(neighbor) * 10.0
		
		# 2. Distance (closer is better)
		var dist = npc.global_position.distance_to(neighbor.global_position)
		score -= dist * 0.05
		
		# 3. Emotion/Personality (placeholder)
		# if npc.personality.is_extrovert: score += 5.0
		
		if score > best_score:
			best_score = score
			best_target = neighbor
			
	if best_target:
		blackboard.set_value("target_npc", best_target)
		blackboard.set_value("target_position", best_target.global_position)
		return SUCCESS
		
	return FAILURE
