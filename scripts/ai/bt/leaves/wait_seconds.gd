@tool
extends ActionLeaf

class_name WaitSeconds

@export var duration: float = 1.0
var _timer: float = 0.0

func tick(actor: Node, _blackboard: Blackboard) -> int:
	if actor is NPC:
		actor.current_state = "idle"

	if _timer <= 0.0:
		_timer = duration
		print("[%s] WaitSeconds: Waiting for %s seconds..." % [actor.name, duration])
		return RUNNING
		
	_timer -= get_physics_process_delta_time()
	if _timer <= 0.0:
		_timer = 0.0
		print("[%s] WaitSeconds: Finished waiting." % actor.name)
		return SUCCESS
		
	return RUNNING
