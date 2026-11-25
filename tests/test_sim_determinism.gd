extends GdUnitTestSuite
## Seeded determinism and save/load.

const F := preload("res://tests/fixtures/sim_fixtures.gd")
const N := 300


func _run_log(sim: Sim, from_tick: int, to_tick: int) -> Array:
	var snaps: Array = []
	for t in range(from_tick, to_tick):
		for c in F.random_fault_commands(t):
			sim.submit(c)
		sim.step()
		snaps.append(sim.snapshot())
	return snaps


func test_same_seed_and_commands_give_identical_snapshots_every_tick() -> void:
	var a := _run_log(Sim.new(F.random_fault_grid(), 777), 0, N)
	var b := _run_log(Sim.new(F.random_fault_grid(), 777), 0, N)
	for i in N:
		assert_dict(a[i]).is_equal(b[i])


func test_random_faults_actually_happen() -> void:
	var s := Sim.new(F.random_fault_grid(), 777)
	var faults := 0
	for t in N:
		for c in F.random_fault_commands(t):
			s.submit(c)
		s.step()
		faults += F.events_of(s.snapshot()["events"], "fault").size()
	assert_int(faults).is_greater(0)


func test_different_seed_gives_a_different_run() -> void:
	var a := _run_log(Sim.new(F.random_fault_grid(), 1), 0, N)
	var b := _run_log(Sim.new(F.random_fault_grid(), 2), 0, N)
	var differs := false
	for i in N:
		if a[i]["components"] != b[i]["components"]:
			differs = true
			break
	assert_bool(differs).is_true()


func test_save_and_load_through_json_continues_identically() -> void:
	var full := _run_log(Sim.new(F.random_fault_grid(), 4242), 0, N)
	for split in [1, 37, 150]:
		var first := Sim.new(F.random_fault_grid(), 4242)
		_run_log(first, 0, split)
		first.submit({"type": "set_alert", "value": "red"})  # leave a command queued across the save
		var text := JSON.stringify(first.save())
		var loaded: Sim = Sim.from_save(JSON.parse_string(text))
		assert_object(loaded).is_not_null()
		assert_dict(F.canon(loaded.snapshot())).is_equal(F.canon(first.snapshot()))
		var rest_loaded := _run_log(loaded, split, N)
		var ref := Sim.new(F.random_fault_grid(), 4242)
		_run_log(ref, 0, split)
		ref.submit({"type": "set_alert", "value": "red"})
		var rest_ref := _run_log(ref, split, N)
		assert_int(rest_loaded.size()).is_equal(rest_ref.size())
		for i in rest_ref.size():
			assert_dict(F.canon(rest_loaded[i])).is_equal(F.canon(rest_ref[i]))
	assert_int(full.size()).is_equal(N)


func test_save_without_json_also_round_trips() -> void:
	var a := Sim.new(F.random_fault_grid(), 9)
	_run_log(a, 0, 50)
	var b: Sim = Sim.from_save(a.save())
	var ra := _run_log(a, 50, 120)
	var rb := _run_log(b, 50, 120)
	for i in ra.size():
		assert_dict(ra[i]).is_equal(rb[i])


func test_save_keeps_reactor_countdown() -> void:
	var s := Sim.new(F.reactor_grid(250.0, {"breach_ticks": 30}), 1)
	for i in 400:
		s.step()
		if s.snapshot()["components"]["core"]["state"] == "containment_failing":
			break
	s.step()
	s.step()
	var loaded: Sim = Sim.from_save(JSON.parse_string(JSON.stringify(s.save())))
	assert_dict(F.canon(loaded.snapshot())).is_equal(F.canon(s.snapshot()))
	F.run(loaded, 40)
	F.run(s, 40)
	assert_str(loaded.snapshot()["components"]["core"]["state"]).is_equal("breach")
	assert_dict(F.canon(loaded.snapshot())).is_equal(F.canon(s.snapshot()))
