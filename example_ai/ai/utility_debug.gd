extends Node2D

@export var utility_agent: UtilityAiAgent = null

var elements = {}

var show_only_top = false

# Called when the node enters the scene tree for the first time.
func _ready():
	if utility_agent != null:
		_setup_actions()


func _process(_delta):
	if utility_agent == null or not self.visible:
		return
	if elements.is_empty():
		_setup_actions()
	else:
		_update_scores()


func _setup_actions():
	var scores = utility_agent.get_all_scores()
	for score in scores:
		var container = $PanelContainer/MarginContainer/score_list/action_score.duplicate()
		elements[score.action] = {
			"container": container,
			"details": null,
			"node": score.node
		}

		container.get_node("label").text = score.action
		container.get_node("score").text = "%.3f" % score.score
		$PanelContainer/MarginContainer/score_list.add_child(container)
		container.show()

		# build details (considerations breakdown)
		_build_details_for_action(score.action, score.node)


func _update_scores():
	var scores = utility_agent.get_all_scores()
	var top = scores[0].action
	for score in scores:
		var is_top_action = score.action == top
		var data = elements[score.action]
		var container = data["container"]
		container.get_node("label").text = score.action
		container.get_node("score").text = "%.3f" % score.score
		container.modulate = Color("#b4d433") if is_top_action else Color("#ffffff")
		_adjust_container_visibility(container, is_top_action)
		_update_details_for_action(score.action, score.node)



func _build_details_for_action(action_id: String, action_node: Node) -> void:
	# Create a small VBox with each consideration name and its score
	var container = elements[action_id]["container"]
	var details = VBoxContainer.new()
	details.name = "details"
	details.visible = false

	# Iterate action children to find considerations/aggregations
	for child in action_node.get_children():
		if child is UtilityAiConsideration:
			var lbl = Label.new()
			lbl.text = "%s: %.3f" % [child.name, child.calculate_score()]
			details.add_child(lbl)
		elif child is UtilityAiAggregation:
			# show aggregation node and its children
			var agg_lbl = Label.new()
			agg_lbl.text = "%s: %.3f" % [child.name, child.calculate_score()]
			details.add_child(agg_lbl)
			for sub in child.get_children():
				if sub is UtilityAiConsideration:
					var sub_lbl = Label.new()
					sub_lbl.text = "  - %s: %.3f" % [sub.name, sub.calculate_score()]
					details.add_child(sub_lbl)

	# attach details under the action container
	container.add_child(details)
	elements[action_id]["details"] = details


func _update_details_for_action(action_id: String, action_node: Node) -> void:
	var details = elements[action_id]["details"]
	if details == null:
		return

	# update each label based on current ordering of children
	var idx = 0
	for child in action_node.get_children():
		if child is UtilityAiConsideration:
			if idx < details.get_child_count():
				details.get_child(idx).text = "%s: %.3f" % [child.name, child.calculate_score()]
				idx += 1
		elif child is UtilityAiAggregation:
			if idx < details.get_child_count():
				details.get_child(idx).text = "%s: %.3f" % [child.name, child.calculate_score()]
				idx += 1
			for sub in child.get_children():
				if sub is UtilityAiConsideration:
					if idx < details.get_child_count():
						details.get_child(idx).text = "  - %s: %.3f" % [sub.name, sub.calculate_score()]
						idx += 1


func _adjust_container_visibility(container, is_top_action):
	if show_only_top:
		$PanelContainer/MarginContainer/score_list/action_score.hide()
		container.visible = is_top_action
		if container.visible:
			container.get_node("label").custom_minimum_size.x = 0
			container.get_node("score").visible = false
	else:
		$PanelContainer/MarginContainer/score_list/action_score.show()
		container.get_node("label").custom_minimum_size.x = 140
		container.get_node("score").visible = true
		container.visible = true
