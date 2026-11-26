extends RefCounted
## Stand-in for the ship runtime: the same call surface (step, snapshot, send, scenario_ids, start_scenario),
## with a fixed fixture grid. Records every command it receives.

var commands: Array = []
var tick := 0
var comps: Dictionary = {}
var alert := "green"
var scenario: Dictionary = {}
var started: Array = []
var events: Array = []
var valid := true
var disposed := false
var ship_extra: Dictionary = {}     # merged into the snapshot's `ship` entry
var reject_types: Dictionary = {}   # command type -> reason, rejected at once
var queue_reject: Dictionary = {}   # command type -> reason, rejected by an event on the next tick
var _next_events: Array = []


func _init(components: Dictionary = {}) -> void:
	comps = components.duplicate(true)


func step() -> void:
	tick += 1
	events = _next_events
	_next_events = []


func snapshot() -> Dictionary:
	var ship := {"alert": alert, "mode": "cruise", "scenario": scenario.duplicate(true)}
	ship.merge(ship_extra.duplicate(true), true)
	return {
		"tick": tick, "alert": alert, "mode": "normal", "valid": true,
		"components": comps.duplicate(true), "events": events.duplicate(true), "rng_state": 0,
		"ship": ship,
	}


func send(cmd: Dictionary) -> Dictionary:
	commands.append(cmd.duplicate(true))
	if reject_types.has(str(cmd.get("type", ""))):
		return {"accepted": false, "reason": reject_types[str(cmd.get("type", ""))]}
	if queue_reject.has(str(cmd.get("type", ""))):
		_next_events.append({"type": "rejected", "cmd": cmd.duplicate(true), "reason": queue_reject[str(cmd.get("type", ""))], "tick": tick})
		return {"accepted": true, "queued": true}
	if str(cmd.get("target", "")) == "reject_me":
		return {"accepted": false, "reason": "no such target"}
	return {"accepted": true}


func scenario_ids() -> Array:
	return ["core_breach", "borg_drain", "coolant_leak"]


func start_scenario(id: String) -> void:
	started.append(id)
	scenario = {"id": id, "title": id.replace("_", " "), "status": "running", "reason": "", "tick": 0, "time_left": 600}


func dispose() -> void:
	disposed = true
