extends RefCounted
## Helpers for the 1701-D system and scenario suites. Tests drive the runtime with commands only.

const SHIP := "res://ships/1701d.json"


static func make(seed_value: int = 1, tweak: Callable = Callable()) -> ShipRuntime:
	var raw := ShipData.read_file(SHIP)
	if tweak.is_valid():
		tweak.call(raw)
	return ShipRuntime.create_from_data(raw, seed_value)


static func run(rt: ShipRuntime, ticks: int) -> void:
	for i in ticks:
		rt.step()


## Steps until `cond.call()` is true or `limit` ticks passed. Returns the ticks stepped.
static func run_until(rt: ShipRuntime, cond: Callable, limit: int) -> int:
	for i in limit:
		if cond.call():
			return i
		rt.step()
	return limit


static func comp(rt: ShipRuntime, id: String) -> Dictionary:
	return rt.snapshot()["components"][id]


static func accepted(rt: ShipRuntime, cmd: Dictionary) -> bool:
	return rt.send(cmd)["accepted"]


static func producer_def(raw: Dictionary, id: String) -> Dictionary:
	for d: Dictionary in raw["producers"]:
		if d["id"] == id:
			return d
	return {}


## Sets a plain (unwrapped) key on a raw producer definition; used to start a ship with a cold warp core.
static func set_state(raw: Dictionary, id: String, state: String) -> void:
	producer_def(raw, id)["state"] = state


## Stable text form of a snapshot for equality checks.
static func fingerprint(rt: ShipRuntime) -> String:
	return JSON.stringify(rt.snapshot())
