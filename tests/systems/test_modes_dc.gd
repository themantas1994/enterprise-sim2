extends GdUnitTestSuite
## Alert conditions and operating modes (D-MODE-*), damage control teams and the repair queue.

const H := preload("res://tests/systems/ship_helpers.gd")

var _rt: ShipRuntime


func after_test() -> void:
	if _rt != null:
		_rt.dispose()
		_rt = null


func test_yellow_alert_holds_the_core_at_20_percent_and_one_backup_reactor_at_standby() -> void:
	_rt = H.make()
	H.run(_rt, 3)
	assert_bool(H.accepted(_rt, {"type": "set_output", "target": "warp_core", "value": 100})).is_true()
	assert_str(H.comp(_rt, "impulse_saucer_1")["state"]).is_equal("cold")
	_rt.send({"type": "set_alert", "value": "yellow"})
	H.run(_rt, 150)
	var s: Dictionary = _rt.snapshot()
	assert_str(s["ship"]["alert"]).is_equal("yellow")
	assert_str(s["ship"]["mode"]).is_equal("yellow_alert")
	assert_str(s["alert"]).is_equal("yellow")
	assert_float(s["ship"]["warp"]["setpoint"]).is_equal_approx(1000.0, 0.01)  # 20% of 5000 MW (D-MODE-001)
	assert_str(s["components"]["impulse_saucer_1"]["state"]).is_equal("standby")  # D-MODE-003
	assert_str(s["components"]["impulse_saucer_2"]["state"]).is_equal("cold")
	assert_float(s["components"]["shield_grid"]["demand"]).is_greater(58.0)  # secondary generators on partial standby (D-MODE-004)


func test_red_alert_raises_core_to_75_percent_and_starts_all_backups() -> void:
	_rt = H.make()
	_rt.send({"type": "set_alert", "value": "red"})
	H.run(_rt, 150)
	var s: Dictionary = _rt.snapshot()
	assert_float(s["ship"]["warp"]["setpoint"]).is_equal_approx(3750.0, 0.01)  # D-MODE-005
	assert_str(s["components"]["impulse_saucer_1"]["state"]).is_equal("standby")
	assert_str(s["components"]["impulse_saucer_2"]["state"]).is_equal("standby")  # D-MODE-008
	assert_int(s["components"]["shield_grid"]["priority"]).is_equal(3)
	_rt.send({"type": "set_alert", "value": "green"})
	H.run(_rt, 5)
	assert_str(_rt.snapshot()["ship"]["mode"]).is_equal("cruise")
	assert_float(_rt.snapshot()["ship"]["warp"]["setpoint"]).is_equal_approx(1500.0, 0.01)


func test_reduced_power_shuts_the_core_when_not_at_warp_and_keeps_impulse_minimum() -> void:
	_rt = H.make()
	H.run(_rt, 3)
	assert_bool(H.accepted(_rt, {"type": "set_mode", "value": "reduced_power"})).is_true()
	H.run(_rt, 10)
	var s: Dictionary = _rt.snapshot()
	assert_str(s["ship"]["mode"]).is_equal("reduced_power")
	assert_str(s["components"]["warp_core"]["state"]).is_equal("cold")  # D-MODE-011
	assert_float(s["components"]["impulse_main"]["power"]).is_greater(300.0)  # D-MODE-012, D-SAFE-002
	assert_str(s["components"]["life_support"]["state"]).is_equal("ok")
	assert_int(s["components"]["shield_grid"]["priority"]).is_equal(6)
	assert_bool(H.accepted(_rt, {"type": "set_mode", "value": "turbo"})).is_false()


func test_reduced_power_keeps_the_core_when_at_warp() -> void:
	_rt = H.make()
	H.run(_rt, 3)
	_rt.send({"type": "core_set_mode", "value": "warp"})
	_rt.send({"type": "set_warp", "value": 5.0})
	H.run(_rt, 150)
	_rt.send({"type": "set_mode", "value": "reduced_power"})
	H.run(_rt, 10)
	assert_str(H.comp(_rt, "warp_core")["state"]).is_equal("online")


func test_damage_control_repairs_in_the_estimated_time_and_lists_the_queue() -> void:
	_rt = H.make()
	H.run(_rt, 3)
	_rt.send({"type": "damage", "target": "eps_sub_weapons", "amount": 30})
	_rt.send({"type": "damage", "target": "phaser_array", "amount": 80})
	H.run(_rt, 2)
	var dc: Dictionary = _rt.snapshot()["ship"]["damage_control"]
	assert_array(dc["queue"]).has_size(2)
	assert_str(dc["queue"][0]["id"]).is_equal("phaser_array")  # worst first
	assert_bool(H.accepted(_rt, {"type": "assign_team", "team": "dc_team_1", "target": "eps_trunk_a"})).is_false()  # undamaged
	assert_bool(H.accepted(_rt, {"type": "assign_team", "team": "dc_team_9", "target": "phaser_array"})).is_false()
	assert_bool(H.accepted(_rt, {"type": "assign_team", "team": "dc_team_1", "target": "phaser_array"})).is_true()
	assert_bool(H.accepted(_rt, {"type": "assign_team", "team": "dc_team_2", "target": "phaser_array"})).is_false()  # taken
	assert_bool(H.accepted(_rt, {"type": "assign_team", "team": "dc_team_2", "target": "eps_sub_weapons"})).is_true()
	H.run(_rt, 3)
	var teams: Dictionary = _rt.snapshot()["ship"]["damage_control"]["teams"]
	assert_str(teams["dc_team_1"]["state"]).is_equal("working")
	assert_str(teams["dc_team_1"]["target"]).is_equal("phaser_array")
	assert_str(teams["dc_team_3"]["state"]).is_equal("idle")
	var eta := int(teams["dc_team_1"]["left"])
	assert_int(eta).is_between(280, 330)  # 20 + 100 + 2.5 x 80
	H.run(_rt, eta - 6)
	assert_float(H.comp(_rt, "phaser_array")["integrity"]).is_equal(20.0)
	H.run(_rt, 10)
	assert_float(H.comp(_rt, "phaser_array")["integrity"]).is_equal(100.0)
	assert_float(H.comp(_rt, "eps_sub_weapons")["integrity"]).is_equal(100.0)
	assert_array(_rt.snapshot()["ship"]["damage_control"]["queue"]).is_empty()
	assert_int(_rt.snapshot()["ship"]["damage_control"]["teams"]["dc_team_1"]["done"]).is_equal(1)


func test_a_team_can_be_recalled_and_a_cut_conduit_is_repairable() -> void:
	_rt = H.make()
	H.run(_rt, 3)
	_rt.send({"type": "cut_conduit", "target": "eps_cross_link"})
	H.run(_rt, 2)
	assert_str(_rt.snapshot()["ship"]["damage_control"]["queue"][0]["id"]).is_equal("eps_cross_link")
	assert_bool(H.accepted(_rt, {"type": "assign_team", "team": "dc_team_4", "target": "eps_cross_link"})).is_true()
	H.run(_rt, 20)
	assert_bool(H.accepted(_rt, {"type": "recall_team", "team": "dc_team_4"})).is_true()
	H.run(_rt, 200)
	assert_str(H.comp(_rt, "eps_cross_link")["state"]).is_equal("cut")  # recalled: nobody repaired it
	_rt.send({"type": "assign_team", "team": "dc_team_4", "target": "eps_cross_link"})
	H.run(_rt, 160)
	assert_str(H.comp(_rt, "eps_cross_link")["state"]).is_equal("ok")


func test_a_reactor_in_breach_cannot_be_repaired() -> void:
	_rt = H.make()
	H.run(_rt, 3)
	_rt.send({"type": "damage", "target": "warp_core", "amount": 70})
	var n := H.run_until(_rt, func() -> bool: return H.comp(_rt, "warp_core")["state"] == "breach", 1400)
	assert_int(n).is_less(1400)
	assert_bool(H.accepted(_rt, {"type": "assign_team", "team": "dc_team_1", "target": "warp_core"})).is_false()
	assert_bool(H.accepted(_rt, {"type": "repair", "target": "warp_core"})).is_false()
	var q: Array = _rt.snapshot()["ship"]["damage_control"]["queue"]
	var found := false
	for e: Dictionary in q:
		if e["id"] == "warp_core":
			found = true
			assert_bool(e["repairable"]).is_false()
	assert_bool(found).is_true()
	assert_bool(_rt.snapshot()["ship"]["destroyed"]).is_true()  # breach without the forcefield
