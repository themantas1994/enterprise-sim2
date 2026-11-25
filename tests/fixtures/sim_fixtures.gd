extends RefCounted
## PLACEHOLDER values invented for tests; not ship data.
## Small generic grids and helpers used by the sim test suites. Every function returns a fresh Dictionary.


## One producer feeding three consumers of priority 1, 2, 3 (lower number = more important).
## Supply setting 100 (hard maximum 300), total demand 120.
static func star_grid() -> Dictionary:
	return {
		"producers": [{"id": "src", "max_output": 300.0, "output": 100.0}],
		"conduits": [
			{"id": "k_hi", "from": "src", "to": "c_hi", "capacity": 100.0},
			{"id": "k_mid", "from": "src", "to": "c_mid", "capacity": 100.0},
			{"id": "k_lo", "from": "src", "to": "c_lo", "capacity": 100.0},
		],
		"consumers": [
			{"id": "c_lo", "demand": 40.0, "priority": 3},
			{"id": "c_hi", "demand": 40.0, "priority": 1},
			{"id": "c_mid", "demand": 40.0, "priority": 2},
		],
	}


## One producer, one consumer, two parallel conduits (capacity 50 each).
static func parallel_grid(demand: float = 40.0) -> Dictionary:
	return {
		"producers": [{"id": "src", "max_output": 200.0}],
		"conduits": [
			{"id": "path_a", "from": "src", "to": "load", "capacity": 50.0},
			{"id": "path_b", "from": "src", "to": "load", "capacity": 50.0},
		],
		"consumers": [{"id": "load", "demand": demand, "priority": 1}],
	}


## A reactor (starts online) feeding one consumer. Rated 100, physical maximum 300.
## `overrides` is merged into the reactor definition; `demand` is the consumer demand.
static func reactor_grid(demand: float = 250.0, overrides: Dictionary = {}) -> Dictionary:
	var reactor := {
		"id": "core", "reactor": true, "state": "online",
		"rated": 100.0, "max_output": 300.0,
		"breach_ticks": 5, "startup_ticks": 3,
	}
	reactor.merge(overrides, true)
	return {
		"producers": [reactor],
		"conduits": [{"id": "feed", "from": "core", "to": "load", "capacity": 1000.0}],
		"consumers": [{"id": "load", "demand": demand, "priority": 1}],
	}


## Two reactors (A online, B online) and a priority-ordered pair of consumers; used for ejection with shedding.
## Each reactor has rated 100 and maximum 100, so total supply is 200 against demand 160.
static func twin_reactor_grid() -> Dictionary:
	return {
		"producers": [
			{"id": "core_a", "reactor": true, "state": "online", "rated": 100.0, "max_output": 100.0, "breach_ticks": 5},
			{"id": "core_b", "reactor": true, "state": "online", "rated": 100.0, "max_output": 100.0, "breach_ticks": 5},
		],
		"conduits": [
			{"id": "a_bus", "from": "core_a", "to": "bus", "capacity": 500.0},
			{"id": "b_bus", "from": "core_b", "to": "bus", "capacity": 500.0},
			{"id": "bus_hi", "from": "bus", "to": "c_hi", "capacity": 500.0},
			{"id": "bus_lo", "from": "bus", "to": "c_lo", "capacity": 500.0},
		],
		"junctions": [{"id": "bus"}],
		"consumers": [
			{"id": "c_hi", "demand": 100.0, "priority": 1},
			{"id": "c_lo", "demand": 60.0, "priority": 2},
		],
	}


## A larger grid with a reactor, a store, a spare conduit and random faults on conduits (seed dependent).
static func random_fault_grid() -> Dictionary:
	return {
		"alert": "green", "mode": "normal",
		"producers": [
			{"id": "core", "reactor": true, "state": "online", "rated": 100.0, "max_output": 140.0, "breach_ticks": 8},
			{"id": "aux", "max_output": 30.0},
		],
		"junctions": [{"id": "hub"}],
		"stores": [{"id": "bank", "capacity": 500.0, "charge": 200.0, "max_charge": 20.0, "max_discharge": 20.0}],
		"conduits": [
			{"id": "k1", "from": "core", "to": "hub", "capacity": 90.0, "loss": 0.02, "fault_chance": 0.05, "fault_damage": 40.0},
			{"id": "k2", "from": "core", "to": "hub", "capacity": 90.0, "loss": 0.02, "fault_chance": 0.05, "fault_damage": 40.0},
			{"id": "k3", "from": "aux", "to": "hub", "capacity": 40.0, "fault_chance": 0.03, "fault_damage": 60.0},
			{"id": "k4", "from": "hub", "to": "bank", "capacity": 40.0},
			{"id": "k5", "from": "hub", "to": "c1", "capacity": 80.0},
			{"id": "k6", "from": "hub", "to": "c2", "capacity": 80.0},
		],
		"consumers": [
			{"id": "c1", "demand": 70.0, "priority": 1},
			{"id": "c2", "demand": 90.0, "priority": 2},
		],
	}


## Scripted command log for random_fault_grid(): commands to submit before the step that computes `tick`.
static func random_fault_commands(tick: int) -> Array:
	var out: Array = []
	if tick % 25 == 5:
		out.append({"type": "set_demand", "target": "c2", "value": 110.0 if (floori(tick / 25.0)) % 2 == 0 else 60.0})
	if tick % 40 == 10:
		out.append({"type": "repair", "target": "k1"})
		out.append({"type": "repair", "target": "k2"})
		out.append({"type": "repair", "target": "k3"})
	if tick == 60:
		out.append({"type": "set_alert", "value": "yellow"})
	if tick == 90:
		out.append({"type": "set_mode", "value": "combat"})
	if tick % 70 == 33:
		out.append({"type": "no_such_command"})
	return out


## Step `n` times and return every event emitted, in order.
static func run(sim: Sim, n: int) -> Array:
	var all: Array = []
	for i in n:
		sim.step()
		all.append_array(sim.snapshot()["events"])
	return all


## Events of a type (and optionally for an id) from a list.
static func events_of(events: Array, type: String, id: String = "") -> Array:
	var out: Array = []
	for e in events:
		if e.get("type", "") == type and (id == "" or e.get("id", "") == id):
			out.append(e)
	return out


## Canonical form for comparing a snapshot that went through JSON (ints become floats there).
static func canon(d: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(d))
