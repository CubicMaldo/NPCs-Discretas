@tool
extends UtilityAiAction
##
## Example action that demonstrates the new action lifecycle.
## This action makes the NPC eat food over time.
##
class_name ActionEat

var eating_time: float = 0.0
const EAT_DURATION: float = 3.0

func start(agent: UtilityAiAgent) -> void:
	super.start(agent)
	eating_time = 0.0
	
	var npc = agent.get_parent()
	# Use passive eating API if available
	if "start_eating" in npc:
		npc.start_eating()
	elif npc.has_method("eat"):
		npc.eat()

	print("[%s] Started eating" % agent.get_parent().name)


func tick(delta: float) -> Status:
	eating_time += delta
	
	if eating_time >= EAT_DURATION:
		# Finished eating
		var npc = _agent.get_parent()
		if npc:
			if "finish_eating" in npc:
				npc.finish_eating()
			else:
				# Fallback: set hunger and clear pocket
				npc.hunger = 0
				npc.has_food_in_pocked = false

		complete()
		return Status.SUCCESS
	
	return Status.RUNNING


func stop() -> void:
	super.stop()
	
	var npc = _agent.get_parent()
	if npc and npc.has_method("idle"):
		npc.idle()
	
	print("[%s] Stopped eating (interrupted)" % _agent.get_parent().name)
