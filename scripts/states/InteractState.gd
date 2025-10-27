extends NPCState
class_name InteractState

@export var duration: float = 1.5

var _timer: float = 0.0

func enter(_npc: Node) -> void:
    _timer = 0.0

func physics_process(_npc: Node, _delta: float) -> void:
    _timer += _delta

func evaluate(_npc: Node) -> NPCState:
    if _timer >= duration:
        return null
    return null
