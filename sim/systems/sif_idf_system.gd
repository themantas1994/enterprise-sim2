class_name SifIdfSystem
extends ShipSystem
## Structural integrity (SIF) and inertial damping (IDF) fields (D-SIF-001..018, D-IDF-001..014).
## SIF: 3 generators in the primary hull and 2 in the secondary hull, 20 sources x 12 MW each (D-SIF-001..004);
## IDF: 4 primary and 2 engineering hull generators, 12 sources x 0.5 MW each (D-IDF-001..004). Each hull has a
## backup unit set (2 SIF, 3 IDF units) that covers lost generators at 55% (SIF, D-SIF-009) or 65% (IDF, D-IDF-009)
## of their rating until its service time ends (D-SIF-008, D-IDF-008). Cruise keeps 1 SIF (D-SIF-013) and 2 IDF
## (D-IDF-014) generators per hull running; alerts run all of them.
## SIF failure ladder, by generators lost (D-SIF-016..018): 2 lost (or one lost with no backup left in its hull)
## raises the alert to yellow; 3 or 4 lost raises yellow and forces a drop out of warp with impulse capped to an
## inertially safe speed; all 5 lost raises red and drops out of warp at once. `ladder` is 0..3 accordingly.
## The IDF follows its target with the 295 ms lag (D-IDF-013, 3 ticks). With either field below `min_field`
## impulse is capped at 3 g worth of acceleration out of over 1,000 g (D-SIF-014, D-SIF-015).

const SIF_P := ["sif_gen_p1", "sif_gen_p2", "sif_gen_p3"]
const SIF_S := ["sif_gen_s1", "sif_gen_s2"]
const IDF_P := ["idf_gen_p1", "idf_gen_p2", "idf_gen_p3", "idf_gen_p4"]
const IDF_E := ["idf_gen_e1", "idf_gen_e2"]

var ladder: int = 0
var sif_strength: float = 1.0
var idf_strength: float = 1.0
var sif_lost: int = 0
var idf_lost: int = 0
var sif_backup_left: Dictionary = {"primary": 0, "secondary": 0}
var idf_backup_left: Dictionary = {"primary": 0, "secondary": 0}
var _idf_target: float = 1.0
var _svc: Dictionary = {}
var _calc: Dictionary = {}


func setup(runtime: Variant) -> void:
	super.setup(runtime)
	for k: String in ["sif_primary", "sif_secondary", "idf_primary", "idf_secondary"]:
		_svc[k] = int(rt.tune("sif", "service_ticks"))


func impulse_cap() -> float:
	if minf(sif_strength, idf_strength) < float(rt.tune("sif", "min_field")):
		return float(rt.tune("sif", "inertial_cap"))
	return 1.0


## One field system: returns {demand, ratio (supply ratio 0..1), lost, covered}.
func _field(prefix: String, grid: String, hulls: Array, backups: Array, units: int, frac: float, gen_mw: float, required_per: Array) -> Dictionary:
	var alive_n := 0
	var lost_total := 0
	var covered_total := 0
	var total_n := 0
	var uncovered := false
	for h in 2:
		var ids: Array = hulls[h]
		var lost := 0
		for id: String in ids:
			if not rt.alive(id):
				lost += 1
		total_n += ids.size()
		alive_n += ids.size() - lost
		lost_total += lost
		var key := "%s_%s" % [prefix, "primary" if h == 0 else "secondary"]
		var u := units if (rt.alive(backups[h]) and _svc[key] > 0) else 0
		var cov := mini(lost, u)
		covered_total += cov
		if cov > 0:
			_svc[key] -= 1
		if lost > cov and lost > 0 and u == 0:
			uncovered = true
		var left_key := "primary" if h == 0 else "secondary"
		if prefix == "sif":
			sif_backup_left[left_key] = u - cov
		else:
			idf_backup_left[left_key] = u - cov
	var mode: String = rt.modes.mode
	var required := int(required_per[0]) if (mode == "cruise" or mode == "reduced_power") else total_n
	var run := mini(required, alive_n)
	var cov_used := mini(required - run, covered_total)
	var eff := float(run) + float(cov_used) * frac
	rt.set_demand(grid, eff * gen_mw)
	var ratio: float = clampf(eff / float(required), 0.0, 1.0) * rt.pf(grid)
	return {"ratio": ratio, "lost": lost_total, "uncovered": uncovered}


func update(_snap: Dictionary) -> void:
	var sif := _field("sif", "sif_grid", [SIF_P, SIF_S], ["sif_backup_primary", "sif_backup_secondary"],
		int(rt.tune("sif", "backup_units")), float(rt.tune("sif", "backup_fraction")), float(rt.tune("sif", "gen_mw")),
		[int(rt.tune("sif", "cruise_active"))])
	var idf := _field("idf", "idf_grid", [IDF_P, IDF_E], ["idf_backup_primary", "idf_backup_secondary"],
		int(rt.tune("idf", "backup_units")), float(rt.tune("idf", "backup_fraction")), float(rt.tune("idf", "gen_mw")),
		[int(rt.tune("idf", "cruise_active"))])
	sif_strength = sif["ratio"]
	_idf_target = idf["ratio"]
	idf_strength += (_idf_target - idf_strength) / float(rt.tune("idf", "lag_ticks"))
	sif_lost = sif["lost"]
	idf_lost = idf["lost"]
	var level := 0
	if sif_lost >= int(rt.tune("sif", "red_lost")):
		level = 3
	elif sif_lost >= int(rt.tune("sif", "slow_lost")):
		level = 2
	elif sif_lost >= int(rt.tune("sif", "yellow_lost")) or sif["uncovered"]:
		level = 1
	if level > ladder:
		rt.event("sif_ladder", {"level": level, "lost": sif_lost})
	ladder = level
	if level >= 1:
		rt.modes.require_alert("red" if level == 3 else "yellow", "SIF failure ladder (D-SIF-016..018)")
	if level >= 2:
		rt.propulsion.force_downwarp("SIF failure ladder level %d" % level)


func section() -> Dictionary:
	return {
		"ladder": ladder, "sif_lost": sif_lost, "idf_lost": idf_lost, "sif_strength": sif_strength,
		"idf_strength": idf_strength, "impulse_cap": impulse_cap(),
		"sif_backup_units_left": sif_backup_left.duplicate(), "idf_backup_units_left": idf_backup_left.duplicate(),
	}
