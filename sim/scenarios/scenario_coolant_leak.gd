class_name ScenarioCoolantLeak
extends ScenarioBase
## A leak in the core coolant loop (D-COOL-001, D-COOL-002, D-COOL-003, D-CORE-001). The ship starts at red alert
## with the core carrying most of the load. The loop loses coolant; once the flow drops the core heats, goes to
## overload and finally to containment failing and breach. The player cuts the load, isolates or repairs the loop
## with a damage control team and refills it. Won when the leak is repaired, the loop is refilled, and the core is
## online and cool for hold_ticks in a row. Lost on breach, on ejection of the core (the cooling problem is not
## solved) or when the time runs out.

var _rt: Variant = null
var _stable: int = 0


func setup(runtime: Variant) -> void:
	_rt = runtime
	id = "coolant_leak"
	title = "Core coolant leak"
	brief = "The core coolant loop is leaking. Reduce the load, get a damage control team on the leak, refill the loop and bring the core back to normal temperature before it breaches."
	runtime.send({"type": "set_alert", "value": "red"})
	runtime.setpoints["impulse_main"] = float(runtime.tune("coolant_leak", "impulse_setting"))
	runtime.cmd({"type": "damage", "target": "coolant_core", "amount": float(runtime.tune("coolant_leak", "leak_damage"))})
	runtime.event("coolant_leak", {"loop": "coolant_core"})


func time_left() -> int:
	return maxi(0, int(_rt.tune("coolant_leak", "time_limit")) - tick) if _rt != null else -1


func update(runtime: Variant) -> void:
	var core: Dictionary = runtime.comp("warp_core")
	if core["state"] == "breach":
		lose("warp core breach after the coolant loss")
		return
	if core["state"] == "ejected":
		lose("core ejected: the ship lost its warp core and the leak was not solved")
		return
	var loop: Dictionary = runtime.comp("coolant_core")
	var cool: float = float(runtime.tune("coolant_leak", "cool_temp"))
	var good: bool = loop["integrity"] >= 100.0 and runtime.coolant.level["coolant_core"] >= float(runtime.tune("coolant_leak", "win_level")) \
		and core["state"] == "online" and core["temp"] <= cool
	_stable = _stable + 1 if good else 0
	if _stable >= int(runtime.tune("coolant_leak", "hold_ticks")):
		win("leak repaired, loop refilled and the core is cool and stable")
		return
	if tick >= int(runtime.tune("coolant_leak", "time_limit")):
		lose("time ran out before the core was stable")
