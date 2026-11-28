class_name FuelSystem
extends ShipSystem
## Fuel: 30 antimatter pods (D-FUEL-001..003), the main deuterium tank (D-FUEL-006, D-FUEL-007), the saucer auxiliary
## deuterium tank (D-IMP-005) and the antimatter generator (D-FUEL-013, D-FUEL-014).
## Live levels are in snapshot().ship.detail[id].level (m3). Burn is proportional to delivered power over the
## endurance of a full load (D-FUEL-004, D-FUEL-009). Pods need containment power (consumer
## antimatter_containment): below the powered threshold the containment falls, and at or below the collapse
## level the pod assembly is ejected automatically (D-FUEL-005, D-SAFE-005), which empties all pods.
## Commands: antimatter_generator_set {value bool}. Hooks for scenarios and tests: set_level(id, m3).

const PODS := [
	"antimatter_pod_01", "antimatter_pod_02", "antimatter_pod_03", "antimatter_pod_04", "antimatter_pod_05",
	"antimatter_pod_06", "antimatter_pod_07", "antimatter_pod_08", "antimatter_pod_09", "antimatter_pod_10",
	"antimatter_pod_11", "antimatter_pod_12", "antimatter_pod_13", "antimatter_pod_14", "antimatter_pod_15",
	"antimatter_pod_16", "antimatter_pod_17", "antimatter_pod_18", "antimatter_pod_19", "antimatter_pod_20",
	"antimatter_pod_21", "antimatter_pod_22", "antimatter_pod_23", "antimatter_pod_24", "antimatter_pod_25",
	"antimatter_pod_26", "antimatter_pod_27", "antimatter_pod_28", "antimatter_pod_29", "antimatter_pod_30",
]
const MAIN := "deuterium_tank_main"
const AUX_TANK := "deuterium_aux_saucer"
const CONTAIN := "antimatter_containment"
const GEN := "antimatter_generator"
const SAUCER_SOURCES := ["impulse_saucer_1", "impulse_saucer_2", "aux_fusion_1", "aux_fusion_2"]

var levels: Dictionary = {}
var containment: float = 1.0
var pods_ejected: bool = false
var generator_on: bool = false


func setup(runtime: Variant) -> void:
	super.setup(runtime)
	var pod_m3 := float(rt.tune("fuel", "pod_m3"))
	for id: String in PODS:
		levels[id] = pod_m3
	levels[MAIN] = float(rt.tune("fuel", "deuterium_main_m3"))
	levels[AUX_TANK] = _aux_total_m3()


## The saucer has 32 auxiliary tanks of 113 m3 with cross-feeds (D-IMP-017, D-IMP-005, D-FUEL-012), modelled as one store.
func _aux_total_m3() -> float:
	return float(rt.tune("fuel", "deuterium_aux_tanks")) * float(rt.tune("fuel", "deuterium_aux_tank_m3"))


func set_level(id: String, m3: float) -> void:
	levels[id] = maxf(0.0, m3)


func antimatter_total() -> float:
	var t := 0.0
	for id: String in PODS:
		t += levels[id]
	return t


func warp_fuel_factor() -> float:
	return 1.0 if (not pods_ejected and antimatter_total() > 0.0 and levels[MAIN] > 0.0) else 0.0


func impulse_fuel_ok() -> bool:
	return levels[MAIN] > 0.0


func handle(cmd: Dictionary, _snap: Dictionary) -> Variant:
	if cmd.get("type", null) == "antimatter_generator_set":
		generator_on = bool(cmd.get("value", true))
		return ok()
	return null


func update(_snap: Dictionary) -> void:
	_containment()
	_burn()
	_generator()
	rt.set_scale("impulse_main", "fuel", 1.0 if levels[MAIN] > 0.0 else 0.0)
	var aux_ok := 1.0 if levels[AUX_TANK] > 0.0 else 0.0
	for id: String in SAUCER_SOURCES:
		rt.set_scale(id, "fuel", aux_ok)


func _containment() -> void:
	rt.set_demand(CONTAIN, float(rt.tune("fuel", "containment_mw")))
	if pods_ejected:
		return
	if rt.pf(CONTAIN) >= float(rt.tune("fuel", "containment_ok_pf")) and rt.alive(CONTAIN):
		containment = minf(1.0, containment + float(rt.tune("fuel", "containment_regain")))
	else:
		containment = maxf(0.0, containment - float(rt.tune("fuel", "containment_decay")))
	if containment <= float(rt.tune("fuel", "containment_collapse")):
		pods_ejected = true
		for id: String in PODS:
			levels[id] = 0.0
		rt.event("pods_ejected", {"reason": "containment collapse, automatic pod ejection (D-FUEL-005, D-SAFE-005)"})


func _burn() -> void:
	var nominal := float(rt.tune("fuel", "nominal_mw"))
	var endurance := float(rt.tune("fuel", "endurance_ticks"))
	var p_core: float = rt.comp("warp_core").get("power", 0.0)
	var p_imp: float = rt.comp("impulse_main").get("power", 0.0)
	levels[MAIN] = maxf(0.0, levels[MAIN] - (p_core + p_imp) / nominal * float(rt.tune("fuel", "deuterium_main_m3")) / endurance)
	var am_burn := p_core / nominal * float(rt.tune("fuel", "pod_m3")) * PODS.size() / endurance
	for id: String in PODS:
		if am_burn <= 0.0:
			break
		var take := minf(levels[id], am_burn)
		levels[id] -= take
		am_burn -= take
	var leak := float(rt.tune("fuel", "pod_leak_m3"))
	for id: String in PODS:
		var integ: float = rt.comp(id).get("integrity", 100.0)
		if integ < 100.0:
			levels[id] = maxf(0.0, levels[id] - leak * (100.0 - integ) / 100.0)
	var p_saucer := 0.0
	for id: String in SAUCER_SOURCES:
		p_saucer += rt.comp(id).get("power", 0.0)
	levels[AUX_TANK] = maxf(0.0, levels[AUX_TANK] - p_saucer / float(rt.tune("fuel", "aux_nominal_mw")) * _aux_total_m3() / float(rt.tune("fuel", "aux_endurance_ticks")))


func _generator() -> void:
	rt.set_demand(GEN, float(rt.tune("fuel", "generator_mw")) if generator_on else 0.0)
	if not generator_on or pods_ejected or rt.pf(GEN) < float(rt.tune("fuel", "containment_ok_pf")):
		return
	var per_tick := float(rt.tune("fuel", "generator_m3_per_h")) / float(rt.tune("fuel", "ticks_per_hour"))
	var cost := per_tick * float(rt.tune("fuel", "generator_ratio"))
	if levels[MAIN] < cost:
		return
	for id: String in PODS:
		if levels[id] + per_tick <= float(rt.tune("fuel", "pod_m3")):
			levels[id] += per_tick
			levels[MAIN] -= cost
			return


func section() -> Dictionary:
	return {
		"antimatter_m3": antimatter_total(), "deuterium_main_m3": levels[MAIN], "deuterium_aux_m3": levels[AUX_TANK],
		"containment": containment, "pods_ejected": pods_ejected, "generator_on": generator_on,
	}


func id_detail() -> Dictionary:
	var out := {}
	for id: String in levels:
		out[id] = {"level": levels[id]}
	return out
