extends GdUnitTestSuite
## Warp core: start-up sequence, ratio, injector redundancy, alignment, output control.

const H := preload("res://tests/systems/ship_helpers.gd")

var _rt: ShipRuntime


func after_test() -> void:
	if _rt != null:
		_rt.dispose()
		_rt = null


func _cold() -> ShipRuntime:
	return H.make(1, func(raw: Dictionary) -> void: H.set_state(raw, "warp_core", "cold"))


func _warp() -> Dictionary:
	return _rt.snapshot()["ship"]["warp"]


func test_cold_start_sequence_follows_the_manual() -> void:
	_rt = _cold()
	H.run(_rt, 5)
	assert_str(_warp()["stage"]).is_equal("cold")
	assert_float(H.comp(_rt, "warp_core")["power"]).is_equal(0.0)
	assert_bool(H.accepted(_rt, {"type": "core_inject"})).is_false()  # not heated yet
	assert_bool(H.accepted(_rt, {"type": "reactor_online", "target": "warp_core"})).is_false()
	assert_bool(H.accepted(_rt, {"type": "reactor_start", "target": "warp_core"})).is_true()
	H.run(_rt, 10)
	assert_str(_warp()["stage"]).is_equal("heating")
	assert_bool(H.accepted(_rt, {"type": "reactor_start", "target": "warp_core"})).is_false()  # already running
	H.run_until(_rt, func() -> bool: return _warp()["stage"] == "heated", 400)
	assert_str(_warp()["stage"]).is_equal("heated")
	assert_float(_warp()["chamber_k"]).is_equal_approx(2500000.0, 1.0)  # D-WARP-011
	assert_bool(H.accepted(_rt, {"type": "core_pressurize"})).is_false()  # needs the idle stage
	assert_bool(H.accepted(_rt, {"type": "core_inject"})).is_true()
	H.run_until(_rt, func() -> bool: return _warp()["stage"] == "idle", 400)
	assert_str(_warp()["stage"]).is_equal("idle")
	assert_float(_warp()["ratio"]).is_equal_approx(25.0, 0.001)  # D-WARP-012
	assert_bool(H.accepted(_rt, {"type": "core_pressurize"})).is_true()
	H.run_until(_rt, func() -> bool: return H.comp(_rt, "warp_core")["state"] == "standby", 600)
	assert_str(H.comp(_rt, "warp_core")["state"]).is_equal("standby")
	assert_float(_warp()["pressure_kpa"]).is_equal_approx(72000.0, 0.1)  # D-WARP-013
	assert_bool(H.accepted(_rt, {"type": "reactor_online", "target": "warp_core"})).is_true()
	H.run(_rt, 10)
	assert_str(_warp()["stage"]).is_equal("online")
	assert_float(H.comp(_rt, "warp_core")["power"]).is_greater(100.0)


func test_start_up_stalls_without_power_and_resumes() -> void:
	_rt = _cold()
	_rt.send({"type": "set_output", "target": "impulse_main", "value": 0})  # no ship power at all
	H.run(_rt, 5)
	assert_bool(H.accepted(_rt, {"type": "reactor_start", "target": "warp_core"})).is_true()
	H.run(_rt, 30)
	assert_str(_warp()["stage"]).is_equal("heating")
	assert_str(_warp()["stalled"]).is_not_empty()
	assert_float(_warp()["chamber_k"]).is_less(1000.0)
	_rt.send({"type": "set_output", "target": "impulse_main", "value": 1200})  # ship power returns
	H.run(_rt, 30)
	assert_str(_warp()["stalled"]).is_empty()
	assert_float(_warp()["chamber_k"]).is_greater(10000.0)


func test_shutdown_aborts_start_up_and_hot_chamber_cools_in_ten_minutes() -> void:
	_rt = _cold()
	H.run(_rt, 3)
	_rt.send({"type": "reactor_start", "target": "warp_core"})
	H.run(_rt, 30)
	assert_bool(H.accepted(_rt, {"type": "reactor_shutdown", "target": "warp_core"})).is_true()
	H.run(_rt, 3)
	assert_str(_warp()["stage"]).is_equal("cold")
	# a running core shut down: chamber cold after about 10 minutes (D-SAFE-001), 6000 ticks
	var hot := H.make()
	H.run(hot, 5)
	hot.send({"type": "reactor_shutdown", "target": "warp_core"})
	H.run(hot, 10)
	assert_float(hot.snapshot()["ship"]["warp"]["chamber_k"]).is_greater(1.0e11)
	H.run(hot, 6000)
	assert_float(hot.snapshot()["ship"]["warp"]["chamber_k"]).is_less(1000.0)
	hot.dispose()


func test_ratio_moves_to_one_to_one_at_warp_8_and_stays() -> void:
	_rt = H.make()
	H.run(_rt, 5)
	assert_float(_warp()["ratio_target"]).is_equal_approx(25.0, 0.001)
	_rt.send({"type": "core_set_mode", "value": "warp"})
	_rt.send({"type": "set_output", "target": "warp_core", "value": 5000})
	_rt.send({"type": "set_warp", "value": 8.0})
	H.run(_rt, 400)
	assert_float(_rt.snapshot()["ship"]["propulsion"]["warp"]).is_equal_approx(8.0, 0.001)
	assert_float(_warp()["ratio_target"]).is_equal_approx(1.0, 0.001)  # D-WARP-015
	assert_float(_warp()["ratio"]).is_equal_approx(1.0, 0.01)
	_rt.send({"type": "set_output", "target": "warp_core", "value": 5000})
	_rt.send({"type": "set_warp", "value": 9.2})
	H.run(_rt, 100)
	assert_float(_rt.snapshot()["ship"]["propulsion"]["warp"]).is_equal_approx(9.2, 0.001)
	assert_float(_warp()["ratio_target"]).is_equal_approx(1.0, 0.001)  # unchanged above warp 8


func test_wrong_ratio_costs_output_and_auto_ratio_recovers() -> void:
	_rt = H.make()
	H.run(_rt, 5)
	var cap_good: float = _warp()["cap"]
	assert_bool(H.accepted(_rt, {"type": "core_set_ratio", "value": 5.0})).is_true()
	H.run(_rt, 3)
	assert_float(_warp()["cap"]).is_less(cap_good)
	assert_bool(H.accepted(_rt, {"type": "core_set_ratio", "value": 0.5})).is_false()
	_rt.send({"type": "core_auto_ratio", "value": true})
	H.run(_rt, 200)
	assert_float(_warp()["cap"]).is_equal_approx(cap_good, 0.001)


func test_matter_injectors_are_redundant_and_the_rest_dilate() -> void:
	_rt = H.make()
	H.run(_rt, 5)
	for i in [1, 2, 3]:
		_rt.send_debug({"type": "damage", "target": "warp_injector_matter_%d" % i, "amount": 100})
	H.run(_rt, 3)
	assert_int(_warp()["matter_usable"]).is_equal(3)
	assert_float(_warp()["cap"]).is_equal_approx(1.0, 0.001)  # D-WARP-003: the remaining nozzles dilate
	_rt.send({"type": "injector_set", "target": "warp_injector_matter_4", "value": false})
	H.run(_rt, 3)
	assert_int(_warp()["matter_usable"]).is_equal(2)
	assert_float(_warp()["cap"]).is_equal_approx(2.0 / 3.0, 0.001)
	assert_bool(H.accepted(_rt, {"type": "injector_set", "target": "warp_core", "value": false})).is_false()
	for i in [5, 6]:
		_rt.send({"type": "injector_set", "target": "warp_injector_matter_%d" % i, "value": false})
	H.run(_rt, 3)
	assert_float(_warp()["cap"]).is_equal(0.0)
	assert_float(H.comp(_rt, "warp_core")["power"]).is_equal_approx(0.0, 0.01)


func test_antimatter_nozzles_constrictors_and_alignment_limit_output() -> void:
	_rt = H.make()
	H.run(_rt, 5)
	_rt.send_debug({"type": "damage", "target": "warp_injector_antimatter_1", "amount": 100})
	_rt.send_debug({"type": "damage", "target": "warp_injector_antimatter_2", "amount": 100})
	H.run(_rt, 3)
	assert_float(_warp()["cap"]).is_equal_approx(0.5, 0.001)
	_rt.send_debug({"type": "repair", "target": "warp_injector_antimatter_1"})
	_rt.send_debug({"type": "damage", "target": "warp_constrictor_upper", "amount": 50})
	H.run(_rt, 3)
	assert_float(_warp()["cap"]).is_equal_approx(0.7, 0.001)
	_rt.send({"type": "core_set_mode", "value": "warp"})
	_rt.send_debug({"type": "damage", "target": "warp_dilithium_frame", "amount": 40})
	H.run(_rt, 3)
	assert_float(_warp()["alignment"]).is_equal_approx(0.6, 0.001)
	assert_float(_warp()["cap"]).is_less(0.7)


func test_setpoint_is_clamped_by_the_cap() -> void:
	_rt = H.make()
	_rt.send({"type": "set_alert", "value": "red"})
	H.run(_rt, 5)
	assert_bool(H.accepted(_rt, {"type": "set_output", "target": "warp_core", "value": 6000})).is_false()
	assert_bool(H.accepted(_rt, {"type": "set_output", "target": "warp_core", "value": 3000})).is_true()
	H.run(_rt, 3)
	assert_float(_warp()["setpoint"]).is_equal(3000.0)
	assert_float(H.comp(_rt, "warp_core")["power"]).is_greater(2600.0)
	_rt.send_debug({"type": "damage", "target": "warp_injector_antimatter_1", "amount": 100})
	_rt.send_debug({"type": "damage", "target": "warp_injector_antimatter_2", "amount": 100})
	H.run(_rt, 5)
	# the factors scale the setpoint: 3000 x 0.5 = 1500 MW although the red alert load is higher
	assert_float(H.comp(_rt, "warp_core")["power"]).is_between(1450.0, 1550.0)


func test_warp_needs_warp_mode_core_and_nacelles() -> void:
	_rt = H.make()
	H.run(_rt, 5)
	assert_bool(H.accepted(_rt, {"type": "set_warp", "value": 5.0})).is_false()  # power mode
	assert_bool(H.accepted(_rt, {"type": "core_set_mode", "value": "warp"})).is_true()
	_rt.send({"type": "set_output", "target": "warp_core", "value": 3000})  # the player raises the core for warp; the grid has no emergency battery (D-EPS-001)
	assert_bool(H.accepted(_rt, {"type": "set_warp", "value": 9.9})).is_false()  # above 9.6 (D-DESIGN-003)
	assert_bool(H.accepted(_rt, {"type": "set_warp", "value": 6.0})).is_true()
	H.run(_rt, 200)
	assert_float(_rt.snapshot()["ship"]["propulsion"]["warp"]).is_equal_approx(6.0, 0.001)
	assert_bool(H.accepted(_rt, {"type": "core_set_mode", "value": "power"})).is_false()  # not while at warp
	_rt.send_debug({"type": "damage", "target": "warp_nacelle_port", "amount": 100})
	H.run(_rt, 3)
	assert_float(_rt.snapshot()["ship"]["propulsion"]["warp"]).is_equal(0.0)
