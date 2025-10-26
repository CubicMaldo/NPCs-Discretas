class_name Edge
extends Resource

@export var source: int = -1
@export var target: int = -1
@export var affinity: float = 0.0

func _init(_s: int = -1, _t: int = -1, _w: float = 0.0):
    source = _s
    target = _t
    affinity = _w
