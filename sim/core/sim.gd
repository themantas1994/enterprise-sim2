class_name Sim
extends RefCounted
## Pure simulation stub (ADR 0001 sketch). No scene tree, no wall clock, no global random calls.
## Simulated time is the integer `tick`; the same seed and the same command log give the same snapshots.

var tick: int = 0
var _rng := RandomNumberGenerator.new()
var _queue: Array[Dictionary] = []
var _events: Array[Dictionary] = []


func _init(_ship_data: Dictionary = {}, seed_value: int = 0) -> void:
	_rng.seed = seed_value


## Queue a command; it is applied by the next step() in arrival order.
func submit(cmd: Dictionary) -> void:
	_queue.append(cmd.duplicate(true))


## Apply the queued commands, then advance one tick. Stub: every command is rejected as an event.
func step() -> void:
	_events = []
	for cmd in _queue:
		_events.append({"type": "rejected", "cmd": cmd, "tick": tick})
	_queue.clear()
	tick += 1


## Deep copy; callers never hold references to live sim state.
func snapshot() -> Dictionary:
	return {"tick": tick, "rng_state": _rng.state, "events": _events.duplicate(true)}
