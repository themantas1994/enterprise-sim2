class_name WarpCoreSystem
extends ShipSystem
## Warp core (M/ARA, plan section 3): start-up sequence, matter/antimatter ratio, injector redundancy,
## constrictors, dilithium frame alignment, containment fault, ejection and the annular forcefield.
##
## Start-up (D-WARP-011, D-WARP-012, D-WARP-013), run by the player while the reactor state is cold:
##   reactor_start      -> stage heating (needs EPS power on warp_core_aux and one matter injector) until the
##                         chamber reaches 2.5 million K, stage heated (a still-warm chamber skips this)
##   core_inject        -> stage injecting (needs an antimatter injector, pod containment and antimatter), then idle
##                         at 25:1
##   core_pressurize    -> stage pressurizing to 72,000 kPa, then stage ready; the generic reactor start-up
##                         (cold, startup, standby) follows by itself and reactor_online brings the core online.
## reactor_shutdown aborts a running start-up. After a shutdown the chamber cools in about 10 minutes (D-SAFE-001).
## Other commands: core_set_ratio {value}, core_auto_ratio {value bool}, core_align, core_set_mode {value
## power|warp}, injector_set {target, value bool}, containment_field {value bool}; set_output sets the setpoint.
## Applied output = setpoint x injectors x constrictors x ratio x alignment x fuel (cap_frac); a lost matter injector is
## covered by dilating the rest (D-WARP-003).
## Containment (D-CORE-002): field strength 40% at the critical integrity falling to 15% at breach. A fault
## (start_containment_fault) drains core integrity each tick until the core is shut down, ejected or breached.
## Core ejection is manual only (a deliberate simplification of D-SAFE-003, D-SAFE-004 and D-SAFE-005; the automatic
## part applies to the pod assembly in practice, see FuelSystem). reactor_eject needs the ejection system powered (D-CORE-003). The forcefield (D-ENG-007) contains a breach when
## at strength >= ff_hold at the moment of breach (breach_state contained), else the ship is destroyed.

const CORE := "warp_core"
const AUX := "warp_core_aux"
const MATTER := [
	"warp_injector_matter_1", "warp_injector_matter_2", "warp_injector_matter_3",
	"warp_injector_matter_4", "warp_injector_matter_5", "warp_injector_matter_6",
]
const ANTI := ["warp_injector_antimatter_1", "warp_injector_antimatter_2", "warp_injector_antimatter_3"]
const ONLINE_STATES := ["online", "overload", "containment_failing"]

var stage: String = "cold"
var chamber_k: float = 300.0
var pressure_kpa: float = 0.0
var ratio: float = 0.0
var ratio_auto: bool = true
var alignment: float = 1.0
var aligning: bool = false
var core_mode: String = "power"
var cap_frac: float = 1.0
var injector_on: Dictionary = {}
var fault_rate: float = 0.0
var forcefield_on: bool = false
var forcefield: float = 0.0
var breach_state: String = ""
var field_pct: float = 100.0
var stalled: String = ""
var _stage_left: int = 0
var _prev_fsm: String = ""
var _start_sent: bool = false


func setup(runtime: Variant) -> void:
	super.setup(runtime)
	for id: String in MATTER + ANTI:
		injector_on[id] = true
	var st: String = rt.comp(CORE)["state"]
	_prev_fsm = st
	if ONLINE_STATES.has(st) or st == "standby":
		chamber_k = float(rt.tune("warp", "online_k")) if st != "standby" else float(rt.tune("warp", "heat_k"))
		pressure_kpa = float(rt.tune("warp", "pressure_kpa"))
		ratio = float(rt.tune("warp", "idle_ratio"))
	else:
		chamber_k = float(rt.tune("warp", "ambient_k"))


func fsm_state() -> String:
	return rt.comp(CORE).get("state", "")


func is_online() -> bool:
	return ONLINE_STATES.has(fsm_state()) and fsm_state() != "containment_failing"


func can_warp() -> bool:
	return is_online() and core_mode == "warp"


func stage_name() -> String:
	var st := fsm_state()
	return stage if st == "cold" else st


func usable(ids: Array) -> int:
	var n := 0
	for id: String in ids:
		if injector_on.get(id, false) and rt.alive(id):
			n += 1
	return n


func ratio_target(w: float) -> float:
	var hi := float(rt.tune("warp", "high_warp_factor"))
	var idle := float(rt.tune("warp", "idle_ratio"))
	var full := float(rt.tune("warp", "full_ratio"))
	return idle + (full - idle) * clampf(w / hi, 0.0, 1.0)


func eject_ready() -> bool:
	return rt.alive(AUX) and rt.pf(AUX) >= float(rt.tune("warp", "eject_aux_min"))


func start_containment_fault(rate_per_tick: float) -> void:
	fault_rate = rate_per_tick
	rt.event("containment_fault", {"rate": rate_per_tick})


# ---- commands ---------------------------------------------------------------------------------------------

func handle(cmd: Dictionary, _snap: Dictionary) -> Variant:
	var type: Variant = cmd.get("type", null)
	var st := fsm_state()
	match type:
		"reactor_start":
			if cmd.get("target") != CORE:
				return null
			if st != "cold":
				return no("start requires cold, state is " + st)
			if stage != "cold":
				return no("start-up already running (stage %s)" % stage)
			if usable(MATTER) < 1:
				return no("no usable matter injector")
			stalled = ""
			stage = "heated" if chamber_k >= float(rt.tune("warp", "heat_k")) else "heating"
			return ok()
		"core_inject":
			if st != "cold" or stage != "heated":
				return no("injection needs stage heated (stage is %s)" % stage_name())
			if usable(ANTI) < 1:
				return no("no usable antimatter injector")
			if rt.fuel.containment < 0.5 or rt.fuel.antimatter_total() <= 0.0:
				return no("antimatter supply or pod containment not available")
			stage = "injecting"
			_stage_left = int(rt.tune("warp", "inject_ticks"))
			return ok()
		"core_pressurize":
			if st != "cold" or stage != "idle":
				return no("pressurizing needs stage idle (stage is %s)" % stage_name())
			stage = "pressurizing"
			return ok()
		"reactor_shutdown":
			if cmd.get("target") != CORE:
				return null
			if st == "cold" and stage != "cold":
				stage = "cold"
				stalled = ""
				return ok()
			var why := ShipRuntime.reactor_check("reactor_shutdown", st)
			if why != "":
				return no(why)
			rt.cmd(cmd)
			return {"accepted": true, "queued": true}
		"reactor_eject":
			if cmd.get("target") != CORE:
				return null
			var why2 := ShipRuntime.reactor_check("reactor_eject", st)
			if why2 != "":
				return no(why2)
			if not eject_ready():
				return no("ejection system offline (D-CORE-003)")
			rt.cmd(cmd)
			return {"accepted": true, "queued": true}
		"core_set_ratio":
			var v: Variant = cmd.get("value", null)
			if not finite(v) or float(v) < 1.0 or float(v) > 100.0:
				return no("ratio must be a number within 1..100")
			ratio_auto = false
			ratio = float(v)
			return ok()
		"core_auto_ratio":
			ratio_auto = bool(cmd.get("value", true))
			return ok()
		"core_align":
			aligning = true
			return ok()
		"core_set_mode":
			var m: Variant = cmd.get("value", null)
			if m != "power" and m != "warp":
				return no("mode must be power or warp")
			if m == "power" and rt.propulsion.warp > 0.0:
				return no("cannot leave warp mode while at warp")
			core_mode = m
			return ok()
		"injector_set":
			var t: Variant = cmd.get("target", null)
			if typeof(t) != TYPE_STRING or not injector_on.has(t):
				return no("target must be an injector")
			injector_on[t] = bool(cmd.get("value", true))
			return ok()
		"containment_field":
			forcefield_on = bool(cmd.get("value", true))
			return ok()
	return null


# ---- per-tick ---------------------------------------------------------------------------------------------

func update(snap: Dictionary) -> void:
	var c: Dictionary = snap["components"][CORE]
	var fsm: String = c["state"]
	_overlay(fsm)
	_prev_fsm = fsm
	_ratio_and_alignment(fsm)
	_forcefield()
	_fault(fsm, c)
	_field(fsm, c)
	_aux_demand(fsm)
	var mf := clampf(float(usable(MATTER)) / float(rt.tune("warp", "matter_min")), 0.0, 1.0)
	var af := clampf(float(usable(ANTI)) / float(rt.tune("warp", "anti_min")), 0.0, 1.0)
	var floor_c := float(rt.tune("warp", "constrictor_floor"))
	var worst := minf(rt.comp("warp_constrictor_upper").get("integrity", 0.0), rt.comp("warp_constrictor_lower").get("integrity", 0.0))
	var cf := floor_c + (1.0 - floor_c) * worst / 100.0
	var rf := 1.0
	if ONLINE_STATES.has(fsm):
		var target := ratio_target(rt.propulsion.warp)
		var dev := clampf(absf(ratio - target) / target, 0.0, 1.0)
		rf = maxf(float(rt.tune("warp", "ratio_floor")), 1.0 - float(rt.tune("warp", "ratio_penalty")) * dev)
	var alf := 1.0
	if core_mode == "warp":
		var fl := float(rt.tune("warp", "align_floor"))
		alf = fl + (1.0 - fl) * alignment
	cap_frac = mf * af * cf * rf * alf * rt.fuel.warp_fuel_factor()
	rt.set_scale(CORE, "warp", cap_frac)


func _overlay(fsm: String) -> void:
	var ambient := float(rt.tune("warp", "ambient_k"))
	var heat_k := float(rt.tune("warp", "heat_k"))
	var online_k := float(rt.tune("warp", "online_k"))
	var p_full := float(rt.tune("warp", "pressure_kpa"))
	if fsm != "cold":
		stage = "cold"
		_start_sent = false
		stalled = ""
		if ONLINE_STATES.has(fsm):
			chamber_k = online_k
			pressure_kpa = p_full
		elif fsm == "startup" or fsm == "standby":
			chamber_k = maxf(chamber_k, heat_k)
			pressure_kpa = p_full
		return
	match stage:
		"cold":
			var decay := log(online_k / ambient) / float(rt.tune("warp", "cold_ticks"))
			chamber_k = maxf(ambient, chamber_k * exp(-decay))
			pressure_kpa = maxf(0.0, pressure_kpa - p_full / float(rt.tune("warp", "depressurize_ticks")))
			ratio = 0.0
		"heating":
			if rt.pf(AUX) < float(rt.tune("warp", "aux_power_min")):
				stalled = "EPS power on warp_core_aux below %d%%" % int(100.0 * float(rt.tune("warp", "aux_power_min")))
			elif usable(MATTER) < 1:
				stalled = "no usable matter injector"
			else:
				stalled = ""
				chamber_k += (heat_k - ambient) / float(rt.tune("warp", "heat_ticks"))
				if chamber_k >= heat_k:
					chamber_k = heat_k
					stage = "heated"
		"injecting":
			_stage_left -= 1
			if _stage_left <= 0:
				stage = "idle"
				ratio = float(rt.tune("warp", "idle_ratio"))
				ratio_auto = true
		"pressurizing":
			pressure_kpa += p_full / float(rt.tune("warp", "pressurize_ticks"))
			if pressure_kpa >= p_full:
				pressure_kpa = p_full
				stage = "ready"
		"ready":
			if not _start_sent:
				_start_sent = true
				rt.cmd({"type": "reactor_start", "target": CORE})


func _ratio_and_alignment(fsm: String) -> void:
	if ONLINE_STATES.has(fsm) and ratio_auto:
		ratio = move_toward(ratio, ratio_target(rt.propulsion.warp), float(rt.tune("warp", "ratio_slew")))
	var frame_max: float = rt.comp("warp_dilithium_frame").get("integrity", 0.0) / 100.0
	if aligning:
		alignment = minf(frame_max, alignment + float(rt.tune("warp", "align_rate")))
		if alignment >= frame_max:
			aligning = false
	alignment = minf(alignment, frame_max)


func _forcefield() -> void:
	var powered: bool = rt.pf(AUX) >= float(rt.tune("warp", "aux_power_min"))
	if forcefield_on and powered:
		forcefield = minf(1.0, forcefield + 1.0 / float(rt.tune("warp", "ff_ramp_ticks")))
	else:
		forcefield = maxf(0.0, forcefield - 1.0 / float(rt.tune("warp", "ff_decay_ticks")))


func _fault(fsm: String, _c: Dictionary) -> void:
	if fault_rate <= 0.0:
		return
	if fsm == "cold" or fsm == "ejected" or fsm == "breach":
		fault_rate = 0.0
		rt.event("containment_fault_ended", {"state": fsm})
		return
	rt.cmd({"type": "damage", "target": CORE, "amount": fault_rate})


func _field(fsm: String, c: Dictionary) -> void:
	var crit := float(rt.tune("warp", "field_critical_pct"))
	var collapse := float(rt.tune("warp", "field_collapse_pct"))
	if fsm == "containment_failing":
		var total: float = maxf(1.0, float(rt.def(CORE).get("breach_ticks", 30)))
		field_pct = collapse + (crit - collapse) * clampf(c["countdown"] / total, 0.0, 1.0)
	elif fsm == "breach" or fsm == "ejected":
		field_pct = 0.0
	else:
		var ci: float = float(rt.def(CORE).get("critical_integrity", 40.0))
		field_pct = crit + (100.0 - crit) * clampf((c["integrity"] - ci) / (100.0 - ci), 0.0, 1.0)


func _aux_demand(fsm: String) -> void:
	var mw := float(rt.tune("warp", "aux_base_mw"))
	if ["heating", "injecting", "pressurizing"].has(stage) and fsm == "cold":
		mw += float(rt.tune("warp", "aux_startup_mw"))
	if forcefield_on:
		mw += float(rt.tune("warp", "aux_forcefield_mw"))
	rt.set_demand(AUX, mw)


func post(snap: Dictionary) -> void:
	for e: Dictionary in snap["events"]:
		if e["type"] == "breach" and e["id"] == CORE:
			if forcefield >= float(rt.tune("warp", "ff_hold")):
				breach_state = "contained"
				rt.event("breach_contained", {})
				for id: String in ["eps_trunk_a", "eps_trunk_b", "eps_hub_a", "eps_hub_b"]:
					rt.cmd({"type": "repair", "target": id})
			else:
				breach_state = "uncontained"
				rt.destroy_ship("warp core breach, forcefield not holding")


func section() -> Dictionary:
	return {
		"stage": stage_name(), "stalled": stalled, "chamber_k": chamber_k, "pressure_kpa": pressure_kpa,
		"ratio": ratio, "ratio_target": ratio_target(rt.propulsion.warp), "ratio_auto": ratio_auto,
		"alignment": alignment, "mode": core_mode, "setpoint": rt.setpoints[CORE], "cap": cap_frac,
		"matter_usable": usable(MATTER), "antimatter_usable": usable(ANTI),
		"field_pct": field_pct, "fault_active": fault_rate > 0.0, "forcefield_on": forcefield_on,
		"forcefield": forcefield, "eject_ready": eject_ready(), "breach": breach_state,
	}


func id_detail() -> Dictionary:
	var out := {}
	for id: String in injector_on:
		out[id] = {"enabled": injector_on[id]}
	return out
