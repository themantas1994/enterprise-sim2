class_name Sim
extends RefCounted
## Pure simulation facade (ADR 0001). No scene tree, no wall clock, no global random calls.
## Simulated time is the integer `tick` (10 Hz, DT = 0.1 s per tick); the same seed, ship data and
## command log always give the same snapshots (same platform; cross-platform float identity is not claimed).
##
## Ship data schema: see ship_loader.gd. Power solving: power_solver.gd. Heat and damage: thermal.gd.
## Reactor state machine: reactor_fsm.gd.
##
## Commands (Dictionary with `type`; numbers may be int or float). Invalid or unknown commands, bad
## targets, bad values and disallowed reactor transitions become events
## {type="rejected", cmd, reason, tick}; nothing is thrown.
##   set_alert {value: String}              set_mode {value: String}     stored fields, no other effect yet
##   set_allocation {target, value 0..1}    consumer allocation scale
##   set_demand {target, value >= 0}        consumer demand
##   set_priority {target, value: int}      consumer priority (lower number = more important)
##   set_output {target, value >= 0}        producer max_output (supply setting)
##   damage {target, amount > 0}            remove integrity from any component
##   repair {target}                        integrity back to 100; clears a conduit cut (rejected for a reactor
##                                          in breach or ejected)
##   cut_conduit {target} / restore_conduit {target}   manual cut flag (restore needs integrity > 0)
##   reactor_start / reactor_online / reactor_shutdown / reactor_eject {target}
## Per-tick order: queued commands (arrival order), random faults, power solve, heat and damage, reactor
## transitions, consumer service events, tick += 1.
## Events (this tick only): rejected, fault {id, amount}, reactor_state, breach, and consumer service changes
## shed / partial / unpowered / restored / destroyed {id, state, tick}, emitted once per change.
##
## Snapshot: {tick, alert, mode, valid, components: {id: {kind, state, power, temp, integrity, efficiency,
## load, plus charge (store), cut (conduit), demand/allocation/priority (consumer), countdown (reactor)}},
## events, rng_state}. A deep copy; panels never see live state.
##
## Save: save() returns a JSON-safe Dictionary. Seed and RNG state are strings (64-bit safe); the rest of
## the state travels in one base64 blob made with the engine's variant encoder, so floats and ints come back
## bit-exact after JSON.stringify and JSON.parse_string. Sim.from_save() returns null for a malformed save.

const DT := 0.1
const SAVE_VERSION := 1
const COMPONENT_FIELDS := ["kind", "state", "power", "temp", "integrity", "efficiency", "load"]
const EXTRA_FIELDS := {
	"store": ["charge"], "conduit": ["cut"],
	"consumer": ["demand", "allocation", "priority"],
}
const SERVICE_EVENT := {
	"ok": "restored", "partial": "partial", "shed": "shed", "unpowered": "unpowered", "destroyed": "destroyed",
}

var tick: int = 0
var alert: String = ShipLoader.DEFAULT_ALERT
var mode: String = ShipLoader.DEFAULT_MODE
var valid: bool = true
var errors: Array[String] = []

var _seed: int = 0
var _rng := RandomNumberGenerator.new()
var _queue: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _ship: Dictionary = {}
var _comps: Dictionary = {}
var _order: Array[String] = []
var _reported_errors: bool = false


func _init(ship_data: Dictionary = {}, seed_value: int = 0) -> void:
	_seed = seed_value
	_rng.seed = seed_value
	_ship = ship_data.duplicate(true)
	var built := ShipLoader.load_ship(_ship)
	errors.assign(built["errors"])
	valid = errors.is_empty()
	if valid:
		_comps = built["comps"]
		_order.assign(built["order"])
		alert = built["alert"]
		mode = built["mode"]


## Queue a command; it is applied by the next step() in arrival order.
func submit(cmd: Dictionary) -> void:
	_queue.append(cmd.duplicate(true))


## Apply the queued commands, then advance exactly one tick.
func step() -> void:
	_events = []
	if not valid and not _reported_errors:
		_reported_errors = true
		_events.append({"type": "rejected", "reason": "invalid_ship_data", "errors": errors.duplicate(), "tick": tick})
	var pending := _queue
	_queue = []
	for cmd in pending:
		var reason := _apply(cmd)
		if reason != "":
			_events.append({"type": "rejected", "cmd": cmd, "reason": reason, "tick": tick})
	_random_faults()
	PowerSolver.solve(_comps, _order, DT)
	for id in _order:
		Thermal.step(_comps[id])
	for id in _order:
		var c: Dictionary = _comps[id]
		if c["kind"] == "producer" and c["reactor"]:
			var before := _events.size()
			ReactorFsm.step(c, tick, _events)
			for i in range(before, _events.size()):
				if _events[i]["type"] == "breach":
					_breach_damage(id)
	_update_states()
	tick += 1


## Deep copy; callers never hold references to live sim state.
func snapshot() -> Dictionary:
	var comps := {}
	for id in _order:
		var c: Dictionary = _comps[id]
		var out := {}
		for f: String in COMPONENT_FIELDS:
			out[f] = c[f]
		for f: String in EXTRA_FIELDS.get(c["kind"], []):
			out[f] = c[f]
		if c["kind"] == "producer" and c["reactor"]:
			out["countdown"] = c["countdown"]
		comps[id] = out
	return {
		"tick": tick, "alert": alert, "mode": mode, "valid": valid,
		"components": comps, "events": _events.duplicate(true), "rng_state": _rng.state,
	}


## Complete state as a JSON-safe Dictionary (see the header for the encoding).
func save() -> Dictionary:
	var state := {
		"ship": _ship, "queue": _queue, "events": _events, "comps": _comps, "order": _order,
		"alert": alert, "mode": mode, "valid": valid, "errors": errors, "reported": _reported_errors,
	}
	return {
		"version": SAVE_VERSION, "tick": tick, "seed": str(_seed), "rng_state": str(_rng.state),
		"alert": alert, "mode": mode, "state": Marshalls.raw_to_base64(var_to_bytes(state)),
	}


## Rebuilds a Sim from save() output (also after a JSON round trip). Returns null if the save is malformed.
static func from_save(d: Dictionary) -> Sim:
	if typeof(d.get("version")) not in [TYPE_INT, TYPE_FLOAT] or int(d["version"]) != SAVE_VERSION:
		return null
	if typeof(d.get("seed")) != TYPE_STRING or typeof(d.get("rng_state")) != TYPE_STRING:
		return null
	if typeof(d.get("tick")) not in [TYPE_INT, TYPE_FLOAT] or typeof(d.get("state")) != TYPE_STRING:
		return null
	var decoded: Variant = bytes_to_var(Marshalls.base64_to_raw(d["state"]))
	if typeof(decoded) != TYPE_DICTIONARY:
		return null
	for key: String in ["ship", "queue", "events", "comps", "order", "alert", "mode", "valid", "errors", "reported"]:
		if not decoded.has(key):
			return null
	var s := Sim.new({}, String(d["seed"]).to_int())
	s._ship = decoded["ship"]
	s._queue.assign(decoded["queue"])
	s._events.assign(decoded["events"])
	s._comps = decoded["comps"]
	s._order.assign(decoded["order"])
	s.alert = decoded["alert"]
	s.mode = decoded["mode"]
	s.valid = decoded["valid"]
	s.errors.assign(decoded["errors"])
	s._reported_errors = decoded["reported"]
	s.tick = int(d["tick"])
	s._rng.state = String(d["rng_state"]).to_int()
	return s


# ---- commands ----------------------------------------------------------------------------------------------

func _apply(cmd: Dictionary) -> String:
	var type: Variant = cmd.get("type", null)
	if typeof(type) != TYPE_STRING:
		return "missing command type"
	match type:
		"set_alert", "set_mode":
			var v: Variant = cmd.get("value", null)
			if typeof(v) != TYPE_STRING or v == "":
				return "value must be a non-empty string"
			if type == "set_alert":
				alert = v
			else:
				mode = v
			return ""
		"set_allocation", "set_demand", "set_priority", "set_output":
			return _cmd_set(type, cmd)
		"damage", "repair", "cut_conduit", "restore_conduit":
			return _cmd_component(type, cmd)
		"reactor_start", "reactor_online", "reactor_shutdown", "reactor_eject":
			var c := _target(cmd, "producer")
			if c.is_empty():
				return "target must be an existing producer"
			if not c["reactor"]:
				return "target is not a reactor"
			return ReactorFsm.command(c, type, tick, _events)
	return "unknown command"


func _cmd_set(type: String, cmd: Dictionary) -> String:
	var kind := "producer" if type == "set_output" else "consumer"
	var c := _target(cmd, kind)
	if c.is_empty():
		return "target must be an existing " + kind
	var v: Variant = cmd.get("value", null)
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT or is_nan(float(v)) or is_inf(float(v)):
		return "value must be a finite number"
	var f := float(v)
	match type:
		"set_allocation":
			if f < 0.0 or f > 1.0:
				return "allocation must be within 0..1"
			c["allocation"] = f
		"set_demand":
			if f < 0.0:
				return "demand must be >= 0"
			c["demand"] = f
		"set_output":
			if f < 0.0:
				return "output must be >= 0"
			c["max_output"] = f
		"set_priority":
			if typeof(v) != TYPE_INT and f != floorf(f):
				return "priority must be an integer"
			c["priority"] = int(f)
	return ""


func _cmd_component(type: String, cmd: Dictionary) -> String:
	var c := _target(cmd, "")
	if c.is_empty():
		return "target must be an existing component"
	match type:
		"damage":
			var a: Variant = cmd.get("amount", null)
			if typeof(a) != TYPE_INT and typeof(a) != TYPE_FLOAT or is_nan(float(a)) or is_inf(float(a)) or float(a) <= 0.0:
				return "amount must be a finite number > 0"
			Thermal.damage(c, float(a))
		"repair":
			if c["kind"] == "producer" and c["reactor"] and not ReactorFsm.present(c):
				return "reactor is beyond repair in state " + c["state"]
			Thermal.repair(c)
		"cut_conduit", "restore_conduit":
			if c["kind"] != "conduit":
				return "target must be a conduit"
			if type == "cut_conduit":
				c["cut"] = true
			elif c["integrity"] <= 0.0:
				return "conduit is destroyed; repair it"
			else:
				c["cut"] = false
	return ""


## The live component for cmd.target, or {} when missing, not a String, or of the wrong kind ("" = any).
func _target(cmd: Dictionary, kind: String) -> Dictionary:
	var id: Variant = cmd.get("target", null)
	if typeof(id) != TYPE_STRING or not _comps.has(id):
		return {}
	var c: Dictionary = _comps[id]
	if kind != "" and c["kind"] != kind:
		return {}
	return c


# ---- per-tick stages ---------------------------------------------------------------------------------------

func _random_faults() -> void:
	for id in _order:
		var c: Dictionary = _comps[id]
		if c["fault_chance"] > 0.0 and c["integrity"] > 0.0 and _rng.randf() < c["fault_chance"]:
			Thermal.damage(c, c["fault_damage"])
			_events.append({"type": "fault", "id": id, "amount": c["fault_damage"], "tick": tick})


## Breach damage hits conduits touching the reactor and the components at their far ends.
func _breach_damage(reactor_id: String) -> void:
	var amount: float = _comps[reactor_id]["breach_damage"]
	var hit: Dictionary = {}
	for id in _order:
		var c: Dictionary = _comps[id]
		if c["kind"] == "conduit" and (c["from"] == reactor_id or c["to"] == reactor_id):
			hit[id] = true
			hit[c["to"] if c["from"] == reactor_id else c["from"]] = true
	for id in _order:
		if hit.has(id) and id != reactor_id:
			Thermal.damage(_comps[id], amount)


## Settles the state label of non-reactor components and emits one event per consumer service change.
func _update_states() -> void:
	for id in _order:
		var c: Dictionary = _comps[id]
		match c["kind"]:
			"producer":
				if not c["reactor"]:
					c["state"] = "online" if c["integrity"] > 0.0 else "destroyed"
			"store", "junction":
				c["state"] = "ok" if c["integrity"] > 0.0 else "destroyed"
			"conduit":
				c["state"] = "cut" if c["cut"] else ("ok" if c["integrity"] > 0.0 else "destroyed")
			"consumer":
				var st := _service_state(c)
				if st != c["state"]:
					c["state"] = st
					_events.append({"type": SERVICE_EVENT[st], "id": id, "state": st, "tick": tick})


static func _service_state(c: Dictionary) -> String:
	if c["integrity"] <= 0.0:
		return "destroyed"
	var want: float = c["demand"] * c["allocation"]
	if want <= PowerSolver.TOL or c["power"] >= want - 1e-6:
		return "ok"
	if not c["reachable"]:
		return "unpowered"
	if c["power"] <= 1e-6:
		return "shed"
	return "partial"
