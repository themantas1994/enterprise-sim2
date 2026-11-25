class_name ShipLoader
extends RefCounted
## Validates a plain-Dictionary ship definition and builds the runtime component table.
##
## ship_data schema (JSON-compatible; every section optional, unknown keys ignored):
##   alert: String (default "green"), mode: String (default "normal"), ambient: number (default 20)
##   producers: [{id, max_output, rated?, reactor?, state?, ...}]
##       max_output  hard maximum output (power units)            required, >= 0
##       output      initial output setting, <= max_output        default max_output
##       rated       load reference; load = output / rated        default max_output
##       reactor     true makes it a state machine producer       default false
##       state       reactor start state (see ReactorFsm)         default "cold"
##       reactor tuning (all optional): startup_ticks 20, breach_ticks 30, overload_load 1.0,
##           overload_temp (= heat_threshold), recover_temp (= 0.9 * overload_temp), critical_temp 200,
##           critical_integrity 40, breach_damage 60
##   stores: [{id, capacity, charge?, max_charge?, max_discharge?, rated?}]   (energy units; defaults 0)
##   conduits: [{id, from, to, capacity, loss?, rated?}]   undirected link between two component ids;
##       capacity = hard limit on power entering the conduit, loss = fraction lost in transit [0,1)
##   consumers: [{id, demand, priority?, allocation?}]   priority is an integer, LOWER = MORE IMPORTANT
##       (default 100); allocation 0..1 scales the demand (default 1)
##   junctions: [{id}]   plain connection points (no rating, no heat model effect)
## Any component may also set the thermal and fault tuning keys below.
##   rated (kind specific, above), heat_threshold 100, overload_heat 10 (heat per tick per unit of load above 1),
##   cooling 0.05 (fraction of the gap to ambient lost per tick), heat_damage 0.02 (integrity per degree over
##   the threshold per tick), eff_span 400 (degrees over the threshold that remove all efficiency),
##   min_eff 0.1, fault_chance 0 (per-tick probability of a random fault, drawn from the seeded generator),
##   fault_damage 25 (integrity removed by a random fault).
## Ids are unique across all sections and are processed in section order (producers, stores, conduits,
## consumers, junctions), then array order.

const DEFAULT_ALERT := "green"
const DEFAULT_MODE := "normal"
const SECTIONS := ["producers", "stores", "conduits", "consumers", "junctions"]
const KINDS := {
	"producers": "producer", "stores": "store", "conduits": "conduit",
	"consumers": "consumer", "junctions": "junction",
}


## Returns {errors: Array[String], comps: {id: Dictionary}, order: Array[String], alert, mode}.
static func load_ship(data: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var comps: Dictionary = {}
	var order: Array[String] = []
	var ambient := _num(data, "ambient", 20.0, -1000.0, 100000.0, "ship", errors)
	var alert: Variant = data.get("alert", DEFAULT_ALERT)
	var mode: Variant = data.get("mode", DEFAULT_MODE)
	if typeof(alert) != TYPE_STRING or alert == "":
		errors.append("ship.alert must be a non-empty string")
		alert = DEFAULT_ALERT
	if typeof(mode) != TYPE_STRING or mode == "":
		errors.append("ship.mode must be a non-empty string")
		mode = DEFAULT_MODE
	for section: String in SECTIONS:
		if not data.has(section):
			continue
		var arr: Variant = data[section]
		if typeof(arr) != TYPE_ARRAY:
			errors.append("%s must be an array" % section)
			continue
		for i in arr.size():
			var def: Variant = arr[i]
			var ctx := "%s[%d]" % [section, i]
			if typeof(def) != TYPE_DICTIONARY:
				errors.append("%s must be an object" % ctx)
				continue
			var id: Variant = def.get("id", null)
			if typeof(id) != TYPE_STRING or id == "":
				errors.append("%s.id must be a non-empty string" % ctx)
				continue
			if comps.has(id):
				errors.append("%s duplicate id '%s'" % [ctx, id])
				continue
			ctx = "%s '%s'" % [section, id]
			var c := _build(KINDS[section], id, def, ambient, ctx, errors)
			comps[id] = c
			order.append(id)
	for id in order:
		var c: Dictionary = comps[id]
		if c["kind"] != "conduit":
			continue
		for end: String in ["from", "to"]:
			if not comps.has(c[end]) or comps[c[end]]["kind"] == "conduit":
				errors.append("conduits '%s'.%s refers to unknown node '%s'" % [id, end, c[end]])
		if c["from"] == c["to"]:
			errors.append("conduits '%s' connects a node to itself" % id)
	return {"errors": errors, "comps": comps, "order": order, "alert": alert, "mode": mode}


static func _build(kind: String, id: String, def: Dictionary, ambient: float, ctx: String, errors: Array[String]) -> Dictionary:
	var c := {
		"id": id, "kind": kind, "state": "ok", "power": 0.0, "load": 0.0,
		"temp": ambient, "ambient": ambient, "integrity": 100.0, "efficiency": 1.0,
		"heat_threshold": _num(def, "heat_threshold", 100.0, 0.0, 1.0e6, ctx, errors),
		"overload_heat": _num(def, "overload_heat", 10.0, 0.0, 1.0e6, ctx, errors),
		"cooling": _num(def, "cooling", 0.05, 0.0, 1.0, ctx, errors),
		"heat_damage": _num(def, "heat_damage", 0.02, 0.0, 1.0e6, ctx, errors),
		"eff_span": _num(def, "eff_span", 400.0, 0.001, 1.0e9, ctx, errors),
		"min_eff": _num(def, "min_eff", 0.1, 0.0, 1.0, ctx, errors),
		"fault_chance": _num(def, "fault_chance", 0.0, 0.0, 1.0, ctx, errors),
		"fault_damage": _num(def, "fault_damage", 25.0, 0.0, 1000.0, ctx, errors),
	}
	match kind:
		"producer":
			c["max_output"] = _num(def, "max_output", 0.0, 0.0, 1.0e9, ctx, errors, true)
			c["rated"] = _num(def, "rated", c["max_output"], 0.0, 1.0e9, ctx, errors)
			c["output_limit"] = _num(def, "output", c["max_output"], 0.0, c["max_output"], ctx, errors)
			var rv: Variant = def.get("reactor", false)
			if typeof(rv) != TYPE_BOOL:
				errors.append("%s.reactor must be a boolean" % ctx)
				rv = false
			c["reactor"] = rv
			c["state"] = "online"
			if c["reactor"]:
				var st: Variant = def.get("state", "cold")
				if typeof(st) != TYPE_STRING or not ReactorFsm.STATES.has(st):
					errors.append("%s.state must be one of the reactor states" % ctx)
					st = "cold"
				c["state"] = st
				c["startup_ticks"] = _int(def, "startup_ticks", 20, 0, 1000000, ctx, errors)
				c["breach_ticks"] = _int(def, "breach_ticks", 30, 1, 1000000, ctx, errors)
				c["overload_load"] = _num(def, "overload_load", 1.0, 0.0, 1.0e6, ctx, errors)
				c["overload_temp"] = _num(def, "overload_temp", c["heat_threshold"], 0.0, 1.0e6, ctx, errors)
				c["recover_temp"] = _num(def, "recover_temp", 0.9 * c["overload_temp"], 0.0, 1.0e6, ctx, errors)
				c["critical_temp"] = _num(def, "critical_temp", 200.0, 0.0, 1.0e6, ctx, errors)
				c["critical_integrity"] = _num(def, "critical_integrity", 40.0, 0.0, 100.0, ctx, errors)
				c["breach_damage"] = _num(def, "breach_damage", 60.0, 0.0, 1000.0, ctx, errors)
				c["startup_left"] = 0
				c["countdown"] = 0
				if c["state"] == "startup":
					c["startup_left"] = c["startup_ticks"]
				elif c["state"] == "containment_failing":
					c["countdown"] = c["breach_ticks"]
		"store":
			c["capacity"] = _num(def, "capacity", 0.0, 0.0, 1.0e12, ctx, errors, true)
			c["charge"] = _num(def, "charge", 0.0, 0.0, c["capacity"], ctx, errors)
			c["max_charge"] = _num(def, "max_charge", 0.0, 0.0, 1.0e9, ctx, errors)
			c["max_discharge"] = _num(def, "max_discharge", 0.0, 0.0, 1.0e9, ctx, errors)
			c["rated"] = _num(def, "rated", maxf(c["max_charge"], c["max_discharge"]), 0.0, 1.0e9, ctx, errors)
		"conduit":
			for end: String in ["from", "to"]:
				var ev: Variant = def.get(end, null)
				if typeof(ev) != TYPE_STRING:
					errors.append("%s.%s must be a string" % [ctx, end])
					ev = ""
				c[end] = ev
			c["capacity"] = _num(def, "capacity", 0.0, 0.0, 1.0e9, ctx, errors, true)
			c["loss"] = _num(def, "loss", 0.0, 0.0, 0.999, ctx, errors)
			c["rated"] = _num(def, "rated", c["capacity"], 0.0, 1.0e9, ctx, errors)
			c["cut"] = false
		"consumer":
			c["demand"] = _num(def, "demand", 0.0, 0.0, 1.0e9, ctx, errors, true)
			c["priority"] = _int(def, "priority", 100, -1000000000, 1000000000, ctx, errors)
			c["allocation"] = _num(def, "allocation", 1.0, 0.0, 1.0, ctx, errors)
			c["reachable"] = true
	return c


## Reads a number. Missing keys give `def` (an error if `required`); bad or out-of-range values give an error.
static func _num(d: Dictionary, key: String, def: float, lo: float, hi: float, ctx: String, errors: Array[String], required: bool = false) -> float:
	if not d.has(key):
		if required:
			errors.append("%s.%s is required" % [ctx, key])
		return def
	var v: Variant = d[key]
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		errors.append("%s.%s must be a number" % [ctx, key])
		return def
	var f := float(v)
	if is_nan(f) or is_inf(f) or f < lo or f > hi:
		errors.append("%s.%s out of range [%s, %s]" % [ctx, key, lo, hi])
		return def
	return f


## Reads an integer (JSON numbers with no fractional part are accepted); anything else is an error.
static func _int(d: Dictionary, key: String, def: int, lo: int, hi: int, ctx: String, errors: Array[String]) -> int:
	var f := _num(d, key, float(def), float(lo), float(hi), ctx, errors)
	if f != floorf(f):
		errors.append("%s.%s must be an integer" % [ctx, key])
		return def
	return int(f)
