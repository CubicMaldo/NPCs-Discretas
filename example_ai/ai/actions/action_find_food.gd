@tool
extends UtilityAiAction
##
## Example action for finding and moving to food.
##
class_name ActionFindFood

var target_food = null

func start(agent: UtilityAiAgent) -> void:
	super.start(agent)
	var npc = agent.get_parent()

	# Prefer NPC helper to find closest food
	if "get_closest_food" in npc:
		target_food = npc.get_closest_food()
	else:
		target_food = _get_closest_food(npc)

	if target_food == null:
		fail()
		return

	if "set_target" in npc:
		npc.set_target(target_food)
	else:
		# fallback: mark looking_for_food and store target
		npc.looking_for_food = true
		print("[%s] Finding food at %s" % [npc.name, target_food.global_position])


func tick(delta: float) -> Status:
	var npc = _agent.get_parent()

	if not is_instance_valid(target_food):
		fail()
		return Status.FAILED

	# If npc has passive API, check arrival via has_target/arrived
	if "has_target" in npc and npc.has_target():
		if npc.arrived():
			# let the npc consume the food if possible
			if "consume_target_if_food" in npc:
				npc.consume_target_if_food()
			complete()
			return Status.SUCCESS
		# otherwise keep moving implied by NPC
		return Status.RUNNING

	# Fallback: manual movement towards the stored target
	if npc.global_position.distance_to(target_food.global_position) <= 1:
		# consume
		target_food.queue_free()
		npc.has_food_in_pocked = true
		npc.looking_for_food = false
		complete()
		return Status.SUCCESS

	var direction = npc.global_position.direction_to(target_food.global_position)
	npc.move_to(direction, delta)

	return Status.RUNNING


func stop() -> void:
	super.stop()

	var npc = _agent.get_parent()
	# clear passive target if present
	if "clear_target" in npc:
		npc.clear_target()
	else:
		npc.looking_for_food = false

	if npc.has_method("idle"):
		npc.idle()


func _get_closest_food(npc):
	var closest = null
	var closest_distance = null
	
	for food in npc.get_tree().get_nodes_in_group("food"):
		var dist = npc.global_position.distance_to(food.global_position)
		if closest_distance == null or closest_distance > dist:
			closest_distance = dist
			closest = food
	
	return closest
