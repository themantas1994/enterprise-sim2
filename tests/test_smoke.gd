extends GdUnitTestSuite


func test_trivial() -> void:
	assert_int(1 + 1).is_equal(2)


func test_sim_same_seed_same_snapshot() -> void:
	var a := Sim.new({}, 42)
	var b := Sim.new({}, 42)
	for i in 5:
		a.submit({"type": "noop"})
		b.submit({"type": "noop"})
		a.step()
		b.step()
	assert_int(a.snapshot()["tick"]).is_equal(5)
	assert_dict(a.snapshot()).is_equal(b.snapshot())


func test_sim_snapshot_is_a_copy() -> void:
	var s := Sim.new({}, 1)
	var snap := s.snapshot()
	s.step()
	assert_int(snap["tick"]).is_equal(0)
