class_name PropulsionSystem
extends ShipSystem
## Warp and impulse propulsion, nacelles and the navigational deflector.
## Warp: factor up to 9.6 (D-DESIGN-003), 9.2 sustainable (D-DESIGN-002); above 9.2 for at most 12 hours
## (D-DESIGN-004). Needs the core online in warp mode, both nacelles, fuel, and a SIF ladder below 2 (D-SIF-017).
## Nacelle power grows with the cube of the warp factor (game-sized, estimate) and with the shield coupling loss
## (up to 32% at maximum shield output, D-SHLD-020). Warp collapses when the nacelles get less than half their
## power, when the core leaves warp mode or goes down, or when the SIF ladder demands it.
## Navigational deflector: 27 MW at impulse (D-NAVD-006); at warp 80% (D-NAVD-008) of each running generator
## (768 MW = 6 sources x 128 MW, D-NAVD-002, D-NAVD-003), 2 generators above warp 8 and 3 above 9.2 (D-NAVD-011).
## Impulse: fraction 0..1 of normal impulse, which is limited to 0.25 c (D-IMP-006).
## Commands: set_warp {value}, set_impulse {value}.

const NAC := ["warp_nacelle_port", "warp_nacelle_stbd"]

var warp: float = 0.0
var warp_target: float = 0.0
var impulse: float = 0.0
var impulse_target: float = 0.0
var nac_pf: float = 1.0
var high_warp_left: float = 0.0


func setup(runtime: Variant) -> void:
	super.setup(runtime)
	high_warp_left = float(rt.tune("propulsion", "high_warp_ticks"))


func nacelles_ok() -> bool:
	for id: String in NAC:
		if not rt.alive(id):
			return false
	return true


func speed_c() -> float:
	return impulse * float(rt.tune("propulsion", "impulse_speed_c"))


func force_downwarp(reason: String) -> void:
	if warp > 0.0 or warp_target > 0.0:
		warp = 0.0
		warp_target = 0.0
		rt.event("downwarp", {"reason": reason})


func handle(cmd: Dictionary, _snap: Dictionary) -> Variant:
	var type: Variant = cmd.get("type", null)
	var v: Variant = cmd.get("value", null)
	if type == "set_warp":
		if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT or is_nan(float(v)) or float(v) < 0.0 or float(v) > float(rt.tune("propulsion", "warp_max")):
			return no("warp factor must be within 0..%s" % str(rt.tune("propulsion", "warp_max")))
		var w := float(v)
		if w > 0.0:
			if not rt.warp.can_warp():
				return no("warp core must be online in warp mode")
			if rt.sif_idf.ladder >= 2:
				return no("SIF failure ladder forbids warp (D-SIF-017)")
			if not nacelles_ok():
				return no("a warp nacelle is lost")
			if rt.fuel.warp_fuel_factor() <= 0.0:
				return no("no antimatter or deuterium for warp")
			if w > float(rt.tune("propulsion", "warp_sustained")) and high_warp_left <= 0.0:
				return no("time at high warp used up (D-DESIGN-004)")
		rt.warp.alignment = maxf(0.0, rt.warp.alignment - float(rt.tune("warp", "align_loss_per_warp")) * absf(w - warp_target))
		warp_target = w
		return ok()
	if type == "set_impulse":
		if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT or is_nan(float(v)) or float(v) < 0.0 or float(v) > 1.0:
			return no("impulse must be within 0..1")
		if float(v) > rt.sif_idf.impulse_cap():
			return no("inertial damping too weak, impulse limited to %s (D-SIF-014)" % str(rt.sif_idf.impulse_cap()))
		if float(v) > 0.0 and not rt.fuel.impulse_fuel_ok():
			return no("no deuterium for the main impulse engine")
		impulse_target = float(v)
		return ok()
	return null


func update(_snap: Dictionary) -> void:
	var sustained := float(rt.tune("propulsion", "warp_sustained"))
	if warp > 0.0 or warp_target > 0.0:
		if not rt.warp.can_warp():
			force_downwarp("warp core not online in warp mode")
		elif not nacelles_ok():
			force_downwarp("warp nacelle lost")
		elif rt.fuel.warp_fuel_factor() <= 0.0:
			force_downwarp("warp fuel exhausted")
		elif nac_pf < float(rt.tune("propulsion", "nac_collapse_pf")):
			force_downwarp("nacelles below half power")
	if warp > sustained:
		high_warp_left -= 1.0
		if high_warp_left <= 0.0:
			warp_target = minf(warp_target, sustained)
			rt.event("high_warp_limit", {})
	warp = move_toward(warp, warp_target, float(rt.tune("propulsion", "warp_slew")))
	var cap: float = rt.sif_idf.impulse_cap()
	impulse_target = minf(impulse_target, cap)
	if not rt.fuel.impulse_fuel_ok():
		impulse_target = 0.0
	impulse = move_toward(impulse, impulse_target, float(rt.tune("propulsion", "impulse_slew")))
	impulse = minf(impulse, cap)
	# demands
	var wd := maxf(warp, warp_target)
	var coupling: float = 1.0 - float(rt.tune("shields", "warp_coupling_loss")) * rt.shields.output_level
	var nac_mw := float(rt.tune("propulsion", "nac_idle_mw"))
	if wd > 0.0:
		nac_mw += float(rt.tune("propulsion", "nac_mw_max")) * pow(wd / float(rt.tune("propulsion", "warp_max")), float(rt.tune("propulsion", "nac_exponent"))) / coupling
	var pf_sum := 0.0
	for id: String in NAC:
		rt.set_demand(id, nac_mw)
		pf_sum += rt.pf(id)
	nac_pf = pf_sum / float(NAC.size())
	var nav_mw := float(rt.tune("propulsion", "nav_impulse_mw"))
	if wd > 0.0:
		var gens := 1
		if wd > 8.0:
			gens = 2
		if wd > sustained:
			gens = 3
		nav_mw = float(gens) * float(rt.tune("propulsion", "nav_gen_mw")) * float(rt.tune("propulsion", "nav_warp_fraction"))
	rt.set_demand("nav_deflector", nav_mw)
	rt.set_demand("impulse_drive", float(rt.tune("propulsion", "impulse_idle_mw")) + impulse * float(rt.tune("propulsion", "impulse_max_mw")))


func section() -> Dictionary:
	return {
		"warp": warp, "warp_target": warp_target, "impulse": impulse, "impulse_target": impulse_target,
		"speed_c": speed_c(), "nacelle_power": nac_pf, "high_warp_left": high_warp_left,
		"nav_deflector_mw": rt.comp("nav_deflector").get("demand", 0.0),
	}
