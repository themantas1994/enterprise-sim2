class_name ScenarioCoreBreach
extends ScenarioBase
## Containment of the warp core is failing (D-CORE-001..003, D-CORE-005, D-SAFE-003, D-SAFE-004, D-ENG-007).
## A fault eats the core's integrity every tick. Before it reaches the critical integrity the core can still be
## shut down (stabilise). Past it the generic reactor machine counts down to breach (120 s, D-CORE-005); then the
## player can eject the core (needs the ejection system powered, D-CORE-003) or hold the annular forcefield up
## (D-ENG-007) so the breach is contained. Lost when the core breaches without the forcefield holding.

var _rt: Variant = null


func setup(runtime: Variant) -> void:
	_rt = runtime
	id = "core_breach"
	title = "Warp core containment failure"
	brief = "Antimatter containment is failing. Shut the core down before it goes critical, or eject it, or raise the containment forcefield before the countdown ends."
	runtime.cmd({"type": "damage", "target": "warp_core", "amount": float(runtime.tune("core_breach", "initial_damage"))})
	runtime.warp.start_containment_fault(float(runtime.tune("core_breach", "fault_rate")))


func time_left() -> int:
	if _rt == null or status != RUNNING:
		return 0 if status != RUNNING else -1
	var c: Dictionary = _rt.comp("warp_core")
	if c.is_empty():
		return -1
	if c["state"] == "containment_failing":
		return int(c["countdown"])
	var crit: float = float(_rt.def("warp_core").get("critical_integrity", 40.0))
	var rate: float = maxf(1e-9, _rt.warp.fault_rate)
	return int(ceil(maxf(0.0, c["integrity"] - crit) / rate)) + int(_rt.def("warp_core").get("breach_ticks", 30))


func update(runtime: Variant) -> void:
	var st: String = runtime.comp("warp_core")["state"]
	match st:
		"cold":
			win("core shut down before containment failed (stabilised)")
		"ejected":
			win("core ejected, the ship survives on impulse power (D-SAFE-003)")
		"breach":
			if runtime.warp.breach_state == "contained":
				win("breach contained by the annular forcefield (D-ENG-007)")
			else:
				lose("warp core breach: the ship is destroyed")
