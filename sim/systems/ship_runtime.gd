class_name ShipRuntime
extends RefCounted
## The only object the host talks to (ADR 0002). Owns the generic Sim, the NCC-1701-D ship systems and the
## active scenario. Deterministic: one seed, one command log, one run.
##
## API: create(ship_path, seed), create_from_data(raw_ship_dict, seed), step(), snapshot(), send(cmd),
## start_scenario(id), scenario_ids(), panel_components(panel_id).
##
## snapshot() = the core snapshot (Sim.snapshot) plus `ship`:
##   alert (green|yellow|red), mode (cruise|yellow_alert|red_alert|reduced_power), destroyed, events (this tick),
##   scenario {id, title, status, reason, tick, time_left} ({} when none),
##   warp, fuel, coolant, shields, sif_idf, propulsion, modes, damage_control (one section per system),
##   detail {id: extra fields} (levels of tanks and pods, generator availability, team tasks, ...).
## The generic sim stores of tanks, pods and coolant keep their ship-file values; the live levels are in
## `ship.detail[id].level` (junction-like components carry no charge).
##
## send(cmd) rejects raw repair, damage and add_heat ("not a player command"); send_debug(cmd) accepts them (tests,
## scenario set-up). start_scenario resets the ship in place. send(cmd) returns {accepted: bool, reason?: String, queued?: bool} at once. Commands the runtime cannot judge
## alone (value ranges the sim checks) are queued; a sim rejection arrives as a `rejected` event next tick.
## Generic sim commands (sim/core/sim.gd): set_allocation, set_priority, set_output (setpoint, see below),
##   cut_conduit, restore_conduit, reactor_start, reactor_online, reactor_shutdown,
##   reactor_eject. set_demand is rejected for demands the systems manage. set_alert {value green|yellow|red} and
##   set_mode {value cruise|yellow_alert|red_alert|reduced_power} go through the alert system.
## set_output sets the SETPOINT of a producer; the ship applies setpoint x system scale factors (injector
## redundancy, fuel, drain) to the sim.
## Ship commands, by system (details in each system file header):
##   warp core: core_inject, core_pressurize, core_set_ratio {value}, core_auto_ratio {value bool}, core_align,
##     core_set_mode {value power|warp}, injector_set {target, value bool}, containment_field {value bool};
##     reactor_start on warp_core starts the start-up sequence.
##   propulsion: set_warp {value 0..9.6}, set_impulse {value 0..1}
##   fuel: antimatter_generator_set {value bool}
##   coolant: coolant_isolate {target, value bool}, coolant_refill {target, value bool}
##   shields: shield_set {frequency, modulation}, shield_set_weights {fore, aft, port, stbd}, shield_set_level {value}
##   damage control: assign_team {team, target}, recall_team {team}

const DEFAULT_SHIP := "res://ships/1701d.json"
const ALERTS := ["green", "yellow", "red"]
const MODES := ["cruise", "yellow_alert", "red_alert", "reduced_power"]
const GENERIC := [
	"set_allocation", "set_demand", "set_priority", "set_output", "damage", "repair", "cut_conduit",
	"restore_conduit", "add_heat", "reactor_start", "reactor_online", "reactor_shutdown", "reactor_eject",
]

var sim: Sim
var raw: Dictionary = {}
var data: Dictionary = {}
var valid: bool = false
var errors: Array = []
var rng := RandomNumberGenerator.new()
var seed_value: int = 0
var tick: int = 0
var scenario: ScenarioBase = null
var destroyed: bool = false
var destroyed_reason: String = ""
var setpoints: Dictionary = {}  # producer id -> MW requested by the player or the alert profile
var ship_events: Array = []
var missing_tunes: Array = []

var modes: ModeSystem
var warp: WarpCoreSystem
var fuel: FuelSystem
var coolant: CoolantSystem
var sif_idf: SifIdfSystem
var shields: ShieldSystem
var propulsion: PropulsionSystem
var dc: DamageControlSystem
var systems: Array = []

var _snap: Dictionary = {}
var _defs: Dictionary = {}
var _scales: Dictionary = {}
var _sent_out: Dictionary = {}
var _sent_demand: Dictionary = {}
var _sent_priority: Dictionary = {}
var managed_demands: Dictionary = {}


static func create(ship_path: String, seed_value_in: int) -> ShipRuntime:
	return create_from_data(ShipData.read_file(ship_path), seed_value_in)


## Builds a runtime from a raw (wrapper) ship dictionary; tests use it to adjust the ship before a run.
static func create_from_data(raw_data: Dictionary, seed_value_in: int) -> ShipRuntime:
	var r := ShipRuntime.new()
	r.seed_value = seed_value_in
	r.raw = raw_data
	r.data = ShipData.flatten(raw_data)
	var probe := Sim.new(r.data, seed_value_in)
	r.valid = probe.valid and r.data.has("systems")
	r.errors = probe.errors.duplicate()
	r.sim = probe
	if r.valid:
		r._build_state()
	return r


## (Re)builds the whole ship state from the ship data: sim, systems, setpoints, rng. Same object, same seed.
func _build_state() -> void:
	dispose()
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x1701D
	sim = Sim.new(data, seed_value)
	tick = 0
	destroyed = false
	destroyed_reason = ""
	ship_events = []
	setpoints = {}
	_defs = {}
	_scales = {}
	_sent_out = {}
	_sent_demand = {}
	_sent_priority = {}
	managed_demands = {}
	scenario = null
	for section: String in ShipLoader.SECTIONS:
		for def: Dictionary in data.get(section, []):
			_defs[def["id"]] = def
			if section == "producers":
				setpoints[def["id"]] = float(def.get("output", def["max_output"]))
	_snap = sim.snapshot()
	modes = ModeSystem.new()
	warp = WarpCoreSystem.new()
	fuel = FuelSystem.new()
	coolant = CoolantSystem.new()
	sif_idf = SifIdfSystem.new()
	shields = ShieldSystem.new()
	propulsion = PropulsionSystem.new()
	dc = DamageControlSystem.new()
	systems = [modes, warp, fuel, coolant, sif_idf, shields, propulsion, dc]
	for s: ShipSystem in systems:
		s.setup(self)


## Breaks the reference cycles between the runtime and its systems; call when a run is finished.
func dispose() -> void:
	for s: ShipSystem in systems:
		if s != null:
			s.rt = null
	systems = []
	scenario = null


# ---- helpers for the systems --------------------------------------------------------------------------------

func tune(group: String, key: String) -> Variant:
	var g: Variant = data["systems"].get(group, {})
	if typeof(g) != TYPE_DICTIONARY or not g.has(key):
		missing_tunes.append("%s.%s" % [group, key])
		return 0.0
	return g[key]


func def(id: String) -> Dictionary:
	return _defs.get(id, {})


func comp(id: String) -> Dictionary:
	return _snap["components"].get(id, {})


## Delivered fraction of a consumer's wanted power (1 when it wants nothing).
func pf(id: String) -> float:
	var c := comp(id)
	if c.is_empty():
		return 0.0
	var want: float = c["demand"] * c["allocation"]
	if want <= 1e-9:
		return 1.0
	return clampf(c["power"] / want, 0.0, 1.0)


func components() -> Dictionary:
	return _snap["components"]


func alive(id: String) -> bool:
	return comp(id).get("integrity", 0.0) > 0.0


func panel_components(panel_id: String) -> Array:
	return data.get("panels", {}).get(panel_id, {}).get("components", [])


func cmd(c: Dictionary) -> void:
	sim.submit(c)


func event(kind: String, extra: Dictionary = {}) -> void:
	var e := {"type": kind, "tick": sim.tick}
	e.merge(extra, true)
	ship_events.append(e)


func set_demand(id: String, mw: float) -> void:
	managed_demands[id] = true
	var prev: float = _sent_demand.get(id, comp(id).get("demand", -1.0))
	if absf(prev - mw) > 1e-6:
		cmd({"type": "set_demand", "target": id, "value": mw})
		_sent_demand[id] = mw


func set_priority(id: String, p: int) -> void:
	if _sent_priority.get(id, comp(id).get("priority", -1)) != p:
		cmd({"type": "set_priority", "target": id, "value": p})
		_sent_priority[id] = p


func set_scale(id: String, source: String, value: float) -> void:
	if not _scales.has(id):
		_scales[id] = {}
	_scales[id][source] = value


func scale_of(id: String) -> float:
	var f := 1.0
	for v: float in _scales.get(id, {}).values():
		f *= v
	return f


func destroy_ship(reason: String) -> void:
	if not destroyed:
		destroyed = true
		destroyed_reason = reason
		event("ship_destroyed", {"reason": reason})


# ---- step, snapshot, commands -----------------------------------------------------------------------------

func step() -> void:
	ship_events = []
	for s: ShipSystem in systems:
		s.update(_snap)
	_flush_outputs()
	sim.step()
	tick = sim.tick
	_snap = sim.snapshot()
	for s: ShipSystem in systems:
		s.post(_snap)
	if scenario != null and scenario.status == ScenarioBase.RUNNING:
		scenario.tick += 1
		scenario.update(self)


func _flush_outputs() -> void:
	for id: String in setpoints:
		var eff := minf(setpoints[id] * scale_of(id), float(_defs[id]["max_output"]))
		if absf(eff - _sent_out.get(id, -1.0)) > 0.01:
			cmd({"type": "set_output", "target": id, "value": eff})
			_sent_out[id] = eff


func snapshot() -> Dictionary:
	if not valid:
		var bad := sim.snapshot()
		bad["ship"] = {"valid": false, "errors": errors.duplicate(), "scenario": {}}
		return bad
	var s := _snap.duplicate(true)
	var detail := {}
	var ship := {
		"alert": modes.alert if modes != null else "green",
		"mode": modes.mode if modes != null else "cruise",
		"destroyed": destroyed, "destroyed_reason": destroyed_reason,
		"events": ship_events.duplicate(true),
		"scenario": {},
	}
	for sys_name: String in ["warp", "fuel", "coolant", "sif_idf", "shields", "propulsion", "modes", "dc"]:
		var sys: ShipSystem = get(sys_name)
		var key := "damage_control" if sys_name == "dc" else sys_name
		ship[key] = sys.section()
		detail.merge(sys.id_detail(), true)
	ship["detail"] = detail
	if scenario != null:
		ship["scenario"] = {
			"id": scenario.id, "title": scenario.title, "status": scenario.status, "reason": scenario.reason,
			"tick": scenario.tick, "time_left": scenario.time_left(),
		}
	s["ship"] = ship
	return s


func scenario_ids() -> Array:
	return ScenarioRegistry.ids()


## Resets the ship in place (same object and seed, state rebuilt from the ship file) and starts the scenario.
## Returns false, touching nothing, for an unknown id or an invalid runtime.
func start_scenario(id: String) -> bool:
	if not valid:
		return false
	var sc := ScenarioRegistry.create(id)
	if sc == null:
		return false
	_build_state()
	scenario = sc
	sc.setup(self)
	return true


## Player command entry. Raw repair, damage and add_heat are not player commands (use assign_team etc.).
func send(c: Dictionary) -> Dictionary:
	if ["repair", "damage", "add_heat"].has(c.get("type", null)):
		return ShipSystem.no("%s is not a player command" % str(c["type"]))
	return send_debug(c)


## Same as send but also accepts raw repair, damage and add_heat. For tests and scenario setup only.
func send_debug(c: Dictionary) -> Dictionary:
	if not valid:
		return ShipSystem.no("ship data invalid")
	for s: ShipSystem in systems:
		var r: Variant = s.handle(c, _snap)
		if r != null:
			return r
	return _pass(c)


func _pass(c: Dictionary) -> Dictionary:
	var type: Variant = c.get("type", null)
	if typeof(type) != TYPE_STRING:
		return ShipSystem.no("missing command type")
	if not GENERIC.has(type):
		return ShipSystem.no("unknown command")
	var id: Variant = c.get("target", null)
	if typeof(id) != TYPE_STRING or not _snap["components"].has(id):
		return ShipSystem.no("target must be an existing component")
	var comp_kind: String = _snap["components"][id]["kind"]
	var want := ""
	match type:
		"set_allocation", "set_demand", "set_priority":
			want = "consumer"
		"set_output", "reactor_start", "reactor_online", "reactor_shutdown", "reactor_eject":
			want = "producer"
		"cut_conduit", "restore_conduit":
			want = "conduit"
	if want != "" and comp_kind != want:
		return ShipSystem.no("target must be a " + want)
	if ["set_allocation", "set_demand", "set_priority"].has(type) and not ShipSystem.finite(c.get("value", null)):
		return ShipSystem.no("value must be a finite number")
	if type == "set_demand" and managed_demands.has(id):
		return ShipSystem.no("demand of %s is managed by the ship systems" % id)
	if type == "set_output":
		var v: Variant = c.get("value", null)
		if not ShipSystem.finite(v):
			return ShipSystem.no("value must be a finite number")
		if float(v) < 0.0 or float(v) > float(_defs[id]["max_output"]):
			return ShipSystem.no("output must be within 0..max_output")
		setpoints[id] = float(v)
		if id == "warp_core":
			modes.core_follow = false  # the player's setting replaces the Cruise preset
		return ShipSystem.ok()
	if type.begins_with("reactor_"):
		var rc: Dictionary = _snap["components"][id]
		if not rc.has("countdown"):
			return ShipSystem.no("target is not a reactor")
		var why := reactor_check(type, rc["state"])
		if why != "":
			return ShipSystem.no(why)
	if type == "repair" and ["breach", "ejected"].has(_snap["components"][id]["state"]):
		return ShipSystem.no("beyond repair in state " + _snap["components"][id]["state"])
	cmd(c)
	return {"accepted": true, "queued": true}


## "" when the reactor transition is allowed from `state`, else the reason (mirrors ReactorFsm).
static func reactor_check(type: String, state: String) -> String:
	match type:
		"reactor_start":
			return "" if state == "cold" else "start requires cold, state is " + state
		"reactor_online":
			return "" if state == "standby" else "bring online requires standby, state is " + state
		"reactor_shutdown":
			return "" if ReactorFsm.SHUTDOWN_ALLOWED.has(state) else "shutdown not allowed in " + state
		"reactor_eject":
			return "" if ReactorFsm.EJECT_ALLOWED.has(state) else "eject not allowed in " + state
	return "unknown reactor command"
