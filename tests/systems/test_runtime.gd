extends GdUnitTestSuite
## ShipRuntime interface (ADR 0002): snapshot shape, command results, determinism, no missing tuning keys.

const H := preload("res://tests/systems/ship_helpers.gd")

var _rts: Array = []


func after_test() -> void:
	for r: ShipRuntime in _rts:
		r.dispose()
	_rts.clear()


func _make(seed_value: int = 1) -> ShipRuntime:
	var rt := H.make(seed_value)
	_rts.append(rt)
	return rt


func test_snapshot_has_core_part_and_ship_entry() -> void:
	var rt := _make()
	H.run(rt, 5)
	var s := rt.snapshot()
	assert_int(s["tick"]).is_equal(5)
	assert_bool(s["components"].has("warp_core")).is_true()
	var ship: Dictionary = s["ship"]
	assert_str(ship["alert"]).is_equal("green")
	assert_str(ship["mode"]).is_equal("cruise")
	assert_dict(ship["scenario"]).is_empty()
	for key: String in ["warp", "fuel", "coolant", "shields", "sif_idf", "propulsion", "modes", "damage_control", "detail", "events"]:
		assert_bool(ship.has(key)).override_failure_message("ship." + key).is_true()


func test_snapshot_is_a_copy() -> void:
	var rt := _make()
	H.run(rt, 3)
	var s := rt.snapshot()
	s["components"]["warp_core"]["integrity"] = 1.0
	s["ship"]["alert"] = "red"
	assert_float(H.comp(rt, "warp_core")["integrity"]).is_equal(100.0)
	assert_str(rt.snapshot()["ship"]["alert"]).is_equal("green")


func test_cruise_ship_runs_stable_and_everything_is_powered() -> void:
	var rt := _make()
	H.run(rt, 100)
	var comps: Dictionary = rt.snapshot()["components"]
	for id: String in ["life_support", "shield_grid", "sif_grid", "idf_grid", "nav_deflector", "computer_core_p1", "antimatter_containment"]:
		assert_str(comps[id]["state"]).override_failure_message(id).is_equal("ok")
	assert_str(comps["warp_core"]["state"]).is_equal("online")
	assert_float(comps["warp_core"]["load"]).is_less(1.0)
	assert_array(rt.missing_tunes).is_empty()


func test_send_results_and_rejections() -> void:
	var rt := _make()
	H.run(rt, 2)
	assert_bool(rt.send({"type": "set_priority", "target": "phaser_array", "value": 7})["accepted"]).is_true()
	var r := rt.send({"type": "set_priority", "target": "no_such_id", "value": 7})
	assert_bool(r["accepted"]).is_false()
	assert_str(r["reason"]).is_not_empty()
	assert_bool(rt.send({"type": "set_priority", "target": "warp_core", "value": 1})["accepted"]).is_false()  # not a consumer
	assert_bool(rt.send({"type": "bogus"})["accepted"]).is_false()
	assert_bool(rt.send({})["accepted"]).is_false()
	assert_bool(rt.send({"type": "set_demand", "target": "shield_grid", "value": 5})["accepted"]).is_false()  # managed
	assert_bool(rt.send({"type": "set_output", "target": "warp_core", "value": 99999})["accepted"]).is_false()
	assert_bool(rt.send({"type": "set_alert", "value": "purple"})["accepted"]).is_false()
	assert_bool(rt.send({"type": "reactor_online", "target": "warp_core"})["accepted"]).is_false()  # already online
	assert_bool(rt.send({"type": "reactor_eject", "target": "impulse_saucer_1"})["accepted"]).is_false()  # cold


func test_scenario_ids_and_unknown_scenario() -> void:
	var rt := _make()
	assert_array(rt.scenario_ids()).is_equal(["core_breach", "borg_drain", "coolant_leak"])
	assert_bool(rt.start_scenario("nope")).is_false()
	assert_dict(rt.snapshot()["ship"]["scenario"]).is_empty()
	assert_bool(rt.start_scenario("core_breach")).is_true()
	var sc: Dictionary = rt.snapshot()["ship"]["scenario"]
	assert_str(sc["id"]).is_equal("core_breach")
	assert_str(sc["status"]).is_equal("running")
	for k: String in ["title", "reason", "tick", "time_left"]:
		assert_bool(sc.has(k)).is_true()


func _drive(rt: ShipRuntime) -> void:
	for t in 400:
		if t == 10:
			rt.send({"type": "set_alert", "value": "red"})
		if t == 60:
			rt.send({"type": "shield_set", "frequency": 123, "modulation": 456})
		if t == 120:
			rt.send({"type": "damage", "target": "sif_gen_p1", "amount": 100})
		if t == 130:
			rt.send({"type": "assign_team", "team": "dc_team_1", "target": "sif_gen_p1"})
		rt.step()


func test_same_seed_and_commands_give_identical_runs_and_other_seed_borg_differs() -> void:
	var a := _make(5)
	var b := _make(5)
	a.start_scenario("borg_drain")
	b.start_scenario("borg_drain")
	_drive(a)
	_drive(b)
	assert_str(H.fingerprint(a)).is_equal(H.fingerprint(b))
	var c := _make(6)
	c.start_scenario("borg_drain")
	_drive(c)
	assert_str(H.fingerprint(c)).is_not_equal(H.fingerprint(a))
