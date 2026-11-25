extends GdUnitTestSuite
## Power solver: priority shedding, conduit cut and reroute, loss, stores.

const F := preload("res://tests/fixtures/sim_fixtures.gd")


func _p(s: Sim, id: String) -> float:
	return s.snapshot()["components"][id]["power"]


func test_shortage_sheds_lowest_priority_first_and_higher_stay_fully_served() -> void:
	var s := Sim.new(F.star_grid(), 1)
	s.step()
	assert_float(_p(s, "c_hi")).is_equal_approx(40.0, 0.001)
	assert_float(_p(s, "c_mid")).is_equal_approx(40.0, 0.001)
	assert_float(_p(s, "c_lo")).is_equal_approx(20.0, 0.001)  # partial service
	assert_str(s.snapshot()["components"]["c_lo"]["state"]).is_equal("partial")
	assert_str(s.snapshot()["components"]["c_hi"]["state"]).is_equal("ok")
	# deeper shortage: lowest fully shed, middle partial, highest still full
	s.submit({"type": "set_output", "target": "src", "value": 50.0})
	s.step()
	assert_float(_p(s, "c_hi")).is_equal_approx(40.0, 0.001)
	assert_float(_p(s, "c_mid")).is_equal_approx(10.0, 0.001)
	assert_float(_p(s, "c_lo")).is_equal_approx(0.0, 0.001)
	assert_str(s.snapshot()["components"]["c_lo"]["state"]).is_equal("shed")


func test_raising_supply_restores_service_and_emits_one_event_per_change() -> void:
	var s := Sim.new(F.star_grid(), 1)
	s.submit({"type": "set_output", "target": "src", "value": 50.0})
	var events: Array = F.run(s, 5)
	assert_int(F.events_of(events, "shed", "c_lo").size()).is_equal(1)  # once, not every tick
	s.submit({"type": "set_output", "target": "src", "value": 200.0})
	events = F.run(s, 5)
	assert_float(_p(s, "c_lo")).is_equal_approx(40.0, 0.001)
	assert_str(s.snapshot()["components"]["c_lo"]["state"]).is_equal("ok")
	assert_int(F.events_of(events, "restored", "c_lo").size()).is_equal(1)


func test_allocation_scale_limits_a_consumer() -> void:
	var s := Sim.new(F.star_grid(), 1)
	s.submit({"type": "set_allocation", "target": "c_hi", "value": 0.5})
	s.step()
	assert_float(_p(s, "c_hi")).is_equal_approx(20.0, 0.001)
	assert_float(_p(s, "c_lo")).is_equal_approx(40.0, 0.001)


func test_conduit_loss_reduces_delivered_power() -> void:
	var data := {
		"producers": [{"id": "src", "max_output": 100.0}],
		"conduits": [{"id": "k", "from": "src", "to": "load", "capacity": 100.0, "loss": 0.1}],
		"consumers": [{"id": "load", "demand": 50.0, "priority": 1}],
	}
	var s := Sim.new(data, 1)
	s.step()
	var snap := s.snapshot()
	assert_float(snap["components"]["load"]["power"]).is_equal_approx(50.0, 0.001)
	assert_float(snap["components"]["k"]["power"]).is_equal_approx(50.0 / 0.9, 0.001)  # input side
	assert_float(snap["components"]["src"]["power"]).is_equal_approx(50.0 / 0.9, 0.001)


func test_conduit_capacity_limits_delivery() -> void:
	var data := F.parallel_grid(80.0)
	var s := Sim.new(data, 1)
	s.step()
	assert_float(_p(s, "load")).is_equal_approx(80.0, 0.001)  # 50 + 30 over two paths
	s.submit({"type": "cut_conduit", "target": "path_a"})
	s.step()
	assert_float(_p(s, "load")).is_equal_approx(50.0, 0.001)  # one path left, capacity 50
	assert_str(s.snapshot()["components"]["load"]["state"]).is_equal("partial")


func test_conduit_cut_reroutes_over_remaining_path() -> void:
	var s := Sim.new(F.parallel_grid(40.0), 1)
	s.step()
	assert_float(_p(s, "load")).is_equal_approx(40.0, 0.001)
	s.submit({"type": "cut_conduit", "target": "path_a"})
	var events: Array = F.run(s, 3)
	assert_float(_p(s, "load")).is_equal_approx(40.0, 0.001)
	assert_str(s.snapshot()["components"]["load"]["state"]).is_equal("ok")
	assert_bool(s.snapshot()["components"]["path_a"]["cut"]).is_true()
	assert_float(s.snapshot()["components"]["path_a"]["power"]).is_equal_approx(0.0, 0.001)
	assert_float(s.snapshot()["components"]["path_b"]["power"]).is_equal_approx(40.0, 0.001)
	assert_int(F.events_of(events, "unpowered").size()).is_equal(0)


func test_cutting_every_path_unpowers_then_repair_restores() -> void:
	var s := Sim.new(F.parallel_grid(40.0), 1)
	s.step()
	s.submit({"type": "cut_conduit", "target": "path_a"})
	s.submit({"type": "cut_conduit", "target": "path_b"})
	var events: Array = F.run(s, 4)
	assert_float(_p(s, "load")).is_equal_approx(0.0, 0.001)
	assert_str(s.snapshot()["components"]["load"]["state"]).is_equal("unpowered")
	assert_int(F.events_of(events, "unpowered", "load").size()).is_equal(1)  # once, not every tick
	s.submit({"type": "repair", "target": "path_b"})
	events = F.run(s, 2)
	assert_float(_p(s, "load")).is_equal_approx(40.0, 0.001)
	assert_int(F.events_of(events, "restored", "load").size()).is_equal(1)
	assert_bool(s.snapshot()["components"]["path_b"]["cut"]).is_false()


func test_destroyed_conduit_is_cut_automatically() -> void:
	var s := Sim.new(F.parallel_grid(40.0), 1)
	s.submit({"type": "damage", "target": "path_a", "amount": 100.0})
	s.step()
	var c: Dictionary = s.snapshot()["components"]["path_a"]
	assert_float(c["integrity"]).is_equal_approx(0.0, 0.001)
	assert_bool(c["cut"]).is_true()
	s.submit({"type": "repair", "target": "path_a"})
	s.step()
	assert_float(s.snapshot()["components"]["path_a"]["integrity"]).is_equal_approx(100.0, 0.001)
	assert_bool(s.snapshot()["components"]["path_a"]["cut"]).is_false()


func test_store_discharges_to_cover_shortage_and_recharges_from_surplus() -> void:
	var data := {
		"producers": [{"id": "src", "max_output": 50.0}],
		"stores": [{"id": "bank", "capacity": 100.0, "charge": 50.0, "max_charge": 20.0, "max_discharge": 20.0}],
		"conduits": [
			{"id": "k1", "from": "src", "to": "hub", "capacity": 100.0},
			{"id": "k2", "from": "bank", "to": "hub", "capacity": 100.0},
			{"id": "k3", "from": "hub", "to": "load", "capacity": 100.0},
		],
		"consumers": [{"id": "load", "demand": 60.0, "priority": 1}],
	}
	data["junctions"] = [{"id": "hub"}]
	var s := Sim.new(data, 1)
	s.step()
	assert_float(_p(s, "load")).is_equal_approx(60.0, 0.001)
	assert_float(_p(s, "bank")).is_equal_approx(10.0, 0.001)  # discharging 10
	assert_float(s.snapshot()["components"]["bank"]["charge"]).is_equal_approx(50.0 - 10.0 * 0.1, 0.001)
	s.submit({"type": "set_demand", "target": "load", "value": 30.0})
	s.step()
	assert_float(_p(s, "bank")).is_equal_approx(-20.0, 0.001)  # charging at max rate from surplus
	assert_float(s.snapshot()["components"]["bank"]["charge"]).is_greater(49.0)
