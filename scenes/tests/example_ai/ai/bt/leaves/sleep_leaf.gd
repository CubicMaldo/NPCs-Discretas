
@tool
extends BeehaveNode

## Sleep behavior leaf - uses passive API to put NPC to sleep until it wakes

func before_run(actor: Node, blackboard: Node) -> void:
	if blackboard:
		blackboard.set_value("action_done", false, str(actor.get_instance_id()))

	# trigger sleep if not already sleeping
	if "start_sleeping" in actor and "is_sleeping" in actor:
		if not actor.is_sleeping:
			actor.start_sleeping()
	elif actor.has_method("sleep") and "is_sleeping" in actor:
		if not actor.is_sleeping:
			actor.sleep()

func tick(actor: Node, blackboard: Node) -> int:
	# keep running while sleeping (NPC will wake up by its own energy handler)
	if "is_sleeping" in actor and actor.is_sleeping:
		return BeehaveNode.RUNNING

	# woke up - complete
	if blackboard:
		blackboard.set_value("action_done", true, str(actor.get_instance_id()))
	return BeehaveNode.SUCCESS

func interrupt(actor: Node, blackboard: Node) -> void:
	# stop sleeping if interrupted
	if "finish_sleeping" in actor:
		actor.finish_sleeping()
	elif actor.has_method("wake_up"):
		actor.wake_up()
	if blackboard:
		blackboard.set_value("action_done", true, str(actor.get_instance_id()))
