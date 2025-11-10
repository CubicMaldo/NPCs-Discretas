
@tool
extends BeehaveNode

## Eat behavior leaf - uses passive API to start eating for a fixed duration

@export var eat_duration: float = 3.0

var _has_started: bool = false
var _start_time: float = 0.0

func before_run(actor: Node, blackboard: Node) -> void:
	_has_started = false
	_start_time = Time.get_ticks_msec() / 1000.0
	if blackboard:
		blackboard.set_value("action_done", false, str(actor.get_instance_id()))

	# Require that the actor has food
	if "has_food_in_pocked" in actor and actor.has_food_in_pocked:
		if "start_eating" in actor:
			actor.start_eating()
		elif actor.has_method("eat"):
			actor.eat()
		_has_started = true
	else:
		# nothing to eat
		if blackboard:
			blackboard.set_value("action_done", true, str(actor.get_instance_id()))

func tick(actor: Node, blackboard: Node) -> int:
	# If we couldn't start (no food), fail immediately
	if not _has_started:
		if blackboard:
			blackboard.set_value("action_done", true, str(actor.get_instance_id()))
		return BeehaveNode.FAILURE

	var now = Time.get_ticks_msec() / 1000.0
	if now - _start_time >= eat_duration:
		# finish eating
		if "finish_eating" in actor:
			actor.finish_eating()
		elif "is_eating" in actor and actor.is_eating:
			# fallback: if the actor has an async eat(), we assume it will finish itself
			pass
		if blackboard:
			blackboard.set_value("action_done", true, str(actor.get_instance_id()))
		return BeehaveNode.SUCCESS

	return BeehaveNode.RUNNING

func interrupt(actor: Node, blackboard: Node) -> void:
	# stop eating if interrupted
	if "finish_eating" in actor:
		actor.finish_eating()
	if blackboard:
		blackboard.set_value("action_done", true, str(actor.get_instance_id()))
