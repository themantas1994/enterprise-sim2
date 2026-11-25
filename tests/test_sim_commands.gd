extends GdUnitTestSuite
## Command validation, snapshot isolation, ship data validation, alert and mode.

const F := preload("res://tests/fixtures/sim_fixtures.gd")


func test_invalid_and_unknown_commands_are_rejected_as_events_without_crashing() -> void:
	var s := Sim.new(F.star_grid(), 1)
	var bad: Array = [
		{},
		{"type": 5},
		{"type": "no_such_command"},
		{"type": "set_demand"},
		{"type": "set_demand", "target": "nope", "value": 1.0},
		{"type": "set_demand", "target": "c_hi", "value": "high"},
		{"type": "set_demand", "target": "c_hi", "value": -3.0},
		{"type": "set_allocation", "target": "c_hi", "value": 2.0},
		{"type": "set_allocation", "target": "src", "value": 0.5},
		{"type": "cut_conduit", "target": "c_hi"},
		{"type": "damage", "target": "k_hi", "amount": -1.0},
		{"type": "reactor_start", "target": "src"},
		{"type": "set_alert", "value": 3},
		{"type": "set_mode"},
		{"type": "set_output", "target": "c_hi", "value": 1.0},
	]
	for c in bad:
		s.submit(c)
	s.step()
	var ev: Array = s.snapshot()["events"]
	assert_int(F.events_of(ev, "rejected").size()).is_equal(bad.size())
	for e in F.events_of(ev, "rejected"):
		assert_bool(e.has("reason")).is_true()
	assert_int(s.snapshot()["tick"]).is_equal(1)
	assert_float(s.snapshot()["components"]["c_hi"]["power"]).is_equal_approx(40.0, 0.001)


func test_commands_apply_in_arrival_order() -> void:
	var s := Sim.new(F.star_grid(), 1)
	s.submit({"type": "set_demand", "target": "c_hi", "value": 10.0})
	s.submit({"type": "set_demand", "target": "c_hi", "value": 25.0})
	s.step()
	assert_float(s.snapshot()["components"]["c_hi"]["power"]).is_equal_approx(25.0, 0.001)


func test_snapshot_is_a_deep_copy() -> void:
	var s := Sim.new(F.star_grid(), 1)
	s.step()
	var snap := s.snapshot()
	snap["components"]["c_hi"]["power"] = 9999.0
	snap["components"]["c_hi"]["state"] = "tampered"
	snap["components"].erase("src")
	snap["events"].append({"type": "fake"})
	snap["tick"] = 77
	var fresh := s.snapshot()
	assert_float(fresh["components"]["c_hi"]["power"]).is_equal_approx(40.0, 0.001)
	assert_str(fresh["components"]["c_hi"]["state"]).is_equal("ok")
	assert_bool(fresh["components"].has("src")).is_true()
	assert_int(fresh["tick"]).is_equal(1)
	assert_int(F.events_of(fresh["events"], "fake").size()).is_equal(0)


func test_submitted_command_is_copied() -> void:
	var s := Sim.new(F.star_grid(), 1)
	var cmd := {"type": "set_demand", "target": "c_hi", "value": 5.0}
	s.submit(cmd)
	cmd["value"] = 40.0
	s.step()
	assert_float(s.snapshot()["components"]["c_hi"]["power"]).is_equal_approx(5.0, 0.001)


func test_alert_and_mode_are_stored_and_shown() -> void:
	var s := Sim.new(F.star_grid(), 1)
	var first_snap := s.snapshot()
	assert_str(first_snap["alert"]).is_not_empty()
	assert_str(first_snap["mode"]).is_not_empty()
	s.submit({"type": "set_alert", "value": "red"})
	s.submit({"type": "set_mode", "value": "custom"})
	s.step()
	assert_str(s.snapshot()["alert"]).is_equal("red")
	assert_str(s.snapshot()["mode"]).is_equal("custom")


func test_invalid_ship_data_is_reported_not_thrown() -> void:
	var data := {
		"producers": [{"id": "a", "max_output": 10.0}, {"id": "a", "max_output": 5.0}],
		"conduits": [{"id": "k", "from": "a", "to": "ghost", "capacity": 10.0}],
		"consumers": [{"id": "c", "demand": -1.0, "priority": 1}, {"demand": 1.0}],
	}
	var s := Sim.new(data, 1)
	assert_bool(s.valid).is_false()
	assert_int(s.errors.size()).is_greater(2)
	s.step()  # must not crash
	var ev: Array = s.snapshot()["events"]
	assert_int(F.events_of(ev, "rejected").size()).is_greater(0)
	assert_bool(Sim.new(F.star_grid(), 1).valid).is_true()
	assert_bool(Sim.new({}, 1).valid).is_true()


func test_loader_rejects_a_malformed_save_without_crashing() -> void:
	assert_object(Sim.from_save({})).is_null()
	assert_object(Sim.from_save({"version": 99})).is_null()


func test_heat_over_threshold_lowers_efficiency_and_integrity() -> void:
	var data := {
		"producers": [{"id": "src", "max_output": 300.0, "rated": 100.0}],
		"conduits": [{"id": "k", "from": "src", "to": "load", "capacity": 500.0}],
		"consumers": [{"id": "load", "demand": 250.0, "priority": 1}],
	}
	var s := Sim.new(data, 1)
	F.run(s, 60)
	var c: Dictionary = s.snapshot()["components"]["src"]
	assert_float(c["temp"]).is_greater(100.0)
	assert_float(c["efficiency"]).is_less(1.0)
	assert_float(c["integrity"]).is_less(100.0)
	# no load: cools back toward ambient
	s.submit({"type": "set_demand", "target": "load", "value": 0.0})
	F.run(s, 300)
	assert_float(s.snapshot()["components"]["src"]["temp"]).is_less(25.0)


func test_set_priority_set_demand_set_output_reject_out_of_range_values() -> void:
	var bad: Array = [
		{"type": "set_priority", "target": "c_hi", "value": 1.5},
		{"type": "set_priority", "target": "c_hi", "value": 1.0e12},
		{"type": "set_priority", "target": "c_hi", "value": -1.0e12},
		{"type": "set_priority", "target": "c_hi", "value": INF},
		{"type": "set_priority", "target": "c_hi", "value": NAN},
		{"type": "set_demand", "target": "c_hi", "value": 2.0e9},
		{"type": "set_demand", "target": "c_hi", "value": INF},
		{"type": "set_demand", "target": "c_hi", "value": NAN},
		{"type": "set_output", "target": "src", "value": INF},
		{"type": "set_output", "target": "src", "value": NAN},
		{"type": "set_output", "target": "src", "value": 1.0e12},
	]
	for c in bad:
		var s := Sim.new(F.star_grid(), 1)
		s.submit(c)
		s.step()
		assert_int(F.events_of(s.snapshot()["events"], "rejected").size()).is_equal(1)
		var comps: Dictionary = s.snapshot()["components"]
		assert_int(comps["c_hi"]["priority"]).is_equal(1)
		assert_float(comps["c_hi"]["demand"]).is_equal_approx(40.0, 0.001)
		assert_float(comps["src"]["power"]).is_equal_approx(100.0, 0.001)
	var ok := Sim.new(F.star_grid(), 1)
	ok.submit({"type": "set_priority", "target": "c_hi", "value": 5.0})
	ok.step()
	assert_int(F.events_of(ok.snapshot()["events"], "rejected").size()).is_equal(0)
	assert_int(ok.snapshot()["components"]["c_hi"]["priority"]).is_equal(5)


func test_loader_rejects_wrong_types_instead_of_coercing() -> void:
	var cases: Array = [
		{"producers": [{"id": "r", "max_output": 10.0, "reactor": "yes"}]},
		{"producers": [{"id": "r", "max_output": 10.0, "reactor": 1}]},
		{"producers": [{"id": "p", "max_output": 10.0}], "consumers": [{"id": "c", "demand": 1.0}],
			"conduits": [{"id": "k", "from": 5, "to": "c", "capacity": 1.0}]},
		{"producers": [{"id": "p", "max_output": 10.0}], "consumers": [{"id": "c", "demand": 1.0}],
			"conduits": [{"id": "k", "from": "p", "to": ["c"], "capacity": 1.0}]},
		{"consumers": [{"id": "c", "demand": 1.0, "priority": 1.5}]},
		{"producers": [{"id": "r", "max_output": 10.0, "reactor": true, "breach_ticks": 2.5}]},
	]
	for data in cases:
		var s := Sim.new(data, 1)
		assert_bool(s.valid).is_false()
		assert_int(s.errors.size()).is_greater(0)
	assert_bool(Sim.new({"consumers": [{"id": "c", "demand": 1.0, "priority": 2.0}]}, 1).valid).is_true()


# ---- save validation ----

func _rewrite(save: Dictionary, mutate: Callable) -> Dictionary:
	var state: Dictionary = bytes_to_var(Marshalls.base64_to_raw(save["state"]))
	mutate.call(state)
	var out := save.duplicate(true)
	out["state"] = Marshalls.raw_to_base64(var_to_bytes(state))
	return out


func _good_save() -> Dictionary:
	var s := Sim.new(F.reactor_grid(50.0), 3)
	F.run(s, 5)
	return JSON.parse_string(JSON.stringify(s.save()))


func test_valid_save_still_round_trips() -> void:
	var save := _good_save()
	var loaded: Sim = Sim.from_save(save)
	assert_object(loaded).is_not_null()
	assert_int(loaded.snapshot()["tick"]).is_equal(5)


func test_from_save_returns_null_for_corrupt_or_truncated_blobs() -> void:
	var save := _good_save()
	for blob in ["!!!not base64!!!", "", "AAAA", save["state"].substr(0, int(save["state"].length() / 2))]:
		var bad := save.duplicate(true)
		bad["state"] = blob
		assert_object(Sim.from_save(bad)).is_null()


func test_from_save_returns_null_for_wrong_member_types_and_ranges() -> void:
	var save := _good_save()
	var mutations: Array = [
		func(st: Dictionary) -> void: st["queue"] = 5,
		func(st: Dictionary) -> void: st["queue"] = [5],
		func(st: Dictionary) -> void: st["events"] = "x",
		func(st: Dictionary) -> void: st["alert"] = 5,
		func(st: Dictionary) -> void: st["mode"] = "",
		func(st: Dictionary) -> void: st["comps"] = [],
		func(st: Dictionary) -> void: st["comps"]["core"].erase("temp"),
		func(st: Dictionary) -> void: st["comps"]["core"]["temp"] = "hot",
		func(st: Dictionary) -> void: st["comps"]["core"]["temp"] = INF,
		func(st: Dictionary) -> void: st["comps"]["core"]["integrity"] = NAN,
		func(st: Dictionary) -> void: st["comps"]["core"]["state"] = "bogus",
		func(st: Dictionary) -> void: st["comps"]["load"]["priority"] = 1.5,
		func(st: Dictionary) -> void: st["comps"]["feed"]["from"] = 7,
		func(st: Dictionary) -> void: st["comps"].erase("feed"),
		func(st: Dictionary) -> void: st["order"].append("ghost"),
		func(st: Dictionary) -> void: st["order"][1] = "core",
		func(st: Dictionary) -> void: st["order"] = [],
		func(st: Dictionary) -> void: st["valid"] = "yes",
		func(st: Dictionary) -> void: st["ship"] = 3,
	]
	for m in mutations:
		assert_object(Sim.from_save(_rewrite(save, m))).is_null()


func test_from_save_returns_null_for_bad_header_fields() -> void:
	for patch in [{"tick": 1.0e30}, {"tick": -5}, {"tick": 1.5}, {"tick": "7"}, {"seed": "abc"}, {"seed": 5},
			{"rng_state": "x1"}, {"rng_state": 12}, {"version": 2}, {"state": 5}]:
		var bad := _good_save()
		for k in patch:
			bad[k] = patch[k]
		assert_object(Sim.from_save(bad)).is_null()
