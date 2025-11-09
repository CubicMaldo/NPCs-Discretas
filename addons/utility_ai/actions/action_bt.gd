@tool
@icon("../icons/action.svg")
extends UtilityAiAction

##
## Action that runs a Behaviour Tree (Beehave) PackedScene.
## If the beehave addon is not available, it will warn and complete/failed gracefully.
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

	# Instantiate the tree and try to add as child of this action node
	_bt_instance = bt_scene.instantiate()
	if _bt_instance == null:
		push_warning("Failed to instantiate BT scene for ActionBT '%s'" % name)
		fail()
		return

	add_child(_bt_instance)

	# If the project has beehave, try to start the runner. We check for common API names to remain tolerant.
	# Known implementations expose a `start()` or `run()` method on a runner node.
	if _bt_instance.has_method("start"):
		_bt_instance.call("start")
	elif _bt_instance.has_method("run"):
		_bt_instance.call("run")
	else:
		# Not a runnable BT from beehave - we still keep it as a visual subtree, mark success or fail.
		push_warning("BT instance for ActionBT '%s' has no start/run method. Ensure beehave or proper runner exists." % name)

	status = Status.RUNNING
	action_started.emit()


func tick(delta: float) -> Status:
	# If there's no instance, fail
	if _bt_instance == null:
		return status

	# If the BT exposes a status property or method, check for completion
	# This is best-effort: different BT runners expose different APIs.
	if _bt_instance.has_method("is_running") and not _bt_instance.call("is_running"):
		# assume completed
		complete()
		return Status.SUCCESS

	if _bt_instance.has_method("is_finished") and _bt_instance.call("is_finished"):
		complete()
		return Status.SUCCESS

	# If BT runner exposes last_status or similar, we could inspect it; otherwise remain RUNNING.
	return Status.RUNNING


func stop() -> void:
	# Try to stop/cleanup the bt instance gracefully
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
