@icon("../icons/agent.svg")
##
## Utility AI Agent that process and notify the highest utility action available.
##
class_name UtilityAiAgent extends UtilityAi

## Emitted when the highest scored action changed.
signal top_score_action_changed(top_action_id)
## Emitted when an action starts executing
signal action_started(action_id)
## Emitted when an action stops executing
signal action_stopped(action_id)
## Emitted when an action is interrupted by another
signal action_preempted(old_action_id, new_action_id)

## Enable or disable the agent
@export var enabled: bool = true
## Time interval between action evaluations (0 = every frame)
@export var sampling_interval: float = 0.0
## Minimum score difference required to change actions (prevents oscillation)
@export var hysteresis_margin: float = 0.0
## If true, the agent will automatically execute actions (start/tick/stop)
@export var auto_execute_actions: bool = false
## Time in seconds to temporarily block re-selecting an action immediately after it was stopped
@export var post_stop_block_time: float = 0.15

var _current_top_action: UtilityAiAction = null
var _current_top_action_id: String = ""
var _action_scores = []
var _score_sorted = false
var _time_since_last_evaluation: float = 0.0
var _warned_no_actions: bool = false
var _last_stopped_action_id: String = ""
var _last_stopped_time: float = -1.0


func _physics_process(delta):
	if not enabled:
		return
	
	# Tick current action if auto-executing
	if auto_execute_actions and _current_top_action != null and _current_top_action.is_running():
		var action_status = _current_top_action.tick(delta)
		if action_status == UtilityAiAction.Status.SUCCESS or action_status == UtilityAiAction.Status.FAILED:
			_stop_current_action()
	
	# Check if it's time to evaluate actions
	_time_since_last_evaluation += delta
	if _time_since_last_evaluation >= sampling_interval:
		_time_since_last_evaluation = 0.0
		_process_actions()


func _process_actions():
	var actions = self.get_children()

	if actions.size() == 0:
		if not _warned_no_actions:
			push_warning("Utility AI agent '%s' should have at least one action as child node" % name)
			_warned_no_actions = true
		return

	var top_action = _get_highest_utility_action(actions)
	
	if top_action == null:
		return
	
	var top_action_id = top_action.get_action_id()
	var top_score = _get_action_score(top_action_id)
	
	# Check if we should switch actions
	if _should_switch_action(top_action, top_action_id, top_score):
		_switch_to_action(top_action, top_action_id)


func _should_switch_action(new_action: UtilityAiAction, new_action_id: String, new_score: float) -> bool:
	# No current action, always switch
	if _current_top_action == null:
		return true
	
	# Same action, don't switch
	if new_action_id == _current_top_action_id:
		return false
	
	# Current action is uninterruptible
	if _current_top_action.is_running() and not _current_top_action.can_interrupt():
		return false
	
	# Apply hysteresis: new action must be significantly better
	var current_score = _get_action_score(_current_top_action_id)
	if new_score <= current_score + hysteresis_margin:
		return false
	
	return true


func _switch_to_action(new_action: UtilityAiAction, new_action_id: String):
	var old_action_id = _current_top_action_id
	
	# Stop current action if auto-executing
	if auto_execute_actions and _current_top_action != null and _current_top_action.is_running():
		_stop_current_action()
		if old_action_id != "":
			action_preempted.emit(old_action_id, new_action_id)
	
	# Update current action
	_current_top_action = new_action
	_current_top_action_id = new_action_id
	
	# Start new action if auto-executing
	if auto_execute_actions:
		new_action.start(self)
		action_started.emit(new_action_id)
	
	# Emit change signal
	top_score_action_changed.emit(new_action_id)


func _stop_current_action():
	if _current_top_action == null:
		return

	# Always call stop to ensure the action can clean up (e.g., disable running BTs).
	# Some actions may have already transitioned to SUCCESS/FAILED and are no longer "running",
	# but we still want to invoke their stop() to free resources and emit the stopped signal.
	_current_top_action.stop()
	action_stopped.emit(_current_top_action_id)

	# Record the stopped action and timestamp to prevent immediate re-selection.
	# This mechanism ensures that after an action is stopped, it cannot be selected again
	# for a short period defined by post_stop_block_time, which helps reduce rapid flickering
	# between actions and provides a buffer before the same action can be reconsidered.
	_last_stopped_action_id = _current_top_action_id
	_last_stopped_time = Time.get_ticks_msec() / 1000.0

	# Clear current action so subsequent evaluations can choose/restart as necessary.
	_current_top_action = null
	_current_top_action_id = ""


func _get_action_score(action_id: String) -> float:
	for score_data in _action_scores:
		if score_data["action"] == action_id:
			return score_data["score"]
	return 0.0


func _get_highest_utility_action(actions: Array) -> UtilityAiAction:
	var top_action: UtilityAiAction = null
	var top_action_utility = -1.0

	var all_scores = []

	for action in actions:
		if not (action is UtilityAiAction):
			push_warning("Child '%s' of agent '%s' is not an action" % [action.name, name])
			continue

		# Skip actions that are on cooldown
		if action.is_on_cooldown():
			# treat as score 0 and don't select
			all_scores.push_back({
				"action": action.get_action_id(),
				"score": 0.0,
				"node": action
			})
			continue

		# Skip an action that was just stopped recently to avoid immediate re-selection (reduces flicker)
		if _last_stopped_action_id != "":
			var now = Time.get_ticks_msec() / 1000.0
			if action.get_action_id() == _last_stopped_action_id and now - _last_stopped_time < post_stop_block_time:
				all_scores.push_back({"action": action.get_action_id(), "score": 0.0, "node": action})
				continue
		
		var score = action.calculate_score()
		# Clamp score to valid range
		score = clampf(score, 0.0, 1.0)

		all_scores.push_back({
			"action": action.get_action_id(),
			"score": score,
			"node": action
		})

		if score > top_action_utility:
			top_action_utility = score
			top_action = action

	_action_scores = all_scores
	_score_sorted = false

	return top_action


##
## Returns a sorted list with all scores calculated from highest to lowest.
## It does not trigger a re-calculation. It uses the last calculated score.
##
## Array<{ "action": string, "score": float, "node": UtilityAiAction }>
##
func get_all_scores() -> Array:
	if not _score_sorted:
		_action_scores.sort_custom(func(a, b): return a.score > b.score)
		_score_sorted = true
	return _action_scores


##
## Get the currently active action
##
func get_current_action() -> UtilityAiAction:
	return _current_top_action


##
## Get the ID of the currently active action
##
func get_current_action_id() -> String:
	return _current_top_action_id


##
## Manually trigger action evaluation
##
func evaluate_actions() -> void:
	_process_actions()
