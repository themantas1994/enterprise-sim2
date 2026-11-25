extends GdUnitTestSuite
## Coolant loops and leaks, fuel burn, pod containment and the antimatter generator.

const H := preload("res://tests/systems/ship_helpers.gd")

var _rt: ShipRuntime


func after_test() -> void:
	if _rt != null:
		_rt.dispose()
		_rt = null


func _cool() -> Dictionary:
	return _rt.snapshot()["ship"]["coolant"]


func test_a_leak_drains_the_loop_and_isolation_stops_it() -> void:
	_rt = H.make()
	H.run(_rt, 5)
	assert_float(_cool()["coolant_core"]["level"]).is_equal(100.0)
	_rt.send({"type": "damage", "target": "coolant_core", "amount": 50})
	H.run(_rt, 100)
	var lvl: float = _cool()["coolant_core"]["level"]
	assert_float(lvl).is_less(100.0)
	assert_float(_cool()["coolant_eps"]["level"]).is_equal(100.0)
	assert_bool(H.accepted(_rt, {"type": "coolant_isolate", "target": "coolant_core", "value": true})).is_true()
	H.run(_rt, 50)
	assert_float(_cool()["coolant_core"]["level"]).is_equal_approx(lvl - 0.0, 0.5)
	assert_float(_cool()["coolant_core"]["flow"]).is_equal(0.0)
	assert_bool(H.accepted(_rt, {"type": "coolant_isolate", "target": "warp_core", "value": true})).is_false()


func test_a_drained_core_loop_overheats_the_core_and_a_full_one_does_not() -> void:
	_rt = H.make()
	_rt.send({"type": "set_alert", "value": "red"})
	H.run(_rt, 300)
	var t_ok: float = H.comp(_rt, "warp_core")["temp"]
	_rt.send({"type": "damage", "target": "coolant_core", "amount": 100})
	H.run(_rt, 400)
	var t_hot: float = H.comp(_rt, "warp_core")["temp"]
	assert_float(_cool()["coolant_core"]["level"]).is_equal_approx(0.0, 0.001)
	assert_float(t_hot).is_greater(t_ok + 40.0)


func test_refill_moves_reserve_into_the_loop() -> void:
	_rt = H.make()
	_rt.send({"type": "damage", "target": "coolant_core", "amount": 60})
	H.run(_rt, 150)
	_rt.send({"type": "repair", "target": "coolant_core"})
	var low: float = _cool()["coolant_core"]["level"]
	var reserve: float = _cool()["reserve"]
	_rt.send({"type": "coolant_refill", "target": "coolant_core", "value": true})
	H.run(_rt, 30)
	assert_float(_cool()["coolant_core"]["level"]).is_greater(low + 10.0)
	assert_float(_cool()["reserve"]).is_less(reserve)
	_rt.send({"type": "coolant_isolate", "target": "coolant_core", "value": true})
	assert_bool(H.accepted(_rt, {"type": "coolant_refill", "target": "coolant_core", "value": true})).is_false()


func test_eps_loop_leak_overheats_the_busiest_conduit_compared_with_a_healthy_loop() -> void:
	var integrity: Array = []
	for leak in [false, true]:
		var rt := H.make()
		rt.send({"type": "set_alert", "value": "red"})
		if leak:
			rt.send({"type": "damage", "target": "coolant_eps", "amount": 100})
		H.run(rt, 600)
		integrity.append(rt.snapshot()["components"]["eps_sub_saucer"]["integrity"])
		if leak:
			assert_float(rt.snapshot()["ship"]["coolant"]["coolant_eps"]["level"]).is_equal_approx(0.0, 0.001)
		rt.dispose()
	assert_float(integrity[0]).is_equal(100.0)
	assert_float(integrity[1]).is_less(50.0)  # without cooling the loaded submaster conduit burns out


func test_fuel_burns_and_levels_are_in_the_detail() -> void:
	_rt = H.make()
	var d0: Dictionary = _rt.snapshot()["ship"]["detail"]
	assert_float(d0["deuterium_tank_main"]["level"]).is_equal(62500.0)  # D-FUEL-007
	assert_float(d0["antimatter_pod_01"]["level"]).is_equal(100.0)  # D-FUEL-002
	H.run(_rt, 200)
	var f: Dictionary = _rt.snapshot()["ship"]["fuel"]
	assert_float(f["deuterium_main_m3"]).is_less(62500.0)
	assert_float(f["antimatter_m3"]).is_less(3000.0)
	assert_float(f["antimatter_m3"]).is_greater(2999.0)


func test_empty_antimatter_stops_the_core_and_blocks_warp() -> void:
	_rt = H.make()
	H.run(_rt, 3)
	for i in range(1, 31):
		_rt.fuel.set_level("antimatter_pod_%02d" % i, 0.0)
	H.run(_rt, 3)
	assert_float(H.comp(_rt, "warp_core")["power"]).is_equal_approx(0.0, 0.01)
	assert_bool(H.accepted(_rt, {"type": "core_set_mode", "value": "warp"})).is_true()
	assert_bool(H.accepted(_rt, {"type": "set_warp", "value": 3.0})).is_false()
	assert_str(H.comp(_rt, "life_support")["state"]).is_equal("ok")  # the impulse reactor carries the ship (D-SAFE-002)


func test_empty_deuterium_stops_impulse() -> void:
	_rt = H.make()
	H.run(_rt, 3)
	_rt.fuel.set_level("deuterium_tank_main", 0.0)
	H.run(_rt, 3)
	assert_bool(H.accepted(_rt, {"type": "set_impulse", "value": 0.3})).is_false()
	assert_float(H.comp(_rt, "impulse_main")["power"]).is_equal_approx(0.0, 0.01)


func test_pod_containment_needs_power_and_collapses_into_automatic_ejection() -> void:
	_rt = H.make()
	H.run(_rt, 10)
	assert_float(_rt.snapshot()["ship"]["fuel"]["containment"]).is_equal(1.0)
	_rt.send({"type": "damage", "target": "antimatter_containment", "amount": 100})
	H.run(_rt, 400)
	var c: float = _rt.snapshot()["ship"]["fuel"]["containment"]
	assert_float(c).is_less(0.9)
	assert_bool(_rt.snapshot()["ship"]["fuel"]["pods_ejected"]).is_false()
	H.run(_rt, 1500)
	var f: Dictionary = _rt.snapshot()["ship"]["fuel"]
	assert_bool(f["pods_ejected"]).is_true()  # D-FUEL-005, D-SAFE-005
	assert_float(f["antimatter_m3"]).is_equal(0.0)


func test_a_leaking_pod_loses_antimatter() -> void:
	_rt = H.make()
	_rt.send({"type": "damage", "target": "antimatter_pod_07", "amount": 100})
	H.run(_rt, 50)
	assert_float(_rt.snapshot()["ship"]["detail"]["antimatter_pod_07"]["level"]).is_less(95.0)
	assert_float(_rt.snapshot()["ship"]["detail"]["antimatter_pod_08"]["level"]).is_greater(99.9)


func test_antimatter_generator_makes_antimatter_from_deuterium_at_ten_to_one() -> void:
	_rt = H.make()
	_rt.fuel.set_level("antimatter_pod_01", 50.0)
	H.run(_rt, 3)
	var f0: Dictionary = _rt.snapshot()["ship"]["fuel"]
	assert_bool(H.accepted(_rt, {"type": "antimatter_generator_set", "value": true})).is_true()
	H.run(_rt, 4)
	var f1: Dictionary = _rt.snapshot()["ship"]["fuel"]
	var d_am: float = f1["antimatter_m3"] - f0["antimatter_m3"]
	assert_float(d_am).is_greater(0.0)
	# burn also lowers the tank, so compare the generator's share: 10 units of deuterium per unit of antimatter
	assert_float(f0["deuterium_main_m3"] - f1["deuterium_main_m3"]).is_greater(d_am * 9.0)
