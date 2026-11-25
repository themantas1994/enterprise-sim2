class_name PowerSolver
extends RefCounted
## Priority power solver. One call per tick; writes power and load into the component dictionaries.
##
## Convention: consumer priority is an integer, LOWER NUMBER = MORE IMPORTANT. Consumers are served in
## ascending (priority, array order); when supply is short the highest numbers are shed first and the
## consumer at the boundary receives partial service.
## Method (greedy, deterministic):
##   1. Producers offer their capacity (output setting * efficiency; reactors only while online or overload).
##      Stores offer min(max_discharge * efficiency, charge / dt) but only as a second tier.
##   2. Each consumer, in priority order, repeatedly takes the nearest (fewest conduits, ties by conduit
##      array order) source with supply left over a path of conduits that still have capacity, first from
##      producers, then from stores. Along a path, conduit i carries delivered / prod(1 - loss) of the
##      conduits from i to the end, which must fit its remaining capacity (capacity * efficiency).
##      Cut or destroyed conduits are never used, so flow reroutes over what is left. The greedy choice is
##      not a global optimum (it can strand capacity on topologies with shared bottlenecks); it is stable
##      and documented, which is what the tests rely on.
##   3. Stores that did not discharge then charge from leftover producer supply, up to max_charge and room.
## Per-component output: power = power drawn from a producer, signed store flow (+ discharge, - charge),
## power entering a conduit, power delivered to a consumer. load = power / rated (0 when rated is 0).
## Nodes with integrity 0, and reactors in breach or ejected, never carry power (not as source, relay or sink).
## A consumer sets reachable = false when no usable conduit path leads to any present source node.

const TOL := 1e-9


static func producer_capacity(c: Dictionary) -> float:
	if c["integrity"] <= 0.0:
		return 0.0
	if c["reactor"] and not ReactorFsm.provides_power(c):
		return 0.0
	return c["output_limit"] * c["efficiency"]


static func _conduit_usable(c: Dictionary) -> bool:
	return not c["cut"] and c["integrity"] > 0.0 and c["capacity"] * c["efficiency"] > TOL


static func _node_ok(comps: Dictionary, id: String) -> bool:
	var n: Dictionary = comps[id]
	if n["integrity"] <= 0.0:
		return false
	return not (n["kind"] == "producer" and n["reactor"] and not ReactorFsm.present(n))


static func solve(comps: Dictionary, order: Array, dt: float) -> void:
	var producers: Dictionary = {}  # id -> remaining capacity
	var stores: Dictionary = {}  # id -> remaining discharge power
	var rem_cap: Dictionary = {}
	var flow_in: Dictionary = {}
	var drawn: Dictionary = {}
	var adj: Dictionary = {}  # node id -> conduit ids (array order)
	var store_ids: Array = []
	var consumer_keys: Array = []
	var conduit_ids: Array = []
	var present: Dictionary = {}  # source node ids that physically exist
	for id: String in order:
		var c: Dictionary = comps[id]
		c["power"] = 0.0
		c["load"] = 0.0
		match c["kind"]:
			"producer":
				drawn[id] = 0.0
				var cap := producer_capacity(c)
				if cap > TOL:
					producers[id] = cap
				if c["integrity"] > 0.0 and (not c["reactor"] or ReactorFsm.present(c)):
					present[id] = true
			"store":
				drawn[id] = 0.0
				store_ids.append(id)
				if c["integrity"] > 0.0:
					present[id] = true
					var d := minf(c["max_discharge"] * c["efficiency"], c["charge"] / dt)
					if d > TOL:
						stores[id] = d
			"conduit":
				flow_in[id] = 0.0
				conduit_ids.append(id)
			"consumer":
				consumer_keys.append([c["priority"], consumer_keys.size(), id])
	# A node whose integrity is 0, or a reactor in breach or ejected, is not part of any path: it cannot be a
	# source, a relay or a sink, so conduits touching it carry nothing.
	for id: String in conduit_ids:
		var c: Dictionary = comps[id]
		if not _conduit_usable(c) or not _node_ok(comps, c["from"]) or not _node_ok(comps, c["to"]):
			continue
		rem_cap[id] = c["capacity"] * c["efficiency"]
		for end: String in ["from", "to"]:
			if not adj.has(c[end]):
				adj[c[end]] = []
			adj[c[end]].append(id)
	consumer_keys.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for key: Array in consumer_keys:
		var c: Dictionary = comps[key[2]]
		var want := 0.0
		if c["integrity"] > 0.0:
			want = c["demand"] * c["allocation"]
		var got := 0.0
		if want > TOL:
			got = _pull(c["id"], want, producers, adj, comps, rem_cap, flow_in, drawn)
			if want - got > TOL:
				got += _pull(c["id"], want - got, stores, adj, comps, rem_cap, flow_in, drawn)
		c["power"] = got
		c["reachable"] = true
		if want - got > TOL:
			c["reachable"] = _reaches_source(c["id"], present, adj, comps)
	for id: String in store_ids:
		var c: Dictionary = comps[id]
		if c["integrity"] <= 0.0:
			continue
		if drawn[id] > 0.0:
			c["power"] = drawn[id]
			c["charge"] = maxf(0.0, c["charge"] - drawn[id] * dt)
			continue
		var room: float = (c["capacity"] - c["charge"]) / dt
		var want := minf(room, c["max_charge"] * c["efficiency"])
		if want > TOL:
			var got := _pull(id, want, producers, adj, comps, rem_cap, flow_in, drawn)
			c["charge"] = minf(c["capacity"], c["charge"] + got * dt)
			c["power"] = -got
	for id: String in order:
		var c: Dictionary = comps[id]
		match c["kind"]:
			"producer":
				c["power"] = drawn[id]
			"conduit":
				c["power"] = flow_in[id]
		if c["kind"] != "consumer" and c["kind"] != "junction" and c["rated"] > TOL:
			c["load"] = absf(c["power"]) / c["rated"]


## Moves up to `need` delivered power to node `start` from the sources in `pool`. Returns the amount delivered.
static func _pull(start: String, need: float, pool: Dictionary, adj: Dictionary, comps: Dictionary, rem_cap: Dictionary, flow_in: Dictionary, drawn: Dictionary) -> float:
	var got := 0.0
	var guard := 0
	while need - got > TOL and guard < 256:
		guard += 1
		var found := _find_path(start, pool, adj, comps, rem_cap)
		if found.is_empty():
			break
		var src: String = found[0]
		var path: Array = found[1]
		var k := path.size()
		var surv: Array[float] = []
		surv.resize(k + 1)
		surv[k] = 1.0
		for i in range(k - 1, -1, -1):
			surv[i] = surv[i + 1] * (1.0 - comps[path[i]]["loss"])
		var d := minf(need - got, pool[src] * surv[0])
		for i in k:
			d = minf(d, rem_cap[path[i]] * surv[i])
		if d <= TOL:
			break
		for i in k:
			var cid: String = path[i]
			var entering := d / surv[i]
			rem_cap[cid] -= entering
			flow_in[cid] += entering
		var draw := d / surv[0]
		pool[src] -= draw
		drawn[src] = drawn.get(src, 0.0) + draw
		got += d
	return got


## Breadth-first search from `start` over conduits with spare capacity to the nearest node in `pool` with supply left.
## Returns [source id, conduit ids in flow order (source to start)] or [].
static func _find_path(start: String, pool: Dictionary, adj: Dictionary, comps: Dictionary, rem_cap: Dictionary) -> Array:
	var via: Dictionary = {start: ""}
	var prev: Dictionary = {}
	var queue: Array[String] = [start]
	var head := 0
	while head < queue.size():
		var n: String = queue[head]
		head += 1
		if n != start and pool.get(n, 0.0) > TOL:
			var path: Array = []
			var cur := n
			while cur != start:
				path.append(via[cur])
				cur = prev[cur]
			return [n, path]
		for cid: String in adj.get(n, []):
			if rem_cap[cid] <= TOL:
				continue
			var cc: Dictionary = comps[cid]
			var other: String = cc["to"] if cc["from"] == n else cc["from"]
			if via.has(other):
				continue
			via[other] = cid
			prev[other] = n
			queue.append(other)
	return []


static func _reaches_source(start: String, present: Dictionary, adj: Dictionary, comps: Dictionary) -> bool:
	var seen: Dictionary = {start: true}
	var queue: Array[String] = [start]
	var head := 0
	while head < queue.size():
		var n: String = queue[head]
		head += 1
		if n != start and present.has(n):
			return true
		for cid: String in adj.get(n, []):
			var cc: Dictionary = comps[cid]
			var other: String = cc["to"] if cc["from"] == n else cc["from"]
			if seen.has(other):
				continue
			seen[other] = true
			queue.append(other)
	return false
