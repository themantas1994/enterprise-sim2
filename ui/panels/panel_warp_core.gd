extends PanelBase
## Warp core panel: reactor controls, forcefield, mode, coolant loop, start-up steps and warp factor.
## Reads only the ids of its map entry (layout hints below match parts of id names) and the `ship` sections.

const WARP_MAX := 9.6   # D-DESIGN-003 maximum warp factor; the runtime validates every request
const EJECT_ARM_TICKS := 30

var _core: Readout


func _group_defs() -> Array:
	return [
		["CORE", ["warp_core"]],
		["MATTER INJECTORS", ["injector_matter"]],
		["ANTIMATTER INJECTORS", ["injector_antimatter"]],
		["CONSTRICTORS", ["constrictor"]],
		["DILITHIUM FRAME", ["dilithium"]],
		["NACELLES", ["nacelle"]],
		["COOLANT", ["coolant"]],
	]


func _inspector_reactor() -> bool:
	return false


func _core_cmd(key: String, type: String) -> void:
	var id := reactor_id()
	if id == "":
		_ctl_error(key, "no reactor in this panel")
		return
	send_ctl(key, {"type": type, "target": id})


func _on_eject() -> void:
	if tick_now() - _arm_tick <= EJECT_ARM_TICKS:
		_arm_tick = -1000
		_core_cmd("eject", "reactor_eject")
	else:
		_arm_tick = tick_now()
	_update_controls(_snap())


func _build_controls() -> void:
	add_button("shutdown", "SHUTDOWN", func() -> void: _core_cmd("shutdown", "reactor_shutdown"))
	add_button("eject", "EJECT", _on_eject, UiStatus.CAUTION)
	add_button("field", "FIELD", func() -> void: send_ctl("field", {"type": "containment_field", "value": not ship("warp").get("forcefield_on", false)}))
	var loop := id_with("coolant")
	if loop != "":
		add_button("isolate", "ISOLATE LOOP", func() -> void: send_ctl("isolate", {"type": "coolant_isolate", "target": loop, "value": not ship("coolant").get(loop, {}).get("isolated", false)}))
		add_button("refill", "REFILL LOOP", func() -> void: send_ctl("refill", {"type": "coolant_refill", "target": loop, "value": not ship("coolant").get(loop, {}).get("refilling", false)}))
	add_button("start", "START", func() -> void: _core_cmd("start", "reactor_start"))
	add_button("online", "ONLINE", func() -> void: _core_cmd("online", "reactor_online"))
	add_button("mode", "MODE", func() -> void: send_ctl("mode", {"type": "core_set_mode", "value": "power" if ship("warp").get("mode", "power") == "warp" else "warp"}))
	add_cmd_button("inject", "INJECT", {"type": "core_inject"})
	add_cmd_button("pressurize", "PRESSURIZE", {"type": "core_pressurize"})
	add_cmd_button("align", "ALIGN", {"type": "core_align"})
	add_slider("warp", "Warp factor", 0.0, WARP_MAX, 0.1, func(v: float) -> Dictionary: return {"type": "set_warp", "value": snappedf(v, 0.1)}, 1.0, 1, "", _controls)


func _build_extra(c: VBoxContainer) -> void:
	_core = kit.readout("Core")
	c.add_child(_core)


func _update_controls(_snap_data: Dictionary) -> void:
	var w := ship("warp")
	var on := UiStatus.OK
	set_button("field", "FIELD", "ON" if w.get("forcefield_on", false) else "OFF", on if w.get("forcefield_on", false) else UiStatus.OFF)
	set_button("mode", "MODE", str(w.get("mode", "")), UiStatus.INFO)
	var armed := tick_now() - _arm_tick <= EJECT_ARM_TICKS
	set_button("eject", "CONFIRM EJECT" if armed else "EJECT", "", UiStatus.ALARM if armed else UiStatus.CAUTION)
	var loop := id_with("coolant")
	if loop != "":
		var cl: Dictionary = ship("coolant").get(loop, {})
		set_button("isolate", "ISOLATE LOOP", "ON" if cl.get("isolated", false) else "OFF", UiStatus.CAUTION if cl.get("isolated", false) else UiStatus.OK)
		set_button("refill", "REFILL LOOP", "ON" if cl.get("refilling", false) else "OFF", UiStatus.INFO if cl.get("refilling", false) else UiStatus.OK)
	sync_slider("warp", float(ship("propulsion").get("warp_target", 0.0)))


func _update_extra(_snap_data: Dictionary) -> void:
	var id := reactor_id()
	if id == "":
		return
	var c := comp(id)
	var cd := float(c.get("countdown", 0.0))
	var stage := str(ship("warp").get("stage", ""))
	_core.set_pair("Core " + str(c.get("state", "")) + " " + stage, UiStatus.clock(cd) if cd > 0.0 else fmt(float(c.get("temp", 0.0))), UiStatus.level_of(c))
