
@tool
extends BeehaveNode

## Find food behavior leaf - searches for closest food and assigns it as the NPC target

var _has_started: bool = false

func before_run(actor: Node, blackboard: Node) -> void:
	_has_started = false
	if blackboard:
		blackboard.set_value("action_done", false, str(actor.get_instance_id()))

	print("[FindFoodLeaf] before_run called for actor: ", actor.name)
	# Prefer the NPC helper API to find closest food
	var closest = null
	if "get_closest_food" in actor:
		closest = actor.get_closest_food()
	else:
		# fallback to scanning the tree
		for food in get_tree().get_nodes_in_group("food"):
			if not is_instance_valid(food):
				continue
			var dist = actor.global_position.distance_to(food.global_position)
			if closest == null or dist < actor.global_position.distance_to(closest.global_position):
				closest = food

	if closest != null:
		if "set_target" in actor:
			actor.set_target(closest)
			_has_started = true
			print("[FindFoodLeaf] Assigned target: ", closest.name)
		elif actor.has_method("find_food"):
			actor.find_food()
			_has_started = true
	else:
		# no food available -> fail quickly
		if blackboard:
			blackboard.set_value("action_done", true, str(actor.get_instance_id()))

func tick(actor: Node, blackboard: Node) -> int:
	# If we couldn't start, fail immediately
	if not _has_started:
		if blackboard:
			blackboard.set_value("action_done", true, str(actor.get_instance_id()))
		return BeehaveNode.FAILURE

	# If the actor already has food, succeed
	if "has_food_in_pocked" in actor and actor.has_food_in_pocked:
		if blackboard:
			blackboard.set_value("action_done", true, str(actor.get_instance_id()))
		return BeehaveNode.SUCCESS

	# If actor has a target and is not yet arrived, keep running
	if "has_target" in actor and actor.has_target():
		if actor.arrived():
			# consume target if it's food
			if "consume_target_if_food" in actor:
				actor.consume_target_if_food()
			if blackboard:
				blackboard.set_value("action_done", true, str(actor.get_instance_id()))
			return BeehaveNode.SUCCESS
		return BeehaveNode.RUNNING

	# No target and didn't find food -> complete/fail
	if blackboard:
		blackboard.set_value("action_done", true, str(actor.get_instance_id()))
	return BeehaveNode.FAILURE

func interrupt(actor: Node, blackboard: Node) -> void:
	# clear passive target if possible
	if "clear_target" in actor:
		actor.clear_target()
	if blackboard:
		blackboard.set_value("action_done", true, str(actor.get_instance_id()))
