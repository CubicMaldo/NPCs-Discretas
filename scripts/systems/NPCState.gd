extends Resource
class_name NPCState

@export var state_name: String = "base"
@export var priority: int = 0

func enter(_npc: Node) -> void:
	# Override in subclasses to initialize per-instance data
	pass

func exit(_npc: Node) -> void:
	# Override to cleanup
	pass

func physics_process(_npc: Node, _delta: float) -> void:
	# Override to run per-frame logic
	pass

func evaluate(_npc: Node) -> NPCState:
	# Optionally return a suggested next state (or null to defer)
	return null
