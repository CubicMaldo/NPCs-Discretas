extends "res://scripts/systems/NPCState.gd"
class_name IdleState

@export var min_duration: float = 0.5
@export var max_duration: float = 2.0

var _timer: float = 0.0
var _duration: float = 1.0

func enter(npc: Node) -> void:
    _duration = lerp(min_duration, max_duration, randf())
    _timer = 0.0
    # Optionally trigger idle animation
    if "sprite" in npc and npc.sprite:
        # Example: set animation or frame if available
        pass

func physics_process(_npc: Node, _delta: float) -> void:
    _timer += _delta

func evaluate(_npc: Node) -> NPCState:
    # If timer finished, let behavior system or external decide next state
    if _timer >= _duration:
        return null
    return null
