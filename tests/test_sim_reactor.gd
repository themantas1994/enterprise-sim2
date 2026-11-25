extends GdUnitTestSuite
## Reactor state machine: startup, overload, containment failing, breach, recovery, ejection.

const F := preload("res://tests/fixtures/sim_fixtures.gd")


func _state(s: Sim, id: String = "core") -> String:
	return s.snapshot()["components"][id]["state"]


func _transitions(events: Array, id: String = "core") -> Array:
	var out: Array = []
	for e in F.events_of(events, "reactor_state", id):
		out.append(e["to"])
	return out


func test_startup_standby_online_sequence() -> void:
	var s := Sim.new(F.reactor_grid(50.0, {"state": "cold"}), 1)
	assert_str(_state(s)).is_equal("cold")
	s.submit({"type": "reactor_online", "target": "core"})  # not allowed from cold
	var ev: Array = F.run(s, 1)
	assert_int(F.events_of(ev, "rejected").size()).is_equal(1)
	s.submit({"type": "reactor_start", "target": "core"})
	ev = F.run(s, 1)
	assert_str(_state(s)).is_equal("startup")
	var start_tick: int = F.events_of(ev, "reactor_state", "core")[0]["tick"]
	ev.append_array(F.run(s, 1))
	assert_str(_state(s)).is_equal("startup")  # startup_ticks = 3: still not standby after 2 steps
	ev.append_array(F.run(s, 1))
	assert_str(_state(s)).is_equal("standby")  # standby exactly on the 3rd step
	assert_int(F.events_of(ev, "reactor_state", "core")[1]["tick"]).is_equal(start_tick + 2)
	assert_float(s.snapshot()["components"]["load"]["power"]).is_equal_approx(0.0, 0.001)
	s.submit({"type": "reactor_online", "target": "core"})
	ev.append_array(F.run(s, 2))
	assert_str(_state(s)).is_equal("online")
	assert_float(s.snapshot()["components"]["load"]["power"]).is_equal_approx(50.0, 0.001)
	assert_array(_transitions(ev)).is_equal(["startup", "standby", "online"])
	s.submit({"type": "reactor_shutdown", "target": "core"})
	s.step()
	assert_str(_state(s)).is_equal("cold")


func test_sustained_overload_goes_to_containment_failing_then_breach_after_countdown() -> void:
	var s := Sim.new(F.reactor_grid(250.0), 1)
	var events: Array = F.run(s, 120)
	assert_array(_transitions(events)).is_equal(["overload", "containment_failing", "breach"])
	var cf: Dictionary = F.events_of(events, "reactor_state", "core")[1]
	var br: Dictionary = F.events_of(events, "reactor_state", "core")[2]
	assert_int(int(br["tick"]) - int(cf["tick"])).is_equal(5)  # breach_ticks
	assert_str(_state(s)).is_equal("breach")
	assert_float(s.snapshot()["components"]["core"]["power"]).is_equal_approx(0.0, 0.001)
	assert_float(s.snapshot()["components"]["load"]["power"]).is_equal_approx(0.0, 0.001)
	assert_int(F.events_of(events, "breach", "core").size()).is_equal(1)


func test_breach_damages_connected_components_exactly_once() -> void:
	var s := Sim.new(F.reactor_grid(250.0, {"breach_damage": 70.0}), 1)
	var events: Array = F.run(s, 120)
	assert_int(F.events_of(events, "breach", "core").size()).is_equal(1)
	var comps: Dictionary = s.snapshot()["components"]
	assert_float(comps["feed"]["integrity"]).is_equal_approx(30.0, 0.001)
	assert_float(comps["load"]["integrity"]).is_equal_approx(30.0, 0.001)
	F.run(s, 30)
	comps = s.snapshot()["components"]
	assert_float(comps["feed"]["integrity"]).is_equal_approx(30.0, 0.001)  # twice would leave 0
	assert_float(comps["load"]["integrity"]).is_equal_approx(30.0, 0.001)


func test_breach_happens_exactly_breach_ticks_after_entry_not_one_earlier() -> void:
	var s := Sim.new(F.reactor_grid(250.0, {"breach_ticks": 7}), 1)
	for i in 200:
		s.step()
		if _state(s) == "containment_failing":
			break
	assert_str(_state(s)).is_equal("containment_failing")
	for i in 6:
		s.step()
		assert_str(_state(s)).is_equal("containment_failing")
	s.step()
	assert_str(_state(s)).is_equal("breach")


func test_breach_reaching_a_far_end_junction_cuts_downstream_supply() -> void:
	var data := {
		"producers": [
			{"id": "core", "reactor": true, "state": "containment_failing", "rated": 100.0, "max_output": 100.0, "breach_ticks": 2, "breach_damage": 100.0},
			{"id": "other", "max_output": 100.0},
		],
		"junctions": [{"id": "node"}],
		"conduits": [
			{"id": "c1", "from": "core", "to": "node", "capacity": 500.0},
			{"id": "c2", "from": "other", "to": "node", "capacity": 500.0},
			{"id": "c3", "from": "node", "to": "load", "capacity": 500.0},
		],
		"consumers": [{"id": "load", "demand": 50.0, "priority": 1}],
	}
	var s := Sim.new(data, 1)
	s.step()
	assert_float(s.snapshot()["components"]["load"]["power"]).is_equal_approx(50.0, 0.001)
	F.run(s, 5)
	var comps: Dictionary = s.snapshot()["components"]
	assert_str(comps["core"]["state"]).is_equal("breach")
	assert_float(comps["node"]["integrity"]).is_equal_approx(0.0, 0.001)
	assert_float(comps["load"]["power"]).is_equal_approx(0.0, 0.001)
	assert_str(comps["load"]["state"]).is_equal("unpowered")


func test_ejected_reactor_in_the_middle_of_a_chain_passes_no_power() -> void:
	var data := {
		"producers": [
			{"id": "src", "max_output": 100.0},
			{"id": "mid", "reactor": true, "state": "ejected", "rated": 100.0, "max_output": 100.0},
		],
		"conduits": [
			{"id": "k1", "from": "src", "to": "mid", "capacity": 500.0},
			{"id": "k2", "from": "mid", "to": "load", "capacity": 500.0},
		],
		"consumers": [{"id": "load", "demand": 50.0, "priority": 1}],
	}
	var s := Sim.new(data, 1)
	s.step()
	assert_float(s.snapshot()["components"]["load"]["power"]).is_equal_approx(0.0, 0.001)
	assert_str(s.snapshot()["components"]["load"]["state"]).is_equal("unpowered")
	data["producers"][1]["state"] = "breach"
	var b := Sim.new(data, 1)
	b.step()
	assert_float(b.snapshot()["components"]["load"]["power"]).is_equal_approx(0.0, 0.001)


func test_reducing_load_in_time_recovers_overload_to_online() -> void:
	var s := Sim.new(F.reactor_grid(250.0), 1)
	var events: Array = []
	for i in 100:
		events.append_array(F.run(s, 1))
		if _state(s) == "overload" and s.snapshot()["components"]["core"]["temp"] > 150.0:
			break
	assert_str(_state(s)).is_equal("overload")
	assert_float(s.snapshot()["components"]["core"]["temp"]).is_greater(150.0)
	s.submit({"type": "set_demand", "target": "load", "value": 50.0})
	events.append_array(F.run(s, 80))
	assert_str(_state(s)).is_equal("online")
	assert_array(_transitions(events)).is_equal(["overload", "online"])
	assert_float(s.snapshot()["components"]["load"]["power"]).is_equal_approx(50.0, 0.001)


func test_eject_during_containment_failing_ends_ejected_and_never_breaches() -> void:
	var s := Sim.new(F.reactor_grid(250.0), 1)
	var events: Array = []
	for i in 200:
		events.append_array(F.run(s, 1))
		if _state(s) == "containment_failing":
			break
	assert_str(_state(s)).is_equal("containment_failing")
	s.submit({"type": "reactor_eject", "target": "core"})
	events.append_array(F.run(s, 100))
	assert_str(_state(s)).is_equal("ejected")
	assert_array(_transitions(events)).is_equal(["overload", "containment_failing", "ejected"])
	assert_int(F.events_of(events, "breach").size()).is_equal(0)
	assert_float(s.snapshot()["components"]["core"]["power"]).is_equal_approx(0.0, 0.001)
	assert_float(s.snapshot()["components"]["feed"]["integrity"]).is_equal_approx(100.0, 0.001)


func test_ejected_source_is_removed_from_the_grid_and_lowest_priority_sheds() -> void:
	var s := Sim.new(F.twin_reactor_grid(), 1)
	s.step()
	assert_float(s.snapshot()["components"]["c_hi"]["power"]).is_equal_approx(100.0, 0.001)
	assert_float(s.snapshot()["components"]["c_lo"]["power"]).is_equal_approx(60.0, 0.001)
	s.submit({"type": "reactor_eject", "target": "core_a"})
	var events: Array = F.run(s, 3)
	var comps: Dictionary = s.snapshot()["components"]
	assert_str(comps["core_a"]["state"]).is_equal("ejected")
	assert_float(comps["core_a"]["power"]).is_equal_approx(0.0, 0.001)
	assert_float(comps["c_hi"]["power"]).is_equal_approx(100.0, 0.001)  # higher priority stays whole
	assert_float(comps["c_lo"]["power"]).is_equal_approx(0.0, 0.001)
	assert_str(comps["c_lo"]["state"]).is_equal("shed")
	assert_int(F.events_of(events, "shed", "c_lo").size()).is_equal(1)


func test_eject_from_a_disallowed_state_is_rejected() -> void:
	var s := Sim.new(F.reactor_grid(50.0, {"state": "standby"}), 1)
	s.submit({"type": "reactor_eject", "target": "core"})
	var ev: Array = F.run(s, 1)
	assert_int(F.events_of(ev, "rejected").size()).is_equal(1)
	assert_str(_state(s)).is_equal("standby")
	var cold := Sim.new(F.reactor_grid(50.0, {"state": "cold"}), 1)
	cold.submit({"type": "reactor_eject", "target": "core"})
	assert_int(F.events_of(F.run(cold, 1), "rejected").size()).is_equal(1)
	assert_str(_state(cold)).is_equal("cold")
	# a second eject after ejection is also rejected
	var on := Sim.new(F.reactor_grid(50.0), 1)
	on.submit({"type": "reactor_eject", "target": "core"})
	on.step()
	assert_str(_state(on)).is_equal("ejected")
	on.submit({"type": "reactor_eject", "target": "core"})
	assert_int(F.events_of(F.run(on, 1), "rejected").size()).is_equal(1)
