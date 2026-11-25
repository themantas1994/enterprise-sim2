extends GdUnitTestSuite
## EPS: shedding under shortage and a conduit cut with a reroute through eps_cross_link.

const H := preload("res://tests/systems/ship_helpers.gd")

var _rt: ShipRuntime


func after_test() -> void:
	if _rt != null:
		_rt.dispose()
		_rt = null


func test_shortage_sheds_lowest_priority_first() -> void:
	_rt = H.make()
	H.run(_rt, 20)
	# one small source left: core 200 MW, main impulse off, battery destroyed
	_rt.send({"type": "damage", "target": "battery_emergency", "amount": 100})
	_rt.send({"type": "set_output", "target": "impulse_main", "value": 0})
	_rt.send({"type": "set_output", "target": "warp_core", "value": 200})
	H.run(_rt, 10)
	var comps: Dictionary = _rt.snapshot()["components"]
	var supplied := 0.0
	for id: String in comps:
		if comps[id]["kind"] == "consumer":
			supplied += comps[id]["power"]
	assert_float(supplied).is_less(201.0)
	assert_str(comps["antimatter_containment"]["state"]).is_equal("ok")  # priority 0
	assert_str(comps["life_support"]["state"]).is_equal("ok")  # priority 1
	assert_str(comps["computer_core_p1"]["state"]).is_equal("ok")  # priority 2
	assert_str(comps["phaser_array"]["state"]).is_equal("shed")  # priority 8 in cruise
	assert_str(comps["warp_nacelle_port"]["state"]).is_equal("shed")  # priority 6
	# the least important consumers go first: a higher-priority one never has less than a lower one
	var p_sif: float = comps["sif_grid"]["power"] / comps["sif_grid"]["demand"]
	var p_shield: float = comps["shield_grid"]["power"] / comps["shield_grid"]["demand"]
	assert_float(p_sif).is_greater_equal(p_shield)
	# an alert reorders the priorities: phasers move ahead of the nacelles
	_rt.send({"type": "set_alert", "value": "red"})
	H.run(_rt, 10)
	assert_int(H.comp(_rt, "phaser_array")["priority"]).is_less(H.comp(_rt, "warp_nacelle_port")["priority"])


func test_cut_trunk_reroutes_through_the_cross_link() -> void:
	_rt = H.make()
	H.run(_rt, 30)
	var before: Dictionary = _rt.snapshot()["components"]
	assert_float(before["eps_trunk_a"]["power"]).is_greater(0.0)
	assert_float(before["eps_cross_link"]["power"]).is_equal_approx(0.0, 0.001)
	assert_str(before["life_support"]["state"]).is_equal("ok")
	_rt.send({"type": "cut_conduit", "target": "eps_trunk_a"})
	H.run(_rt, 5)
	var after: Dictionary = _rt.snapshot()["components"]
	assert_str(after["eps_trunk_a"]["state"]).is_equal("cut")
	assert_float(after["eps_trunk_a"]["power"]).is_equal_approx(0.0, 0.001)
	assert_float(after["eps_cross_link"]["power"]).is_greater(0.0)  # the saucer side is fed through the cross link
	assert_float(after["eps_trunk_b"]["power"]).is_greater(before["eps_trunk_b"]["power"])
	for id: String in ["life_support", "computer_core_p1", "shield_grid", "sif_grid", "idf_grid"]:
		assert_str(after[id]["state"]).override_failure_message(id).is_equal("ok")


func test_cutting_trunk_and_cross_link_leaves_the_saucer_on_its_own_sources() -> void:
	_rt = H.make()
	_rt.send({"type": "set_alert", "value": "red"})
	H.run(_rt, 150)  # red alert starts the saucer reactors to hot standby (D-MODE-008)
	assert_str(H.comp(_rt, "impulse_saucer_1")["state"]).is_equal("standby")
	assert_str(H.comp(_rt, "shield_grid")["state"]).is_equal("ok")
	_rt.send({"type": "cut_conduit", "target": "eps_trunk_a"})
	_rt.send({"type": "cut_conduit", "target": "eps_cross_link"})
	H.run(_rt, 10)
	var c: Dictionary = _rt.snapshot()["components"]
	# the saucer submaster has no path to the core; only the emergency battery (300 MW) is left there
	assert_float(c["eps_sub_saucer"]["power"]).is_less(301.0)
	assert_str(c["life_support"]["state"]).is_equal("ok")  # essential load still served
	assert_str(c["shield_grid"]["state"]).is_not_equal("ok")
	var shield_before: float = c["shield_grid"]["power"]
	# the saucer reactors and the auxiliary generators power the saucer submaster alone
	_rt.send({"type": "set_output", "target": "aux_fusion_1", "value": 200})
	_rt.send({"type": "set_output", "target": "aux_fusion_2", "value": 200})
	_rt.send({"type": "reactor_online", "target": "impulse_saucer_1"})
	_rt.send({"type": "reactor_online", "target": "impulse_saucer_2"})
	H.run(_rt, 10)
	c = _rt.snapshot()["components"]
	assert_float(c["feed_impulse_saucer_1"]["power"]).is_greater(0.0)
	assert_float(c["feed_aux_fusion_1"]["power"]).is_greater(0.0)
	assert_float(c["shield_grid"]["power"]).is_greater(shield_before + 500.0)
	assert_float(c["eps_sub_saucer"]["power"]).is_equal_approx(0.0, 0.001)  # nothing came through the cut side
