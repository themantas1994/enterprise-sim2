class_name Thermal
extends RefCounted
## Heat, efficiency, integrity and damage for every component (all kinds).
##
## Per tick, for each component with load L (output / rated; 0 for consumers and junctions):
##   temp += overload_heat * max(0, L - 1) - cooling * (temp - ambient)
##   over = max(0, temp - heat_threshold)
##   integrity -= heat_damage * over                (floored at 0)
##   efficiency = clamp(1 - over / eff_span, min_eff, 1)
## Integrity 0 means destroyed (no output, no service). A conduit at integrity 0 is cut.
## damage() and repair() back the commands of the same name and the random faults.

const MAX_INTEGRITY := 100.0


static func step(c: Dictionary) -> void:
	var load_value: float = c["load"]
	var heat: float = c["overload_heat"] * maxf(0.0, load_value - 1.0)
	c["temp"] = c["temp"] + heat - c["cooling"] * (c["temp"] - c["ambient"])
	var over: float = maxf(0.0, c["temp"] - c["heat_threshold"])
	if over > 0.0:
		damage(c, c["heat_damage"] * over)
	c["efficiency"] = clampf(1.0 - over / c["eff_span"], c["min_eff"], 1.0)


static func damage(c: Dictionary, amount: float) -> void:
	c["integrity"] = maxf(0.0, c["integrity"] - amount)
	if c["integrity"] <= 0.0 and c["kind"] == "conduit":
		c["cut"] = true


static func repair(c: Dictionary) -> void:
	c["integrity"] = MAX_INTEGRITY
	if c["kind"] == "conduit":
		c["cut"] = false
