extends Node
##
## Example demonstrating UtilityAiBlackboard usage.
## Add this as a child of your NPC or as a global autoload.
##

class_name ExampleBlackboard

var blackboard: Node  # UtilityAiBlackboard

func _ready():
	# Create blackboard
	var blackboard_script = load("res://addons/utility_ai/utility_ai_blackboard.gd")
	blackboard = blackboard_script.new()
	add_child(blackboard)
	
	# Initialize values
	blackboard.set_value("hunger", 0.0)
	blackboard.set_value("energy", 100.0)
	blackboard.set_value("stress", 0.0)
	blackboard.set_value("health", 100.0)
	blackboard.set_value("has_weapon", false)
	blackboard.set_value("enemies_nearby", 0)
	
	# Watch for changes (reactive programming)
	blackboard.watch_key("health", _on_health_changed)
	blackboard.watch_key("enemies_nearby", _on_enemies_changed)
	
	# Connect to the global value_changed signal
	blackboard.value_changed.connect(_on_any_value_changed)


func _on_health_changed(new_value: float, old_value: float):
	print("Health changed from %.1f to %.1f" % [old_value, new_value])
	
	if new_value <= 20 and old_value > 20:
		print("⚠️ Low health warning!")


func _on_enemies_changed(new_value: int, old_value: int):
	if new_value > 0 and old_value == 0:
		print("⚠️ Enemies detected!")
	elif new_value == 0 and old_value > 0:
		print("✅ All clear!")


func _on_any_value_changed(_key: String, _new_value, _old_value):
	# Log all changes for debugging
	pass  # print("[Blackboard] %s: %s -> %s" % [_key, _old_value, _new_value])


# Example helper methods
func update_from_npc(npc):
	"""Update blackboard values from NPC state"""
	blackboard.set_value("hunger", npc.hunger)
	blackboard.set_value("energy", npc.energy)
	blackboard.set_value("stress", npc.stress)
	
	# Count enemies nearby
	var enemies = npc.get_tree().get_nodes_in_group("enemies")
	var nearby_count = 0
	for enemy in enemies:
		if npc.global_position.distance_to(enemy.global_position) < 100:
			nearby_count += 1
	blackboard.set_value("enemies_nearby", nearby_count)


func apply_to_npc(npc):
	"""Apply blackboard values back to NPC (useful after loading save)"""
	npc.hunger = blackboard.get_value("hunger", 0)
	npc.energy = blackboard.get_value("energy", 100)
	npc.stress = blackboard.get_value("stress", 0)


# Example: Save/Load
func save_to_file(path: String):
	var data = blackboard.to_dict()
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()
		print("Saved blackboard to: ", path)


func load_from_file(path: String):
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var data = file.get_var()
			blackboard.from_dict(data)
			file.close()
			print("Loaded blackboard from: ", path)


# Example: Debug display
func print_all_values():
	print("=== Blackboard State ===")
	for key in blackboard.get_keys():
		print("  %s: %s" % [key, blackboard.get_value(key)])
	print("========================")
