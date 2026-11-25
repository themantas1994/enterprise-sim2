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


func _init(components: Dictionary = {}) -> void:
	comps = components.duplicate(true)


func step() -> void:
	tick += 1


func snapshot() -> Dictionary:
	return {
		"tick": tick, "alert": alert, "mode": "normal", "valid": true,
		"components": comps.duplicate(true), "events": events.duplicate(true), "rng_state": 0,
		"ship": {"alert": alert, "mode": "cruise", "scenario": scenario.duplicate(true)},
	}


func send(cmd: Dictionary) -> Dictionary:
	commands.append(cmd.duplicate(true))
	if str(cmd.get("target", "")) == "reject_me":
		return {"accepted": false, "reason": "no such target"}
	return {"accepted": true}


func scenario_ids() -> Array:
	return ["core_breach", "borg_drain", "coolant_leak"]


func start_scenario(id: String) -> void:
	started.append(id)
	scenario = {"id": id, "title": id.replace("_", " "), "status": "running", "reason": "", "tick": 0, "time_left": 600}
