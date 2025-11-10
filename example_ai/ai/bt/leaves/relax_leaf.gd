@tool
extends BeehaveNode

## Relax behavior leaf - idle while in safe area to reduce stress

@export var duration: float = 4.0

var _start_time: float = 0.0

func before_run(actor: Node, blackboard: Node) -> void:
	_start_time = Time.get_ticks_msec() / 1000.0
	if blackboard:
		blackboard.set_value("action_done", false, str(actor.get_instance_id()))

	# play idle animation while relaxing via passive API if present
	if "idle" in actor:
		actor.idle()
	elif actor.has_method("idle"):
		actor.idle()

func tick(actor: Node, blackboard: Node) -> int:
	var now = Time.get_ticks_msec() / 1000.0
	
	# relax for a duration
	if now - _start_time >= duration:
		if blackboard:
			blackboard.set_value("action_done", true, str(actor.get_instance_id()))
		return BeehaveNode.SUCCESS
	
	return BeehaveNode.RUNNING

func interrupt(actor: Node, blackboard: Node) -> void:
	if blackboard:
		blackboard.set_value("action_done", true, str(actor.get_instance_id()))
