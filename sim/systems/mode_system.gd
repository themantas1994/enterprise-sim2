class_name ModeSystem
extends ShipSystem
## Alert conditions and operating modes (D-MODE-001..013, plan section 3).
## Commands: set_alert {value green|yellow|red}, set_mode {value cruise|yellow_alert|red_alert|reduced_power}.
## A mode change reapplies the priority profile of the ship file, the phaser allocation and the power plan:
##   yellow: core held at least at 20% of its maximum (D-MODE-001), one backup impulse reactor at hot standby
##     (D-MODE-003); red: core at least 75% (D-MODE-005), all backup impulse reactors at hot standby (D-MODE-008);
##   reduced power: warp core shut down when not at warp (D-MODE-011), main impulse at the minimum that covers
##     onboard use (D-MODE-012), auxiliary fusion kept off-line (D-MODE-013).
## Reduced power keeps the core when it is the last power source (D-MODE-011 exception). Yellow and red only raise
## the core setpoint of a core that is already running; they never cold-start a core (start-up is the player's
## sequence, see WarpCoreSystem). Shield, SIF and IDF generator counts follow the mode in their own systems.
## Core ejection is manual only (a deliberate simplification of D-SAFE-003, D-SAFE-004 and D-SAFE-005; the
## automatic part of D-SAFE-005 applies to the pod assembly, see FuelSystem).

const ALERT_OF := {"cruise": "green", "yellow_alert": "yellow", "red_alert": "red", "reduced_power": "green"}
const MODE_OF := {"green": "cruise", "yellow": "yellow_alert", "red": "red_alert"}

var alert: String = "green"
var mode: String = "cruise"
var _applied: String = ""


func setup(runtime: Variant) -> void:
	super.setup(runtime)
	mode = str(rt.data.get("mode", "cruise"))
	alert = str(rt.data.get("alert", "green"))
	if not ShipRuntime.MODES.has(mode):
		mode = "cruise"
	_apply(true)
	_applied = mode


func rank(a: String) -> int:
	return ShipRuntime.ALERTS.find(a)


func handle(cmd: Dictionary, _snap: Dictionary) -> Variant:
	var type: Variant = cmd.get("type", null)
	if type != "set_alert" and type != "set_mode":
		return null
	var v: Variant = cmd.get("value", null)
	if type == "set_alert":
		if typeof(v) != TYPE_STRING or not ShipRuntime.ALERTS.has(v):
			return no("alert must be green, yellow or red")
		alert = v
		if not (v == "green" and mode == "reduced_power"):
			mode = MODE_OF[v]
	else:
		if typeof(v) != TYPE_STRING or not ShipRuntime.MODES.has(v):
			return no("mode must be cruise, yellow_alert, red_alert or reduced_power")
		mode = v
		alert = ALERT_OF[v]
	return ok()


## Raises the alert to at least `level` (used by the SIF failure ladder). Returns true when it changed.
func require_alert(level: String, why: String) -> bool:
	if rank(alert) >= rank(level):
		return false
	alert = level
	mode = MODE_OF[level]
	rt.event("alert_forced", {"value": level, "reason": why})
	return true


func update(_snap: Dictionary) -> void:
	if mode == _applied:
		return
	_apply(false)
	_applied = mode
	rt.cmd({"type": "set_alert", "value": alert})
	rt.cmd({"type": "set_mode", "value": mode})


func _apply(first: bool) -> void:
	var prof: Dictionary = rt.tune("modes", "priorities")
	var pr: Dictionary = prof.get(mode, {})
	for id: String in pr:
		rt.set_priority(id, int(pr[id]))
	var alloc: Dictionary = rt.tune("modes", "phaser_allocation")
	rt.cmd({"type": "set_allocation", "target": "phaser_array", "value": float(alloc.get(mode, 0.0))})
	if first:
		return
	var max_core := float(rt.def("warp_core")["max_output"])
	var sp: float = rt.setpoints["warp_core"]
	match mode:
		"cruise":
			rt.setpoints["warp_core"] = float(rt.tune("modes", "core_frac_cruise")) * max_core
			rt.setpoints["impulse_main"] = float(rt.tune("modes", "impulse_cruise_mw"))
		"yellow_alert":
			rt.setpoints["warp_core"] = maxf(sp, float(rt.tune("modes", "core_frac_yellow")) * max_core)
			_hot_standby(["impulse_saucer_1"])
		"red_alert":
			rt.setpoints["warp_core"] = maxf(sp, float(rt.tune("modes", "core_frac_red")) * max_core)
			_hot_standby(["impulse_saucer_1", "impulse_saucer_2"])
		"reduced_power":
			rt.setpoints["impulse_main"] = float(rt.tune("modes", "reduced_impulse_mw"))
			rt.setpoints["aux_fusion_1"] = 0.0
			rt.setpoints["aux_fusion_2"] = 0.0
			var st: String = rt.comp("warp_core").get("state", "")
			if rt.propulsion.warp > 0.0:
				pass  # at warp: D-MODE-011 exception, the core stays up
			elif _core_is_sole_source():
				rt.event("core_kept", {"reason": "warp core is the only power source (D-MODE-011 exception)"})
			elif ReactorFsm.SHUTDOWN_ALLOWED.has(st):
				rt.cmd({"type": "reactor_shutdown", "target": "warp_core"})
				rt.event("core_cold_shutdown", {"reason": "reduced power, not at warp (D-MODE-011)"})


## True when no other producer can carry ship power: the core is the last power source.
func _core_is_sole_source() -> bool:
	for id: String in ["impulse_main", "impulse_saucer_1", "impulse_saucer_2", "aux_fusion_1", "aux_fusion_2"]:
		var c: Dictionary = rt.comp(id)
		if c.get("integrity", 0.0) > 0.0 and c.get("state", "") == "online" and rt.setpoints[id] * rt.scale_of(id) > 0.0:
			return false
	return true


func _hot_standby(ids: Array) -> void:
	for id: String in ids:
		if rt.comp(id).get("state", "") == "cold":
			rt.cmd({"type": "reactor_start", "target": id})


func section() -> Dictionary:
	return {"alert": alert, "mode": mode}
