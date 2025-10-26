class_name Graph
extends Node

# Lightweight graph with explicit node registry and adjacency map.
# Strict key policy: only accepts either ints (npc_id) or Objects that expose `npc_id`.

var nodes: Dictionary = {} # key -> meta (key is int or NPC-like Object)
var adjacency: Dictionary = {} # key -> { neighbor_key: weight }

func _is_valid_key(x) -> bool:
    if typeof(x) == TYPE_INT:
        return true
    if typeof(x) == TYPE_OBJECT and x != null and x.has_variable("npc_id"):
        return true
    return false

func _key_for(x):
    # Normalize or reject unsupported keys.
    if typeof(x) == TYPE_INT:
        return int(x)
    if typeof(x) == TYPE_OBJECT and x != null and x.has_variable("npc_id"):
        return x
    push_error("Graph: invalid key type. Only int npc_id or Object with npc_id are allowed.")
    return null

func _ready() -> void:
    pass

func add_node(key, meta: Dictionary = {}) -> void:
    var k = _key_for(key)
    if k == null:
        return
    if nodes.has(k):
        for mk in meta.keys():
            nodes[k][mk] = meta[mk]
    else:
        nodes[k] = meta.duplicate(true) if meta else {}
    if not adjacency.has(k):
        adjacency[k] = {}

func ensure_node(key, meta: Dictionary = {}) -> void:
    var k = _key_for(key)
    if k == null:
        return
    if not nodes.has(k):
        add_node(k, meta if meta else {})
    elif not adjacency.has(k):
        adjacency[k] = {}

func remove_node(key) -> void:
    var k = _key_for(key)
    if k == null or not nodes.has(k):
        return
    if adjacency.has(k):
        for neighbor in adjacency[k].keys():
            if adjacency.has(neighbor):
                adjacency[neighbor].erase(k)
        adjacency.erase(k)
    nodes.erase(k)

func has_vertex(key) -> bool:
    var k = _key_for(key)
    if k == null:
        return false
    return nodes.has(k)

func get_nodes() -> Dictionary:
    return nodes.duplicate()

func get_edge(a, b):
    var ka = _key_for(a)
    var kb = _key_for(b)
    if ka == null or kb == null:
        return null
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
func get_relationships_for(npc_or_id) -> Dictionary:
    var k = _key_for(npc_or_id)
    if k == null or not adjacency.has(k):
        return {}
    var raw: Dictionary = adjacency[k]
    var out: Dictionary = {}
    for neighbor in raw.keys():
        var out_key = neighbor
        if typeof(neighbor) == TYPE_OBJECT and neighbor != null and neighbor.has_variable("npc_id"):
            out_key = int(neighbor.npc_id)
        out[out_key] = raw[neighbor]
    return out

func add_connection(a, b, affinity: float) -> void:
    var ka = _key_for(a)
    var kb = _key_for(b)
    if ka == null or kb == null or ka == kb:
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
    if ka == null or kb == null:
        return
    if adjacency.has(ka):
        adjacency[ka].erase(kb)
    if adjacency.has(kb):
        adjacency[kb].erase(ka)

func clear() -> void:
    nodes.clear()
    adjacency.clear()
