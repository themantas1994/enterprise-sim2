class_name ScenarioBorgDrain
extends ScenarioBase
## A Borg cube locks on and drains the shields (D-BORG-001..003). Its drain per shot depends on how well it has
## adapted to the shield frequency and modulation in use, so the player must keep rotating both. While the shields
## are down the cube also drains the output of the warp core and the main impulse reactor (a gameplay invention,
## D-BORG-004, estimate); the saucer reactors, and auxiliary fusion are out of its reach. Survive
## until the timer ends. Lost when the shields and the power supply both collapse for hold ticks.

var _rt: Variant = null
var _drain: float = 0.0
var _collapsed: int = 0


func setup(runtime: Variant) -> void:
	_rt = runtime
	id = "borg_drain"
	title = "Borg cube drains the shields"
	brief = "A Borg cube has locked a tractor beam on the ship. Rotate shield frequency and modulation faster than it adapts, bring the backup reactors online, and keep the ship alive until the timer ends."
	runtime.send({"type": "set_alert", "value": "red"})
	runtime.shields.set_levels(float(runtime.tune("borg_drain", "initial_level")))


func time_left() -> int:
	return maxi(0, int(_rt.tune("borg_drain", "time_limit")) - tick) if _rt != null else -1


func update(runtime: Variant) -> void:
	if tick == int(runtime.tune("borg_drain", "attack_start")):
		runtime.shields.start_borg()
	var strength: float = runtime.shields.strength
	var rate := float(runtime.tune("borg_drain", "power_drain_rate"))
	if runtime.shields.borg["active"]:
		if strength < float(runtime.tune("borg_drain", "drain_below")):
			_drain = minf(float(runtime.tune("borg_drain", "max_power_drain")), _drain + rate)
		elif strength > float(runtime.tune("borg_drain", "recover_above")):
			_drain = maxf(0.0, _drain - rate)
	runtime.set_scale("warp_core", "borg", 1.0 - _drain)
	runtime.set_scale("impulse_main", "borg", 1.0 - _drain)
	var wanted := 0.0
	var got := 0.0
	for cid: String in runtime.components():
		var c: Dictionary = runtime.components()[cid]
		if c["kind"] == "consumer":
			wanted += c["demand"] * c["allocation"]
			got += c["power"]
	var supply := got / wanted if wanted > 1e-9 else 1.0
	if strength < float(runtime.tune("borg_drain", "collapse_strength")) and supply < float(runtime.tune("borg_drain", "collapse_supply")):
		_collapsed += 1
	else:
		_collapsed = 0
	if _collapsed >= int(runtime.tune("borg_drain", "collapse_hold")):
		lose("shields and power collapsed")
		return
	if tick >= int(runtime.tune("borg_drain", "time_limit")):
		win("the cube lost its lock: shields held until the timer ended")
