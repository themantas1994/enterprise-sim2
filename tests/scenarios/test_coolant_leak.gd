extends GdUnitTestSuite
## coolant_leak: reduce the load, repair with a team, refill and cool down to win; ignoring it ends in breach.

const H := preload("res://tests/systems/ship_helpers.gd")

var _rt: ShipRuntime


func before_test() -> void:
	_rt = H.make(21)
	assert_bool(_rt.start_scenario("coolant_leak")).is_true()


func after_test() -> void:
	_rt.dispose()


func _sc() -> Dictionary:
	return _rt.snapshot()["ship"]["scenario"]


func test_starts_at_red_alert_with_the_core_loaded_and_the_loop_leaking() -> void:
	H.run(_rt, 20)
	var s: Dictionary = _rt.snapshot()
	assert_str(s["ship"]["alert"]).is_equal("red")
	assert_float(s["components"]["warp_core"]["load"]).is_greater(0.8)
	assert_float(s["components"]["coolant_core"]["integrity"]).is_equal(20.0)
	assert_float(s["ship"]["coolant"]["coolant_core"]["leak_rate"]).is_greater(0.0)
	assert_int(_sc()["time_left"]).is_greater(3900)


func test_win_by_cutting_load_repairing_and_refilling() -> void:
	H.run(_rt, 2)
	assert_bool(H.accepted(_rt, {"type": "set_alert", "value": "green"})).is_true()  # core load falls
	assert_bool(H.accepted(_rt, {"type": "assign_team", "team": "dc_team_1", "target": "coolant_core"})).is_true()
	H.run_until(_rt, func() -> bool: return H.comp(_rt, "coolant_core")["integrity"] >= 100.0, 600)
	assert_float(H.comp(_rt, "coolant_core")["integrity"]).is_equal(100.0)
	assert_str(_sc()["status"]).is_equal("running")  # the loop is still low
	assert_bool(H.accepted(_rt, {"type": "coolant_refill", "target": "coolant_core", "value": true})).is_true()
	H.run_until(_rt, func() -> bool: return _sc()["status"] != "running", 600)
	assert_str(_sc()["status"]).is_equal("won")
	assert_str(H.comp(_rt, "warp_core")["state"]).is_equal("online")
	assert_bool(_rt.snapshot()["ship"]["destroyed"]).is_false()


func test_win_by_isolating_the_loop_at_low_power() -> void:
	H.run(_rt, 2)
	_rt.send({"type": "set_alert", "value": "green"})
	H.run(_rt, 3)  # the alert profile sets the core first, then the player lowers it
	_rt.send({"type": "set_output", "target": "warp_core", "value": 600})
	_rt.send({"type": "coolant_isolate", "target": "coolant_core", "value": true})
	_rt.send({"type": "assign_team", "team": "dc_team_1", "target": "coolant_core"})
	H.run_until(_rt, func() -> bool: return H.comp(_rt, "coolant_core")["integrity"] >= 100.0, 600)
	_rt.send({"type": "coolant_isolate", "target": "coolant_core", "value": false})
	_rt.send({"type": "coolant_refill", "target": "coolant_core", "value": true})
	H.run_until(_rt, func() -> bool: return _sc()["status"] != "running", 800)
	assert_str(_sc()["status"]).is_equal("won")


func test_lose_by_ignoring_the_leak() -> void:
	var n := H.run_until(_rt, func() -> bool: return _sc()["status"] != "running", 2400)
	assert_int(n).is_less(2400)
	assert_str(_sc()["status"]).is_equal("lost")
	assert_str(_sc()["reason"]).contains("breach")
	assert_str(H.comp(_rt, "warp_core")["state"]).is_equal("breach")
	assert_float(_rt.snapshot()["ship"]["coolant"]["coolant_core"]["level"]).is_equal(0.0)


func test_lose_by_ejecting_the_core() -> void:
	H.run_until(_rt, func() -> bool: return H.comp(_rt, "warp_core")["state"] == "containment_failing", 1200)
	assert_bool(H.accepted(_rt, {"type": "reactor_eject", "target": "warp_core"})).is_true()
	H.run(_rt, 3)
	assert_str(_sc()["status"]).is_equal("lost")
	assert_str(_sc()["reason"]).contains("ejected")


func test_overload_comes_before_containment_failure_and_a_late_fix_is_too_late() -> void:
	var seen: Array = []
	for i in 1200:
		_rt.step()
		var st: String = H.comp(_rt, "warp_core")["state"]
		if seen.is_empty() or seen[-1] != st:
			seen.append(st)
		if st == "containment_failing":
			break
	assert_array(seen).is_equal(["online", "overload", "containment_failing"])
	# once containment is failing a repair cannot stop the countdown
	_rt.send_debug({"type": "repair", "target": "coolant_core"})
	_rt.send({"type": "coolant_refill", "target": "coolant_core", "value": true})
	H.run_until(_rt, func() -> bool: return _sc()["status"] != "running", 1500)
	assert_str(_sc()["status"]).is_equal("lost")


func test_same_seed_same_run() -> void:
	var other := H.make(21)
	other.start_scenario("coolant_leak")
	H.run(_rt, 200)
	H.run(other, 200)
	assert_str(H.fingerprint(_rt)).is_equal(H.fingerprint(other))
	assert_array(_rt.missing_tunes).is_empty()
	other.dispose()


func test_win_at_red_alert_by_keeping_the_loop_topped_up_while_the_team_repairs() -> void:
	H.run(_rt, 2)
	assert_bool(H.accepted(_rt, {"type": "coolant_refill", "target": "coolant_core", "value": true})).is_true()
	assert_bool(H.accepted(_rt, {"type": "assign_team", "team": "dc_team_1", "target": "coolant_core"})).is_true()
	var peak := 0.0
	for i in 800:
		_rt.step()
		peak = maxf(peak, H.comp(_rt, "warp_core")["load"])
		if _sc()["status"] != "running":
			break
	assert_float(peak).is_greater(0.85)  # the core stayed at its high red alert load all the time
	assert_str(_sc()["status"]).is_equal("won")
	assert_str(_rt.snapshot()["ship"]["alert"]).is_equal("red")
	assert_float(H.comp(_rt, "warp_core")["temp"]).is_less(float(_rt.tune("coolant_leak", "cool_temp")) + 0.001)


func test_lose_on_timeout_when_the_leak_is_isolated_but_never_repaired() -> void:
	H.run(_rt, 2)
	_rt.send({"type": "set_alert", "value": "green"})
	H.run(_rt, 3)
	_rt.send({"type": "set_output", "target": "warp_core", "value": 0})  # impulse carries the ship, the core makes no heat
	_rt.send({"type": "coolant_isolate", "target": "coolant_core", "value": true})
	var n := H.run_until(_rt, func() -> bool: return _sc()["status"] != "running", 4200)
	assert_str(_sc()["status"]).is_equal("lost")
	assert_str(_sc()["reason"]).contains("time ran out")
	assert_int(n).is_between(3990, 4010)
	assert_str(H.comp(_rt, "warp_core")["state"]).is_equal("online")
