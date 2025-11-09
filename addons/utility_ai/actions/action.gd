@tool
@icon("../icons/action.svg")
class_name UtilityAiAction extends UtilityAi

enum Status {
	IDLE,      ## Action is not running
	RUNNING,   ## Action is currently executing
	SUCCESS,   ## Action completed successfully
	FAILED     ## Action failed to complete
}

## Emitted when the action starts execution
signal action_started()
## Emitted when the action is stopped/interrupted
signal action_stopped()
## Emitted when the action completes successfully
signal action_completed()
## Emitted when the action fails
signal action_failed()

@export var _action_id = ""
## If true, this action cannot be interrupted by another action
@export var uninterruptible: bool = false
## If true, this action can run in parallel with others
@export var allow_parallel: bool = false
## Cooldown in seconds after the action completes during which it won't be reselected
@export var cooldown: float = 0.0

var status: Status = Status.IDLE
var _agent: UtilityAiAgent = null
var _last_completed_time: float = -1.0

##
## Id for the action. If not set, it returns the node name.
##
func get_action_id():
	return _action_id if _action_id != "" else self.name


func calculate_score() -> float:
	# Find the first valid consideration or aggregation child and use it to calculate score.
	for child in get_children():
		if child is UtilityAiConsideration or child is UtilityAiAggregation:
			# Both types expose calculate_score()
			return child.calculate_score()

	# No valid consideration found
	return 0.0


##
## Called when the action starts. Override this method to implement initialization logic.
## @param agent: Reference to the UtilityAiAgent that started this action
##
func start(agent: UtilityAiAgent) -> void:
	_agent = agent
	status = Status.RUNNING
	action_started.emit()


##
## Called when the action is stopped/interrupted. Override to implement cleanup logic.
##
func stop() -> void:
	status = Status.IDLE
	_agent = null
	action_stopped.emit()


##
## Called every frame while the action is running. Override to implement action logic.
## @param delta: Time elapsed since last frame
## @return: Current status (RUNNING, SUCCESS, or FAILED)
##
func tick(delta: float) -> Status:
	# Override in child classes
	return status


##
## Mark the action as successfully completed
##
func complete() -> void:
	status = Status.SUCCESS
	_last_completed_time = Time.get_ticks_msec() / 1000.0
	action_completed.emit()


func is_on_cooldown() -> bool:
	if cooldown <= 0.0:
		return false
	if _last_completed_time < 0.0:
		return false
	var now = Time.get_ticks_msec() / 1000.0
	return now - _last_completed_time < cooldown


##
## Mark the action as failed
##
func fail() -> void:
	status = Status.FAILED
	action_failed.emit()


##
## Check if the action is currently running
##
func is_running() -> bool:
	return status == Status.RUNNING


##
## Check if the action can be interrupted
##
func can_interrupt() -> bool:
	return not uninterruptible


func _get_configuration_warnings():
	var warnings = []
	var considerations = self.get_child_count()

	if considerations == 0:
		warnings.push_back("Action node has no child consideration")
	elif considerations > 1:
		warnings.push_back("Action node has more than one child. For multiple considerations use UtilityAiConsiderationAggregation")

	for consideration in self.get_children():
		if not (consideration is UtilityAiConsideration or consideration is UtilityAiAggregation):
			warnings.push_back("Child needs to be a UtilityAiConsideration or UtilityAiAggregation")

	return warnings
