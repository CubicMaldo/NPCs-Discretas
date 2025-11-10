extends CharacterBody2D

var is_moving = false

# those are being exported so we can modify
# the initial value in the example
@export var hunger : float = 0
@export var stress : float = 0
@export var energy : float = 100

var is_sleeping = false
var is_eating = false

var looking_for_food = false
var looking_for_shelter = false

var has_food_in_pocked = false

var is_safe = true

func set_is_safe(value):
	is_safe = value
	if is_safe and looking_for_shelter:
		looking_for_shelter = false
		_target = null
		$body.play("idle")


var _target


func _process(delta):
	_handle_energy(delta)
	_handle_hunger(delta)
	_handle_stress(delta)
	_handle_target(delta)


func move_to(direction, delta):
	is_moving = true
	$body.play("run")
	if direction.x > 0:
		turn_right()
	else:
		turn_left()

  # warning-ignore:return_value_discarded
	move_and_collide(direction * delta * 100)


func turn_right():
	if not $body.flip_h:
		return

	$body.flip_h = false


func turn_left():
	if $body.flip_h:
		return

	$body.flip_h = true


func _handle_energy(delta: float):
	if is_sleeping:
		energy += delta * 4
		if energy >= 100:
			energy = 100
			wake_up()
	else:
		energy -= delta * 2
		if energy <= 0:
			energy = 0
			sleep()

	$energy_bar.value = energy


func _handle_hunger(delta: float):
	hunger = clampf(hunger + delta * 5, 0, 100)
	$hunger_bar.value = hunger


func _handle_stress(delta: float):
	if is_safe:
		stress -= delta * 4
	else:
		stress += delta * 2

	stress = clampf(stress, 0, 100)

	$stress_bar.value = stress


func _handle_target(delta: float):
	if is_sleeping:
		return
	if not is_instance_valid(_target):
		# passive NPC: when target disappears we just clear it and wait for BT to assign a new one
		_target = null
		return

	if self.global_position.distance_to(_target.global_position) <= 1:
		# arrived at target — we become idle and let the BT (actor) decide what to do next
		$body.play("idle")
		_target = null
		return

	move_to(self.global_position.direction_to(_target.global_position), delta)



func sleep():
	$body.play("sleep")
	is_sleeping = true


func wake_up():
	$body.play("idle")
	is_sleeping = false


func idle():
	$body.play("idle")
	print("[NPC] Playing idle animation")


func eat():
	print("[NPC] Starting to eat")
	is_eating = true
	$body.play("eat")
	$body/mushroom.show()
	await get_tree().create_timer(3).timeout
	hunger = 0
	$hunger_bar.value = 0
	has_food_in_pocked = false
	is_eating = false
	$body/mushroom.hide()
	$body.play("idle")
	print("[NPC] Finished eating")


func find_food():
	looking_for_food = true
	var closest = _get_closest_food()
	if closest != null:
		_target = closest
		print("[NPC] Finding food, target set to: ", closest.name)
	else:
		print("[NPC] No food available to find")
		looking_for_food = false


func _get_closest_food():
	var closest = null
	var closest_distance = null
	for food in get_tree().get_nodes_in_group("food"):
		var dist = self.global_position.distance_to(food.global_position)
		if closest_distance == null or closest_distance > dist:
			closest_distance = dist
			closest = food

	return closest


func get_closest_food():
	"""Public helper for BT/actions to query the closest food node.
	Keeps the scan centralized on the NPC for easier maintenance and testing."""
	return _get_closest_food()


func get_closest_shelter():
	"""Public helper to find the closest firepit (shelter).
	Returns null if none found."""
	var closest = null
	var closest_distance = null
	for fp in get_tree().get_nodes_in_group("firepit"):
		var dist = self.global_position.distance_to(fp.global_position)
		if closest_distance == null or dist < closest_distance:
			closest_distance = dist
			closest = fp

	return closest


func find_shelter():
	looking_for_shelter = true
	var firepits = get_tree().get_nodes_in_group("firepit")
	if firepits.size() > 0:
		var shelter = firepits[0]
		_target = shelter
		print("[NPC] Finding shelter, target set to: ", shelter.name)
	else:
		print("[NPC] No firepit available")
		looking_for_shelter = false


# --- Passive helper API for BT ---
func set_target(node):
	"""Assign a target for the NPC to move towards. BT should call this."""
	_target = node


func clear_target():
	"""Clear current target and passive flags."""
	_target = null
	looking_for_food = false
	looking_for_shelter = false


func has_target() -> bool:
	return is_instance_valid(_target)


func arrived(threshold: float = 1.0) -> bool:
	return is_instance_valid(_target) and self.global_position.distance_to(_target.global_position) <= threshold


func consume_target_if_food():
	"""If the current target is a food node, consume it (called by BT when appropriate)."""
	if is_instance_valid(_target) and _target.is_in_group("food"):
		_target.queue_free()
		has_food_in_pocked = true
		_target = null


func start_eating():
	"""Begin eating animation/state; BT should call finish_eating() when appropriate."""
	is_eating = true
	$body.play("eat")


func finish_eating():
	"""Finalize eating (reset hunger, hide food visuals)."""
	is_eating = false
	hunger = 0
	$hunger_bar.value = 0
	has_food_in_pocked = false
	$body.play("idle")


func start_sleeping():
	is_sleeping = true
	$body.play("sleep")


func finish_sleeping():
	is_sleeping = false
	$body.play("idle")



func _on_utility_ai_agent_top_score_action_changed(top_action_id):
	print("Action changed: %s" % top_action_id)
	# The BT trees now handle the execution via ActionBT wrapper
	# No need to manually trigger methods here
