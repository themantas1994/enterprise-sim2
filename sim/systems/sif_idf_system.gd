class_name SifIdfSystem
extends ShipSystem
## Structural integrity (SIF) and inertial damping (IDF) fields (D-SIF-001..018, D-IDF-001..014).
## SIF: 3 generators in the primary hull and 2 in the secondary hull, 20 sources x 12 MW each (D-SIF-001..004);
## IDF: 4 primary and 2 engineering hull generators, 12 sources x 0.5 MW each (D-IDF-001..004). Each hull has a
## backup unit set (2 SIF, 3 IDF units) that covers lost generators at 55% (SIF, D-SIF-009) or 65% (IDF, D-IDF-009)
## of their rating until its service time ends (D-SIF-008, D-IDF-008). Cruise keeps 1 SIF (D-SIF-013) and 2 IDF
## (D-IDF-014) generators per hull running (checked per hull; a hull below that raises field_degraded); Reduced Power
## keeps one generator of each field for the whole spaceframe (D-SIF-022, D-IDF-019, D-MODE-026); alerts run all of
## them (the manual keeps them at hot standby, D-SIF-021, D-IDF-018; the standby draw has no ledger value, so the
## full generator draw is kept and this is a simplification).
## SIF failure ladder, by generators lost (D-SIF-016..018): 2 lost (or one lost with no backup left in its hull)
## raises the alert to yellow; 3 or 4 lost raises yellow, forces a drop out of warp and caps impulse to an
## inertially safe speed (D-SIF-017, tuning sif.safe_impulse, estimate); all 5 lost raises red and drops out of
## warp at once (same impulse cap). `ladder` is 0..3 accordingly.
## The IDF follows its target with the 295 ms lag (D-IDF-013, 3 ticks). With either field below `min_field`
## the impulse speed can change only at the inertial cap share of its normal slew rate (3 g out of over 1,000 g,
## D-SIF-014, D-SIF-015; accel_ratio); the speed itself is not clamped.

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
var _warned: Dictionary = {}
var degraded_hulls: Dictionary = {}


func setup(runtime: Variant) -> void:
	super.setup(runtime)
	for k: String in ["sif_primary", "sif_secondary"]:
		_svc[k] = int(rt.tune("sif", "service_ticks"))  # D-SIF-008
	for k: String in ["idf_primary", "idf_secondary"]:
		_svc[k] = int(rt.tune("idf", "service_ticks"))  # D-IDF-008


## Share of the normal acceleration (slew rate of the impulse speed) the fields allow: 1 with the fields up, the
## inertial cap (3 g against over 1,000 g, D-SIF-014, D-SIF-015) when either field is below min_field. It is a ratio on
## the ACCELERATION, never a clamp on the current speed: the ship only slows as far as the remaining field capacity
## allows, and after a total failure the speed is practically fixed for a long time (D-SIF-026).
func accel_ratio() -> float:
	if minf(sif_strength, idf_strength) < float(rt.tune("sif", "min_field")):
		return clampf(float(rt.tune("sif", "inertial_cap")), 0.0, 1.0)
	return 1.0


## Highest impulse fraction the SIF failure ladder allows: the inertially safe speed at ladder level 2 or 3 (D-SIF-017),
## else 1.
func speed_limit() -> float:
	if ladder >= 2:
		return float(rt.tune("sif", "safe_impulse"))
	return 1.0


## One warning event per hull when a field falls below what the cruise rule asks for.
func _warn(system: String, hulls: Array) -> void:
	for h: String in ["primary", "secondary"]:
		var key := system + "_" + h
		var now := hulls.has(h)
		if now and not _warned.get(key, false):
			rt.event("field_degraded", {"system": system, "hull": h})
		_warned[key] = now


## One field system, evaluated hull by hull. Returns {ratio (supply ratio 0..1), lost, uncovered, degraded: [hull]}.
## Cruise requires `required_per` generators in EACH hull (D-SIF-013, D-IDF-014); alerts run every generator.
## A hull's backups cover its own lost generators; the service timer of a hull only runs while its backups are in use.
func _field(prefix: String, grid: String, hulls: Array, backups: Array, units: int, frac: float, gen_mw: float, required_per: int, reduced_total: int) -> Dictionary:
	var lost_total := 0
	var uncovered := false
	var eff_total := 0.0
	var req_total := 0
	var degraded: Array = []
	var mode_name: String = rt.modes.mode
	var cruise: bool = mode_name == "cruise"
	# Reduced Power: one generator feeds the whole spaceframe through the umbilical connect (D-SIF-022, D-IDF-019, D-MODE-026);
	# it runs in the first hull that can still field one (a live generator or a backup unit covering a lost one)
	var reduced_hull := -1
	if mode_name == "reduced_power":
		reduced_hull = 0
		for h in 2:
			var n_alive := 0
			for id: String in hulls[h]:
				if rt.alive(id):
					n_alive += 1
			var k := "%s_%s" % [prefix, "primary" if h == 0 else "secondary"]
			if n_alive > 0 or (n_alive < hulls[h].size() and rt.alive(backups[h]) and _svc[k] > 0):
				reduced_hull = h
				break
	for h in 2:
		var ids: Array = hulls[h]
		var lost := 0
		for id: String in ids:
			if not rt.alive(id):
				lost += 1
		lost_total += lost
		var alive_n: int = ids.size() - lost
		var key := "%s_%s" % [prefix, "primary" if h == 0 else "secondary"]
		var u := units if (rt.alive(backups[h]) and _svc[key] > 0) else 0
		var cov := mini(lost, u)
		var required: int = ids.size()
		if reduced_hull >= 0:
			required = mini(reduced_total, ids.size()) if h == reduced_hull else 0
		elif cruise:
			required = mini(required_per, ids.size())
		var run := mini(required, alive_n)
		var cov_used := mini(required - run, cov)
		if cov_used > 0:
			_svc[key] -= 1  # only backups actually in use age (D-SIF-008, D-IDF-008)
		if lost > cov and u == 0:
			uncovered = true
		var left_key := "primary" if h == 0 else "secondary"
		var left := u - cov_used
		if prefix == "sif":
			sif_backup_left[left_key] = left
		else:
			idf_backup_left[left_key] = left
		var eff := float(run) + float(cov_used) * frac
		eff_total += eff
		req_total += required
		if eff < float(required) - 1e-9:
			degraded.append(left_key)
	rt.set_demand(grid, eff_total * gen_mw)
	var ratio: float = clampf(eff_total / float(req_total), 0.0, 1.0) * rt.pf(grid)
	return {"ratio": ratio, "lost": lost_total, "uncovered": uncovered, "degraded": degraded}


func update(_snap: Dictionary) -> void:
	var sif := _field("sif", "sif_grid", [SIF_P, SIF_S], ["sif_backup_primary", "sif_backup_secondary"],
		int(rt.tune("sif", "backup_units")), float(rt.tune("sif", "backup_fraction")), float(rt.tune("sif", "gen_mw")),
		int(rt.tune("sif", "cruise_per_hull")), int(rt.tune("sif", "reduced_total")))
	var idf := _field("idf", "idf_grid", [IDF_P, IDF_E], ["idf_backup_primary", "idf_backup_secondary"],
		int(rt.tune("idf", "backup_units")), float(rt.tune("idf", "backup_fraction")), float(rt.tune("idf", "gen_mw")),
		int(rt.tune("idf", "cruise_per_hull")), int(rt.tune("idf", "reduced_total")))
	sif_strength = sif["ratio"]
	_idf_target = idf["ratio"]
	idf_strength += (_idf_target - idf_strength) / float(rt.tune("idf", "lag_ticks"))
	degraded_hulls = {"sif": sif["degraded"], "idf": idf["degraded"]}
	_warn("sif", sif["degraded"])
	_warn("idf", idf["degraded"])
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
		"idf_strength": idf_strength, "accel_ratio": accel_ratio(), "speed_limit": speed_limit(),
		"degraded_hulls": degraded_hulls.duplicate(true), "sif_backup_units_left": sif_backup_left.duplicate(), "idf_backup_units_left": idf_backup_left.duplicate(),
	}
