class_name Vertex
extends Resource

@export var id: int = -1
var meta: Dictionary = {}

func _init(_id: int = -1, _meta: Dictionary = {}):
    id = _id
    meta = _meta.duplicate(true) if _meta else {}
