extends GdUnitTestSuite
## The generic add_heat command of the sim core (needed by external heat sources and sinks such as coolant).

const F := preload("res://tests/fixtures/sim_fixtures.gd")


func test_add_heat_raises_temperature_and_negative_amounts_cool_but_stop_at_ambient() -> void:
	var s := Sim.new(F.star_grid(), 1)
	s.step()
	var t0: float = s.snapshot()["components"]["src"]["temp"]
	s.submit({"type": "add_heat", "target": "src", "amount": 30.0})
	s.step()
	var t1: float = s.snapshot()["components"]["src"]["temp"]
	assert_float(t1).is_greater(t0 + 20.0)
	s.submit({"type": "add_heat", "target": "src", "amount": -1000.0})
	s.step()
	assert_float(s.snapshot()["components"]["src"]["temp"]).is_equal_approx(20.0, 0.001)  # never below ambient


func test_add_heat_rejects_bad_input() -> void:
	var s := Sim.new(F.star_grid(), 1)
	s.submit({"type": "add_heat", "target": "nope", "amount": 1.0})
	s.submit({"type": "add_heat", "target": "src", "amount": "hot"})
	s.submit({"type": "add_heat", "target": "src", "amount": INF})
	s.submit({"type": "add_heat", "target": "src"})
	s.step()
	assert_int(F.events_of(s.snapshot()["events"], "rejected").size()).is_equal(4)
	assert_float(s.snapshot()["components"]["src"]["temp"]).is_equal_approx(20.0, 0.001)


func test_add_heat_on_a_conduit_and_overheating_damages_it() -> void:
	var s := Sim.new(F.star_grid(), 1)
	for i in 3:
		s.submit({"type": "add_heat", "target": "k_hi", "amount": 500.0})
		s.step()
	assert_float(s.snapshot()["components"]["k_hi"]["integrity"]).is_less(100.0)
