class_name Graph
extends Node

# Lightweight graph implementation keeping explicit node registry and adjacency map.
# Maintains compatibility methods (`add_connection`, `remove_connection`,
# `get_relationships_for`) used elsewhere in the project.

var nodes: Dictionary = {} # key -> meta dictionary (key can be int or Object)
var adjacency: Dictionary = {} # key -> { neighbor_key: weight }
var id_to_ref: Dictionary = {} # npc_id (int) -> object reference (key)

func _key_for(x):
    # Normalize input to the internal key used in nodes/adjacency.
    if typeof(x) == TYPE_OBJECT and x != null:
        return x
    if typeof(x) == TYPE_INT:
        var nid = int(x)
        if id_to_ref.has(nid):
            return id_to_ref[nid]
        return nid
    return x

func _ready() -> void:
    # placeholder for Node lifecycle if needed
    pass

func add_node(key, meta: Dictionary = {}) -> void:
    if key == null:
        return
    # if key is an object and has an npc_id, register mapping
    if typeof(key) == TYPE_OBJECT and key != null and key.has_variable("npc_id"):
        var nid = int(key.npc_id)
        id_to_ref[nid] = key
    if nodes.has(key):
        for k in meta.keys():
            nodes[key][k] = meta[k]
    else:
        nodes[key] = meta.duplicate(true) if meta else {}
    if not adjacency.has(key):
        adjacency[key] = {}

func ensure_node(key, meta: Dictionary = {}) -> void:
    if typeof(key) == TYPE_OBJECT and key != null:
        add_node(key, meta)
    else:
        # try map numeric id to existing ref
        var k = _key_for(key)
        if not nodes.has(k):
            add_node(k, meta if meta else {})
        elif not adjacency.has(k):
            adjacency[k] = {}

func remove_node(key) -> void:
    var k = _key_for(key)
    if not nodes.has(k):
        return
    # remove incident edges
    if adjacency.has(k):
        for neighbor in adjacency[k].keys():
            if adjacency.has(neighbor):
                adjacency[neighbor].erase(k)
        adjacency.erase(k)
    nodes.erase(k)

func has_vertex(id) -> bool:
    return nodes.has(_key_for(id))

func get_nodes() -> Dictionary:
    return nodes.duplicate()

func get_edge(a, b):
    var ka = _key_for(a)
    var kb = _key_for(b)
    if not adjacency.has(ka):
        return null
    return adjacency[ka].get(kb, null)

func get_edges() -> Array:
    var out: Array = []
    for a in adjacency.keys():
        for b in adjacency[a].keys():
            out.append({"source": a, "target": b, "weight": adjacency[a][b]})
    return out

### Compatibility methods (used by RelationshipComponent and NPC)
func get_relationships_for(npc) -> Dictionary:
    var k = _key_for(npc)
    if not adjacency.has(k):
        return {}
    var raw: Dictionary = adjacency[k]
    var out: Dictionary = {}
    for neighbor in raw.keys():
        var out_key = neighbor
        if typeof(neighbor) == TYPE_OBJECT and neighbor != null:
            if neighbor.has_variable("npc_id"):
                out_key = int(neighbor.npc_id)
            elif neighbor.has_method("get_instance_id"):
                out_key = int(neighbor.get_instance_id())
        out[out_key] = raw[neighbor]
    return out

func add_connection(a, b, affinity: float) -> void:
    var ka = _key_for(a)
    var kb = _key_for(b)
    if ka == kb:
        return
    ensure_node(ka)
    ensure_node(kb)
    if affinity < 0.0:
        remove_connection(ka, kb)
        return
    adjacency[ka][kb] = affinity
    adjacency[kb][ka] = affinity

func remove_connection(a, b) -> void:
    var ka = _key_for(a)
    var kb = _key_for(b)
    if adjacency.has(ka):
        adjacency[ka].erase(kb)
    if adjacency.has(kb):
        adjacency[kb].erase(ka)

func clear() -> void:
    nodes.clear()
    adjacency.clear()
