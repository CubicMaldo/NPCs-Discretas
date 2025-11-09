extends Node

# Minimal demonstration runner that emulates a BT runner API used by ActionBT

var _running: bool = false
var _start_time: float = 0.0
var duration: float = 3.0

func _ready():
    pass

func start():
    _running = true
    _start_time = Time.get_ticks_msec() / 1000.0

func is_running() -> bool:
    if not _running:
        return false
    var now = Time.get_ticks_msec() / 1000.0
    if now - _start_time >= duration:
        _running = false
    return _running

func stop():
    _running = false
