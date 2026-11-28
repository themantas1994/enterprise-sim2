class_name ShieldSystem
extends ShipSystem
## Deflector shields (D-SHLD-001..021, D-BORG-001..003). One grid consumer (shield_grid) draws the power of the
## active generators; backups (4 units each, 65%) cover lost generators.
## Reading of the ledger used here: the cruise graviton load is the ledger's nominal 1,152 MW (D-SHLD-011), which is
## three generators at their full 384 MW rating; the shield LEVEL shown to the player stays at about 5% (D-SHLD-012,
## the radiation-standard bands), so cruise draw is 3 x 384 MW while the displayed level is 0.05. Generators at
## alert (yellow and red) run at a level of at least 85% (D-SHLD-013), up to 7 in phase lock (D-SHLD-014). Level
## normalisation uses the fixed 0.85 reference. The backup service time (D-SHLD-009) is not modelled. The Borg
## adaptation is a gameplay mapping of the phaser adaptation of D-BORG-001/002 onto shield frequency, and the drain
## depends on how well the cube matches the shield setting (the reverse of D-SHLD-019 on purpose). Four facings (fore, aft, port, stbd) hold a level 0..1;
## the weights decide how the grid's capacity and regeneration are shared. Shields cost warp coupling (up to 32%
## at maximum output, D-SHLD-020), applied in the propulsion system.
## Frequency and modulation (0..999) are player controls (D-SHLD-018). A Borg attack (start_borg) drains every
## facing by a step each shot; its drain depends on how well its adapted frequency and modulation match the
## shield's (D-SHLD-019 reversed for the attacker, D-BORG-001, D-BORG-002, D-BORG-003). The Borg move a fixed step
## towards the shield setting after each shot, so a changed setting buys a few shots.
## Commands: shield_set {frequency?, modulation?}, shield_set_weights {fore, aft, port, stbd},
## shield_set_level {value 0.85..1} (the level used at yellow and red alert; below 85% is rejected).

const FACINGS := ["fore", "aft", "port", "stbd"]
const GENS := [
	"shield_gen_p1", "shield_gen_p2", "shield_gen_p3", "shield_gen_p4", "shield_gen_p5",
	"shield_gen_s1", "shield_gen_s2", "shield_gen_s3",
	"shield_gen_np1", "shield_gen_np2", "shield_gen_ns1", "shield_gen_ns2",
]
## Order in which generators are switched on: one per major section first (primary hull, secondary hull, nacelles; the
## cruise rule D-SHLD-025, so the three cruise generators of D-SHLD-011 are one in each), then the rest in turn. A
## lost generator is skipped and the next one of the list takes over.
const ORDER := [
	"shield_gen_p1", "shield_gen_s1", "shield_gen_np1",
	"shield_gen_p2", "shield_gen_s2", "shield_gen_ns1",
	"shield_gen_p3", "shield_gen_s3", "shield_gen_np2",
	"shield_gen_p4", "shield_gen_ns2", "shield_gen_p5",
]
const SECONDARY_STANDBY := ["shield_gen_s1", "shield_gen_s2", "shield_gen_s3"]
const BACKUPS := ["shield_backup_primary", "shield_backup_secondary"]
const GRID := "shield_grid"

var frequency: int = 500
var modulation: int = 500
var weights: Dictionary = {"fore": 0.25, "aft": 0.25, "port": 0.25, "stbd": 0.25}
var levels: Dictionary = {"fore": 0.0, "aft": 0.0, "port": 0.0, "stbd": 0.0}
var alert_level: float = 0.85
var strength: float = 0.0
var output_level: float = 0.0  # delivered share of rated output, 0..1
var capacity: float = 1.0
var active: Array = []
var backups_used: int = 0
var borg: Dictionary = {"active": false, "freq": 0, "mod": 0, "match": 0.0, "shots": 0, "shot_in": 0}


func setup(runtime: Variant) -> void:
	super.setup(runtime)
	alert_level = float(rt.tune("shields", "alert_level"))
	var start := float(rt.tune("shields", "cruise_level")) / float(rt.tune("shields", "alert_level"))
	for f: String in FACINGS:
		levels[f] = start * 4.0 * weights[f]


## Scenario hook: sets every facing to `value` (0..1).
func set_levels(value: float) -> void:
	for f: String in FACINGS:
		levels[f] = clampf(value, 0.0, 1.0)
	strength = clampf(value, 0.0, 1.0)


func start_borg() -> void:
	borg["active"] = true
	borg["freq"] = rt.rng.randi_range(0, 999)
	borg["mod"] = rt.rng.randi_range(0, 999)
	borg["shot_in"] = int(rt.tune("shields", "shot_interval"))
	borg["shots"] = 0
	rt.event("borg_attack", {})


func stop_borg() -> void:
	borg["active"] = false
	borg["match"] = 0.0


func handle(cmd: Dictionary, _snap: Dictionary) -> Variant:
	var type: Variant = cmd.get("type", null)
	match type:
		"shield_set":
			var hi := int(rt.tune("shields", "freq_range")) - 1
			var f: Variant = cmd.get("frequency", frequency)
			var m: Variant = cmd.get("modulation", modulation)
			for v: Variant in [f, m]:
				if not finite(v) or float(v) < 0.0 or float(v) > hi or float(v) != floorf(float(v)):
					return no("frequency and modulation must be integers within 0..%d" % hi)
			frequency = int(f)
			modulation = int(m)
			return ok()
		"shield_set_weights":
			var total := 0.0
			var w := {}
			for k: String in FACINGS:
				var v: Variant = cmd.get(k, null)
				if not finite(v) or float(v) < 0.0 or float(v) > 1.0e6:
					return no("weights need a number >= 0 for each of fore, aft, port, stbd")
				w[k] = float(v)
				total += float(v)
			if total <= 0.0:
				return no("weights must not all be zero")
			for k: String in FACINGS:
				weights[k] = w[k] / total
			return ok()
		"shield_set_level":
			var lv: Variant = cmd.get("value", null)
			var lo := float(rt.tune("shields", "alert_level"))
			if not finite(lv) or float(lv) < lo or float(lv) > 1.0:
				return no("level must be within %s..1 (D-SHLD-013: at least 85%% at alert)" % str(lo))
			alert_level = float(lv)
			return ok()
	return null


func match_of() -> float:
	var dist := (absf(frequency - borg["freq"]) + absf(modulation - borg["mod"])) / 2.0
	return clampf(1.0 - dist / float(rt.tune("shields", "match_width")), 0.0, 1.0)


func update(_snap: Dictionary) -> void:
	var mode: String = rt.modes.mode
	var n: int = int(rt.tune("shields", "cruise_gens"))
	var lvl := float(rt.tune("shields", "cruise_level"))  # displayed level
	var draw := 1.0  # share of rated power drawn: nominal cruise graviton load (D-SHLD-011)
	if mode == "yellow_alert" or mode == "red_alert":
		lvl = maxf(alert_level, float(rt.tune("shields", "alert_level")))
		draw = lvl
	if mode == "red_alert":
		n = int(rt.tune("shields", "max_gens"))
	elif mode == "reduced_power":
		n = int(rt.tune("shields", "reduced_gens"))
	var avail: Array = []
	for id: String in ORDER:
		if rt.alive(id):
			avail.append(id)
	active = avail.slice(0, n)
	var shortfall := n - active.size()
	var units := 0
	for b: String in BACKUPS:
		if rt.alive(b):
			units += int(rt.tune("shields", "backup_units"))
	backups_used = mini(shortfall, units)
	var eff_gens := float(active.size()) + float(backups_used) * float(rt.tune("shields", "backup_fraction"))
	var gen_mw := float(rt.tune("shields", "gen_mw"))
	var demand := eff_gens * gen_mw * draw
	if mode == "yellow_alert":
		for id: String in SECONDARY_STANDBY:
			if rt.alive(id):
				demand += gen_mw * float(rt.tune("shields", "yellow_standby_level"))
	rt.set_demand(GRID, demand)
	var pf: float = rt.pf(GRID)
	output_level = lvl * pf * float(active.size()) / float(rt.tune("shields", "max_gens"))
	capacity = clampf(eff_gens / float(n), 0.0, 1.0)
	var norm := lvl / float(rt.tune("shields", "alert_level"))
	var regen := float(rt.tune("shields", "regen"))
	var total := 0.0
	for f: String in FACINGS:
		var w: float = weights[f]
		var mx := clampf(4.0 * w * pf * capacity * norm, 0.0, 1.0)
		if levels[f] > mx:
			levels[f] = maxf(mx, levels[f] - float(rt.tune("shields", "fall_rate")))
		else:
			levels[f] = minf(mx, levels[f] + regen * pf * capacity * minf(1.0, 4.0 * w))
	if borg["active"]:
		borg["match"] = match_of()
		borg["shot_in"] -= 1
		if borg["shot_in"] <= 0:
			borg["shot_in"] = int(rt.tune("shields", "shot_interval"))
			borg["shots"] += 1
			var fl := float(rt.tune("shields", "drain_floor"))
			var drain := float(rt.tune("shields", "shot_drain")) * (fl + (1.0 - fl) * float(borg["match"]))
			for f: String in FACINGS:
				levels[f] = maxf(0.0, levels[f] - drain)
			var step := float(rt.tune("shields", "adapt_step"))
			borg["freq"] += int(clampf(frequency - borg["freq"], -step, step))
			borg["mod"] += int(clampf(modulation - borg["mod"], -step, step))
	for f: String in FACINGS:
		total += levels[f]
	strength = total / 4.0


func section() -> Dictionary:
	return {
		"frequency": frequency, "modulation": modulation, "weights": weights.duplicate(), "levels": levels.duplicate(),
		"strength": strength, "capacity": capacity, "alert_level": alert_level, "active_generators": active.duplicate(),
		"backup_units_used": backups_used, "borg": borg.duplicate(),
	}


func id_detail() -> Dictionary:
	var out := {}
	for id: String in GENS:
		out[id] = {"active": active.has(id)}
	return out
