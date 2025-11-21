@tool
extends UtilityAiAction

class_name ActionBTWrapper

@export var bt_scene: PackedScene

var _bt_instance: Node = null

func start(agent: UtilityAiAgent) -> void:
	super.start(agent)
	print("[%s] Starting Action: %s" % [agent.get_parent().name, name])

	if bt_scene == null:
		push_warning("No Behaviour Tree scene assigned to ActionBT '%s'" % name)
		fail()
		return

	_bt_instance = bt_scene.instantiate()
	if _bt_instance == null:
		push_warning("Failed to instantiate BT scene for ActionBT '%s'" % name)
		_last_completed_time = Time.get_ticks_msec() / 1000.0 # Trigger cooldown
		fail()
		return

	add_child(_bt_instance)

	if _bt_instance is BeehaveTree:
		var actor = agent.get_parent()
		_bt_instance.actor = actor
		_bt_instance.enabled = true
		# Reset blackboard flags if needed
		_bt_instance.blackboard.set_value("action_done", false)
	
	status = Status.RUNNING
	action_started.emit()

func tick(_delta: float) -> Status:
	if _bt_instance == null:
		return status

	if _bt_instance is BeehaveTree:
		# Check if the tree has finished its sequence (custom logic or blackboard flag)
		# Note: Beehave 2.x might use different status codes or properties.
		# We check a custom blackboard flag "action_done" set by our leaves.
		if _bt_instance.blackboard and _bt_instance.blackboard.get_value("action_done", false):
			print("[%s] Action %s DONE (Blackboard Flag)" % [_agent.get_parent().name, name])
			complete()
			return Status.SUCCESS
			
		# Also check if the tree status is SUCCESS/FAILURE directly
		if _bt_instance.status == 0: # SUCCESS
			print("[%s] Action %s SUCCESS (Tree Status)" % [_agent.get_parent().name, name])
			complete()
			return Status.SUCCESS
		if _bt_instance.status == 1: # FAILURE
			print("[%s] Action %s FAILED (Tree Status)" % [_agent.get_parent().name, name])
			_last_completed_time = Time.get_ticks_msec() / 1000.0 # Trigger cooldown
			fail()
			return Status.FAILED
			
	return Status.RUNNING

func stop() -> void:
	var _actor_name = "Unknown"
	if _agent and _agent.get_parent():
		_actor_name = _agent.get_parent().name
	if _bt_instance != null:
		if _bt_instance.has_method("stop"):
			_bt_instance.call("stop")
		_bt_instance.queue_free()
		_bt_instance = null

	status = Status.IDLE
	action_stopped.emit()
