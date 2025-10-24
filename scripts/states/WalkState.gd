extends "res://scripts/systems/NPCState.gd"
class_name WalkState

@export var speed: float = 60.0
@export var wander_radius: float = 64.0

var _target: Vector2 = Vector2.ZERO

func enter(npc: Node) -> void:
    # Choose a simple random target near current position
    var angle := randf() * TAU
    var r := randf() * wander_radius
    _target = npc.global_position + Vector2(cos(angle), sin(angle)) * r

func physics_process(_npc: Node, _delta: float) -> void:
    # Minimal walk logic: move towards target if NPC has a velocity or movement method
    if not _npc:
        return
    var dir: Vector2 = (_target - _npc.global_position)
    if dir.length() < 4.0:
        return
    dir = dir.normalized()
    if _npc.has_method("move_and_slide"):
        _npc.move_and_slide(dir * speed)
    elif _npc.has_method("set_velocity"):
        _npc.set_velocity(dir * speed)

func evaluate(_npc: Node) -> NPCState:
    return null
