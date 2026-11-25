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
