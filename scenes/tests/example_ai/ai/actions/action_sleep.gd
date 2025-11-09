@tool
extends UtilityAiAction
##
## Example action for sleeping to restore energy.
##
class_name ActionSleep

var sleep_location = null

func start(agent: UtilityAiAgent) -> void:
	super.start(agent)
	var npc = agent.get_parent()

	# Find a sleep location (firepit) and assign via passive API
	# Prefer NPC helper to locate closest shelter
	if "get_closest_shelter" in npc:
		sleep_location = npc.get_closest_shelter()
		if sleep_location != null and "set_target" in npc:
			npc.set_target(sleep_location)
	else:
		var shelter = npc.get_tree().get_nodes_in_group("firepit")
		if shelter.size() > 0:
			sleep_location = shelter[0]
			if "set_target" in npc:
				npc.set_target(sleep_location)

	print("[%s] Going to sleep" % npc.name)


func tick(delta: float) -> Status:
	var npc = _agent.get_parent()
	
	# If not at location, move there first
	# If npc uses passive API and has target, check arrival
	if "has_target" in npc and npc.has_target():
		if not npc.arrived(5.0):
			return Status.RUNNING
		# arrived -> start sleeping
		if "start_sleeping" in npc:
			npc.start_sleeping()
		elif npc.has_method("sleep"):
			npc.sleep()
		# now wait until energy filled
		if npc.energy >= 100:
			if "finish_sleeping" in npc:
				npc.finish_sleeping()
			complete()
			return Status.SUCCESS
		return Status.RUNNING

	# fallback: manual movement to sleep_location
	if sleep_location != null and npc.global_position.distance_to(sleep_location.global_position) > 5:
		var direction = npc.global_position.direction_to(sleep_location.global_position)
		npc.move_to(direction, delta)
		return Status.RUNNING

	# Start sleeping if not already
	if not npc.is_sleeping:
		if "start_sleeping" in npc:
			npc.start_sleeping()
		else:
			npc.sleep()

	# Check if fully rested
	if npc.energy >= 100:
		if "finish_sleeping" in npc:
			npc.finish_sleeping()
		else:
			npc.wake_up()
		complete()
		return Status.SUCCESS

	return Status.RUNNING


func stop() -> void:
	super.stop()
	var npc = _agent.get_parent()
	# clear passive target and stop sleeping if needed
	if "clear_target" in npc:
		npc.clear_target()
	if "finish_sleeping" in npc and npc.is_sleeping:
		npc.finish_sleeping()
	elif npc.is_sleeping:
		npc.wake_up()
