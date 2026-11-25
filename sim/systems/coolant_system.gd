class_name CoolantSystem
extends ShipSystem
## Two game coolant loops, core and EPS (D-COOL-001..003, estimate rows). A leak is a fault on the loop's store
## (integrity below 100): the loop loses level each tick in proportion to the damage. Cooling flow follows the
## level (full above flow_full_level, zero when the loop is isolated). The core loop removes heat from the warp
## core and the EPS loop from the conduits through add_heat commands; heat generation is proportional to load, so
## a drained core loop overheats the core (D-COOL-001) and a core that cannot be shut down heads for breach
## (D-COOL-002, D-CORE-001) through the generic reactor state machine.
## Commands: coolant_isolate {target, value bool} (stops the leak and the flow of that loop),
## coolant_refill {target, value bool} (moves reserve into the loop). Repairing the store ends a leak.

const LOOPS := ["coolant_core", "coolant_eps"]
const EPS_CONDUITS := [
	"eps_trunk_a", "eps_trunk_b", "eps_cross_link", "eps_sub_saucer", "eps_sub_engineering",
	"eps_sub_nacelle", "eps_sub_weapons",
]

var level: Dictionary = {"coolant_core": 100.0, "coolant_eps": 100.0}
var isolated: Dictionary = {"coolant_core": false, "coolant_eps": false}
var refilling: Dictionary = {"coolant_core": false, "coolant_eps": false}
var reserve: float = 0.0


func setup(runtime: Variant) -> void:
	super.setup(runtime)
	reserve = float(rt.tune("coolant", "reserve"))
	for id: String in LOOPS:
		level[id] = float(rt.def(id).get("charge", 100.0))


func leak_rate(id: String) -> float:
	if isolated[id]:
		return 0.0
	var integ: float = rt.comp(id).get("integrity", 100.0)
	return float(rt.tune("coolant", "max_leak")) * (100.0 - integ) / 100.0


func flow(id: String) -> float:
	if isolated[id]:
		return 0.0
	return clampf(level[id] / float(rt.tune("coolant", "full_flow_level")), 0.0, 1.0)


func handle(cmd: Dictionary, _snap: Dictionary) -> Variant:
	var type: Variant = cmd.get("type", null)
	if type != "coolant_isolate" and type != "coolant_refill":
		return null
	var t: Variant = cmd.get("target", null)
	if typeof(t) != TYPE_STRING or not LOOPS.has(t):
		return no("target must be coolant_core or coolant_eps")
	var v := bool(cmd.get("value", true))
	if type == "coolant_isolate":
		isolated[t] = v
		if v:
			refilling[t] = false
	else:
		if v and isolated[t]:
			return no("loop is isolated")
		refilling[t] = v
	return ok()


func update(snap: Dictionary) -> void:
	var amb := float(rt.data.get("ambient", 20.0))
	for id: String in LOOPS:
		var before: float = level[id]
		level[id] = maxf(0.0, level[id] - leak_rate(id))
		if refilling[id]:
			var amt := minf(minf(float(rt.tune("coolant", "refill_rate")), reserve), 100.0 - level[id])
			level[id] += amt
			reserve -= amt
			if level[id] >= 100.0 or reserve <= 0.0:
				refilling[id] = false
		if before > 25.0 and level[id] <= 25.0:
			rt.event("coolant_low", {"loop": id})
	var core: Dictionary = snap["components"]["warp_core"]
	if WarpCoreSystem.ONLINE_STATES.has(core["state"]):
		var gen: float = float(rt.tune("coolant", "heat_gen")) * core["load"]
		var rem: float = float(rt.tune("coolant", "core_cool_k")) * flow("coolant_core") * (core["temp"] - amb)
		_heat("warp_core", gen - rem)
	for id: String in EPS_CONDUITS:
		var c: Dictionary = snap["components"][id]
		var g: float = float(rt.tune("coolant", "eps_heat_gen")) * c["load"] * c["load"]
		var r: float = float(rt.tune("coolant", "eps_cool_k")) * flow("coolant_eps") * (c["temp"] - amb)
		_heat(id, g - r)


func _heat(id: String, amount: float) -> void:
	if absf(amount) > 1e-9:
		rt.cmd({"type": "add_heat", "target": id, "amount": amount})


func section() -> Dictionary:
	var out := {"reserve": reserve}
	for id: String in LOOPS:
		out[id] = {
			"level": level[id], "flow": flow(id), "leak_rate": leak_rate(id),
			"isolated": isolated[id], "refilling": refilling[id],
		}
	return out


func id_detail() -> Dictionary:
	var out := {}
	for id: String in LOOPS:
		out[id] = {"level": level[id], "isolated": isolated[id], "leaking": leak_rate(id) > 0.0}
	return out
