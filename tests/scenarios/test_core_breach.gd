extends GdUnitTestSuite
## core_breach: stabilise, eject or contain wins; a breach without containment loses. Commands only.

const H := preload("res://tests/systems/ship_helpers.gd")

var _rt: ShipRuntime


func before_test() -> void:
	_rt = H.make(11)
	assert_bool(_rt.start_scenario("core_breach")).is_true()


func after_test() -> void:
	_rt.dispose()


func _sc() -> Dictionary:
	return _rt.snapshot()["ship"]["scenario"]


func test_starts_running_with_a_timer_and_a_containment_fault() -> void:
	H.run(_rt, 5)
	assert_str(_sc()["status"]).is_equal("running")
	assert_int(_sc()["time_left"]).is_between(1300, 1500)
	assert_bool(_rt.snapshot()["ship"]["warp"]["fault_active"]).is_true()
	assert_float(_rt.snapshot()["ship"]["warp"]["field_pct"]).is_less(100.0)
	H.run(_rt, 100)
	assert_int(_sc()["tick"]).is_equal(105)


func test_win_by_shutting_the_core_down_in_time() -> void:
	H.run(_rt, 50)
	assert_bool(H.accepted(_rt, {"type": "reactor_shutdown", "target": "warp_core"})).is_true()
	H.run(_rt, 3)
	assert_str(_sc()["status"]).is_equal("won")
	assert_str(_sc()["reason"]).contains("shut down")
	assert_bool(_rt.snapshot()["ship"]["warp"]["fault_active"]).is_false()
	assert_str(H.comp(_rt, "life_support")["state"]).is_equal("ok")  # impulse carries the ship


func test_too_late_for_shutdown_then_eject_wins() -> void:
	H.run_until(_rt, func() -> bool: return H.comp(_rt, "warp_core")["state"] == "containment_failing", 600)
	assert_str(H.comp(_rt, "warp_core")["state"]).is_equal("containment_failing")
	assert_bool(H.accepted(_rt, {"type": "reactor_shutdown", "target": "warp_core"})).is_false()
	assert_float(_rt.snapshot()["ship"]["warp"]["field_pct"]).is_between(15.0, 40.0)
	assert_bool(H.accepted(_rt, {"type": "reactor_eject", "target": "warp_core"})).is_true()
	H.run(_rt, 3)
	assert_str(_sc()["status"]).is_equal("won")
	assert_str(H.comp(_rt, "warp_core")["state"]).is_equal("ejected")
	assert_bool(_rt.snapshot()["ship"]["destroyed"]).is_false()


func test_eject_is_refused_when_the_ejection_system_has_no_power() -> void:
	H.run_until(_rt, func() -> bool: return H.comp(_rt, "warp_core")["state"] == "containment_failing", 600)
	_rt.send_debug({"type": "damage", "target": "warp_core_aux", "amount": 100})
	H.run(_rt, 3)
	var r := _rt.send({"type": "reactor_eject", "target": "warp_core"})
	assert_bool(r["accepted"]).is_false()
	assert_str(r["reason"]).contains("D-CORE-003")
	assert_str(_sc()["status"]).is_equal("running")


func test_win_by_containing_the_breach_with_the_forcefield() -> void:
	H.run(_rt, 5)
	assert_bool(H.accepted(_rt, {"type": "containment_field", "value": true})).is_true()
	H.run_until(_rt, func() -> bool: return _sc()["status"] != "running", 1600)
	assert_str(_sc()["status"]).is_equal("won")
	assert_str(_sc()["reason"]).contains("forcefield")
	assert_str(H.comp(_rt, "warp_core")["state"]).is_equal("breach")
	assert_bool(_rt.snapshot()["ship"]["destroyed"]).is_false()
	H.run(_rt, 3)
	assert_float(H.comp(_rt, "eps_trunk_a")["integrity"]).is_greater(90.0)  # the breach damage was absorbed


func test_lose_by_doing_nothing_the_core_breaches() -> void:
	H.run_until(_rt, func() -> bool: return _sc()["status"] != "running", 1600)
	assert_str(_sc()["status"]).is_equal("lost")
	assert_str(_sc()["reason"]).contains("breach")
	assert_bool(_rt.snapshot()["ship"]["destroyed"]).is_true()
	assert_int(_sc()["tick"]).is_between(1400, 1450)  # critical after about 220 ticks, then 120 s (D-CORE-005)
	assert_int(_sc()["time_left"]).is_equal(0)


func test_a_weak_forcefield_does_not_contain() -> void:
	H.run(_rt, 5)
	_rt.send({"type": "containment_field", "value": true})
	H.run(_rt, 400)
	_rt.send({"type": "containment_field", "value": false})  # dropped before the breach
	H.run_until(_rt, func() -> bool: return _sc()["status"] != "running", 1600)
	assert_str(_sc()["status"]).is_equal("lost")


func test_status_is_final_after_the_scenario_ends() -> void:
	H.run(_rt, 50)
	_rt.send({"type": "reactor_shutdown", "target": "warp_core"})
	H.run(_rt, 3)
	assert_str(_sc()["status"]).is_equal("won")
	var tick: int = _sc()["tick"]
	H.run(_rt, 50)
	assert_str(_sc()["status"]).is_equal("won")
	assert_int(_sc()["tick"]).is_equal(tick)


func test_same_seed_same_run() -> void:
	var other := H.make(11)
	other.start_scenario("core_breach")
	for t in 300:
		if t == 40:
			_rt.send({"type": "shield_set", "frequency": 11, "modulation": 22})
			other.send({"type": "shield_set", "frequency": 11, "modulation": 22})
		_rt.step()
		other.step()
	assert_str(H.fingerprint(_rt)).is_equal(H.fingerprint(other))
	assert_array(_rt.missing_tunes).is_empty()
	other.dispose()
