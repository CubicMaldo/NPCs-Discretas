
@tool
extends BeehaveNode

## Find shelter behavior leaf - moves NPC to nearest firepit and marks it safe

var _has_started: bool = false

func before_run(actor: Node, blackboard: Node) -> void:
	_has_started = false
	if blackboard:
		blackboard.set_value("action_done", false, str(actor.get_instance_id()))

	# Prefer the NPC helper API to find closest shelter
	var closest = null
	if "get_closest_shelter" in actor:
		closest = actor.get_closest_shelter()
	else:
		for fp in get_tree().get_nodes_in_group("firepit"):
			if not is_instance_valid(fp):
				continue
			var dist = actor.global_position.distance_to(fp.global_position)
			if closest == null or dist < actor.global_position.distance_to(closest.global_position):
				closest = fp

	if closest != null:
		if "set_target" in actor:
			actor.set_target(closest)
			_has_started = true
			print("[FindShelterLeaf] Assigned shelter: ", closest.name)
		elif actor.has_method("find_shelter"):
			actor.find_shelter()
			_has_started = true
	else:
		if blackboard:
			blackboard.set_value("action_done", true, str(actor.get_instance_id()))

func tick(actor: Node, blackboard: Node) -> int:
	if not _has_started:
		if blackboard:
			blackboard.set_value("action_done", true, str(actor.get_instance_id()))
		return BeehaveNode.FAILURE

	# if actor reached safety, succeed
	if "is_safe" in actor and actor.is_safe:
		if blackboard:
			blackboard.set_value("action_done", true, str(actor.get_instance_id()))
		return BeehaveNode.SUCCESS

	# if actor has target, check arrival
	if "has_target" in actor and actor.has_target():
		if actor.arrived():
			if "set_is_safe" in actor:
				actor.set_is_safe(true)
			else:
				actor.is_safe = true
			if blackboard:
				blackboard.set_value("action_done", true, str(actor.get_instance_id()))
			return BeehaveNode.SUCCESS
		return BeehaveNode.RUNNING

	# fallback: complete
	if blackboard:
		blackboard.set_value("action_done", true, str(actor.get_instance_id()))
	return BeehaveNode.FAILURE

func interrupt(actor: Node, blackboard: Node) -> void:
	if "clear_target" in actor:
		actor.clear_target()
	if blackboard:
		blackboard.set_value("action_done", true, str(actor.get_instance_id()))
