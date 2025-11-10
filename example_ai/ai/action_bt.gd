@tool
extends UtilityAiAction

##
## Example copy of ActionBT placed under example_refactor for demonstration.
## It behaves the same as the addon version but lives in the example folder.
##

@export var bt_scene: PackedScene
@export var bt_node_path: NodePath = NodePath(".")

var _bt_instance: Node = null

func start(agent: UtilityAiAgent) -> void:
	super.start(agent)

	if bt_scene == null:
		push_warning("No Behaviour Tree scene assigned to ActionBT '%s'" % name)
		fail()
		return

	_bt_instance = bt_scene.instantiate()
	if _bt_instance == null:
		push_warning("Failed to instantiate BT scene for ActionBT '%s'" % name)
		fail()
		return

	add_child(_bt_instance)

	# agent is stored by the parent action (UtilityAiAction._agent)

	# Special-case Beehave trees: assign the actor (the NPC, not the agent node) and enable ticking.
	if _bt_instance is BeehaveTree:
		# The actor should be the owner of the agent (the NPC CharacterBody2D),
		# not the UtilityAiAgent node itself
		var actual_actor = agent.get_parent()
		if actual_actor == null:
			push_warning("Agent has no parent (NPC). BT may not work correctly.")
			actual_actor = agent
		
		_bt_instance.actor = actual_actor
		# enable the tree so it will tick
		_bt_instance.enabled = true
		print("[ActionBT] Instantiated BeehaveTree for actor:", actual_actor.name, " (agent: ", agent.name, ")")

	elif _bt_instance.has_method("start"):
		_bt_instance.call("start")
	elif _bt_instance.has_method("run"):
		_bt_instance.call("run")
	else:
		push_warning("BT instance for ActionBT '%s' has no start/run method. Ensure beehave or proper runner exists." % name)

	status = Status.RUNNING
	action_started.emit()


func tick(_delta: float) -> Status:
	if _bt_instance == null:
		return status

	# If the instance is a BeehaveTree, we check the tree's blackboard for the action_done flag
	if _bt_instance is BeehaveTree:
		if _bt_instance.actor != null and _bt_instance.blackboard:
			var actor_id = str(_bt_instance.actor.get_instance_id())
			var has = _bt_instance.blackboard.has_value("action_done", actor_id)
			var done = false
			if has:
				done = _bt_instance.blackboard.get_value("action_done", false, actor_id)
			if done:
				complete()
				return Status.SUCCESS
		return Status.RUNNING

	# Generic runner fallback: check common runner methods
	if _bt_instance.has_method("is_running") and not _bt_instance.call("is_running"):
		complete()
		return Status.SUCCESS

	if _bt_instance.has_method("is_finished") and _bt_instance.call("is_finished"):
		complete()
		return Status.SUCCESS

	return Status.RUNNING


func stop() -> void:
	if _bt_instance != null:
		if _bt_instance.has_method("stop"):
			_bt_instance.call("stop")
		_bt_instance.queue_free()
		_bt_instance = null

	status = Status.IDLE
	action_stopped.emit()


func _get_configuration_warnings():
	var warnings = []
	if bt_scene == null:
		warnings.push_back("BT PackedScene not assigned")
	return warnings
