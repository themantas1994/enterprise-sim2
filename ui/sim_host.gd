extends Node
## SimHost autoload (ADR 0001, ADR 0002): the single bridge between the sim and the panels.
## It owns the ship runtime, steps it at a fixed 10 Hz from the frame delta and publishes snapshots.
## Public interface for panels:
##   snapshot, prev                 latest and previous snapshot (Dictionary, deep copies from the runtime)
##   signal snapshot_ready(snap, prev), signal scenario_changed()
##   panel_ids() -> Array[String]   panel ids in station-menu order
##   panel_title(id) -> String, panel_components(id) -> Array[String], all_ids() -> Array[String]
##   power_unit() -> String
##   send(cmd) -> Dictionary        the only write path for commands
##   scenario_ids() -> Array, start_scenario(id)
## Setup: start(ship_path, seed) builds ShipRuntime.create(...) and reads the panel map from the ship file's
## `panels` object, or from ships/1701d_panels.json when the ship file has none. use_runtime(rt, map) injects
## a runtime and a panel map (tests).

signal snapshot_ready(snap: Dictionary, prev: Dictionary)
signal scenario_changed

const TICK := 0.1
const MAX_STEPS_PER_FRAME := 5
const SHIP_PATH := "res://ships/1701d.json"
const PANEL_FILE := "res://ships/1701d_panels.json"
const RUNTIME_SCRIPT := "res://sim/systems/ship_runtime.gd"
const PANEL_ORDER := ["msd", "warp_core", "fuel", "eps", "shields", "impulse", "sif_idf", "damage_control"]

var snapshot: Dictionary = {}
var prev: Dictionary = {}
var paused := false
var seed_value := 1
var auto_start := true
var load_errors: Array[String] = []

var _runtime: Object
var _panels: Dictionary = {}
var _acc := 0.0
var _unit := ""


func _ready() -> void:
	if auto_start and _runtime == null:
		start(SHIP_PATH, seed_value)


func _process(delta: float) -> void:
	advance(delta)


## Accumulates frame time and steps the runtime at a fixed 10 Hz. Returns the number of steps done.
func advance(delta: float) -> int:
	if paused or _runtime == null:
		return 0
	_acc += delta
	var steps := 0
	while _acc >= TICK and steps < MAX_STEPS_PER_FRAME:
		_acc -= TICK
		step_once()
		steps += 1
	if steps == MAX_STEPS_PER_FRAME:
		_acc = 0.0
	return steps


func step_once() -> void:
	if _runtime == null:
		return
	_runtime.call("step")
	prev = snapshot
	snapshot = _runtime.call("snapshot")
	snapshot_ready.emit(snapshot, prev)


func start(ship_path: String, seed_in: int) -> bool:
	seed_value = seed_in
	load_errors.clear()
	if not ResourceLoader.exists(RUNTIME_SCRIPT):
		load_errors.append("ship runtime not available")
		push_warning("SimHost: " + load_errors[0])
		return false
	var script: Script = load(RUNTIME_SCRIPT)
	var rt: Variant = script.call("create", ship_path, seed_in)
	if rt == null:
		load_errors.append("ship runtime could not load " + ship_path)
		push_warning("SimHost: " + load_errors[0])
		return false
	var data := _read_json(ship_path)
	var map: Variant = data.get("panels", null)
	if typeof(map) != TYPE_DICTIONARY:
		map = _read_json(PANEL_FILE)
		if map.has("panels") and typeof(map["panels"]) == TYPE_DICTIONARY:
			map = map["panels"]
	var unit: Variant = data.get("power_unit", "")
	use_runtime(rt, map if typeof(map) == TYPE_DICTIONARY else {}, str(unit))
	return true


func use_runtime(runtime: Object, panel_map: Dictionary, unit: String = "") -> void:
	_runtime = runtime
	_unit = unit
	_panels = _normalise(panel_map)
	_acc = 0.0
	prev = {}
	snapshot = runtime.call("snapshot") if runtime != null else {}
	snapshot_ready.emit(snapshot, prev)
	scenario_changed.emit()


func panel_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in PANEL_ORDER:
		if _panels.has(id):
			out.append(id)
	for id: String in _panels:
		if not out.has(id):
			out.append(id)
	return out


func panel_title(id: String) -> String:
	return str(_panels.get(id, {}).get("title", id))


func panel_components(id: String) -> Array[String]:
	var out: Array[String] = []
	out.assign(_panels.get(id, {}).get("components", []))
	return out


func all_ids() -> Array[String]:
	var out: Array[String] = []
	for pid: String in _panels:
		for cid: String in _panels[pid]["components"]:
			if not out.has(cid):
				out.append(cid)
	return out


func power_unit() -> String:
	return _unit


## The only write path for commands. Returns the runtime's result, {} when there is no runtime.
func send(cmd: Dictionary) -> Dictionary:
	if _runtime == null:
		return {"accepted": false, "reason": "no runtime"}
	var result: Variant = _runtime.call("send", cmd)
	return result if typeof(result) == TYPE_DICTIONARY else {}


func scenario_ids() -> Array:
	if _runtime == null:
		return []
	return _runtime.call("scenario_ids")


func start_scenario(id: String) -> void:
	if _runtime == null:
		return
	_runtime.call("start_scenario", id)
	snapshot = _runtime.call("snapshot")
	snapshot_ready.emit(snapshot, prev)
	scenario_changed.emit()


func _normalise(map: Dictionary) -> Dictionary:
	var out := {}
	for pid: String in map:
		var entry: Variant = map[pid]
		var title := pid
		var comps: Array = []
		if typeof(entry) == TYPE_DICTIONARY:
			title = str(entry.get("title", pid))
			comps = entry.get("components", [])
		elif typeof(entry) == TYPE_ARRAY:
			comps = entry
		var ids: Array[String] = []
		for c: Variant in comps:
			ids.append(str(c))
		out[pid] = {"title": title, "components": ids}
	return out


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
