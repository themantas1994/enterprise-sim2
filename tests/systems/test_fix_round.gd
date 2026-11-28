extends GdUnitTestSuite
## Player command boundary, scenario reset, input validation, shield level rules, per-hull fields, modes.

const H := preload("res://tests/systems/ship_helpers.gd")

var _rt: ShipRuntime


func after_test() -> void:
	if _rt != null:
		_rt.dispose()
		_rt = null


# ---- A: player commands --------------------------------------------------------------------------------------

func test_raw_repair_damage_and_add_heat_are_not_player_commands() -> void:
	_rt = H.make()
	H.run(_rt, 2)
	for type in ["repair", "damage", "add_heat"]:
		var r := _rt.send({"type": type, "target": "warp_core", "amount": 10})
		assert_bool(r["accepted"]).is_false()
		assert_str(r["reason"]).contains("not a player command")
	assert_bool(_rt.send_debug({"type": "damage", "target": "life_support", "amount": 10})["accepted"]).is_true()
	H.run(_rt, 2)
	assert_float(H.comp(_rt, "life_support")["integrity"]).is_equal(90.0)


func test_spamming_repair_does_not_save_the_core_breach_scenario() -> void:
	_rt = H.make(11)
	_rt.start_scenario("core_breach")
	for t in 1600:
		_rt.send({"type": "repair", "target": "warp_core"})
		_rt.step()
		if _rt.snapshot()["ship"]["scenario"]["status"] != "running":
			break
	assert_str(_rt.snapshot()["ship"]["scenario"]["status"]).is_equal("lost")


# ---- B: scenario reset ---------------------------------------------------------------------------------------

func test_second_scenario_starts_on_a_fresh_ship() -> void:
	_rt = H.make(11)
	_rt.start_scenario("core_breach")
	H.run_until(_rt, func() -> bool: return _rt.snapshot()["ship"]["scenario"]["status"] != "running", 1600)
	assert_str(_rt.snapshot()["ship"]["scenario"]["status"]).is_equal("lost")
	assert_bool(_rt.snapshot()["ship"]["destroyed"]).is_true()
	assert_bool(_rt.start_scenario("coolant_leak")).is_true()
	H.run(_rt, 5)
	var s := _rt.snapshot()
	assert_str(s["ship"]["scenario"]["id"]).is_equal("coolant_leak")
	assert_str(s["ship"]["scenario"]["status"]).is_equal("running")
	assert_bool(s["ship"]["destroyed"]).is_false()
	assert_str(s["components"]["warp_core"]["state"]).is_equal("online")
	assert_float(s["components"]["warp_core"]["integrity"]).is_equal(100.0)
	assert_int(s["tick"]).is_equal(5)
	assert_bool(s["ship"]["warp"]["fault_active"]).is_false()


func test_start_scenario_on_an_invalid_runtime_returns_false() -> void:
	_rt = ShipRuntime.create_from_data({"producers": [{"id": "x"}]}, 1)
	assert_bool(_rt.valid).is_false()
	assert_bool(_rt.start_scenario("core_breach")).is_false()
	assert_bool(_rt.send({"type": "set_alert", "value": "red"})["accepted"]).is_false()
	_rt.step()
	assert_bool(_rt.snapshot()["ship"]["valid"]).is_false()


func test_unknown_scenario_leaves_the_state_alone_and_dispose_is_idempotent() -> void:
	_rt = H.make(3)
	H.run(_rt, 10)
	assert_bool(_rt.start_scenario("nope")).is_false()
	assert_int(_rt.snapshot()["tick"]).is_equal(10)
	_rt.dispose()
	_rt.dispose()
	assert_bool(_rt.start_scenario("borg_drain")).is_true()


# ---- C: NaN and inf ------------------------------------------------------------------------------------------

func test_non_finite_numbers_are_rejected_everywhere() -> void:
	_rt = H.make()
	H.run(_rt, 2)
	for bad in [NAN, INF, -INF]:
		assert_bool(H.accepted(_rt, {"type": "shield_set_level", "value": bad})).is_false()
		assert_bool(H.accepted(_rt, {"type": "shield_set_weights", "fore": bad, "aft": 1, "port": 1, "stbd": 1})).is_false()
		assert_bool(H.accepted(_rt, {"type": "shield_set", "frequency": bad})).is_false()
		assert_bool(H.accepted(_rt, {"type": "shield_set", "modulation": bad})).is_false()
		assert_bool(H.accepted(_rt, {"type": "core_set_ratio", "value": bad})).is_false()
		assert_bool(H.accepted(_rt, {"type": "set_warp", "value": bad})).is_false()
		assert_bool(H.accepted(_rt, {"type": "set_impulse", "value": bad})).is_false()
		assert_bool(H.accepted(_rt, {"type": "set_output", "target": "warp_core", "value": bad})).is_false()
		assert_bool(H.accepted(_rt, {"type": "set_allocation", "target": "phaser_array", "value": bad})).is_false()
		assert_bool(H.accepted(_rt, {"type": "set_priority", "target": "phaser_array", "value": bad})).is_false()
	assert_float(_rt.shields.alert_level).is_equal(0.85)
	assert_float(_rt.warp.ratio).is_less(100.0)


# ---- D: shield level -----------------------------------------------------------------------------------------

func test_shield_level_is_at_least_85_percent_at_alert() -> void:
	_rt = H.make()
	var r := _rt.send({"type": "shield_set_level", "value": 0.5})
	assert_bool(r["accepted"]).is_false()
	assert_str(r["reason"]).contains("D-SHLD-013")
	assert_bool(H.accepted(_rt, {"type": "shield_set_level", "value": 0.9})).is_true()
	_rt.send({"type": "set_alert", "value": "yellow"})
	H.run(_rt, 10)
	# yellow: the three running generators are at the alert level, not at the cruise level
	assert_float(H.comp(_rt, "shield_grid")["demand"]).is_greater(3.0 * 384.0 * 0.89)
	assert_float(_rt.snapshot()["ship"]["shields"]["alert_level"]).is_equal(0.9)


func test_cruise_draw_is_the_nominal_1152_mw_while_the_level_stays_five_percent() -> void:
	_rt = H.make()
	H.run(_rt, 60)
	assert_float(H.comp(_rt, "shield_grid")["demand"]).is_equal_approx(1152.0, 0.01)
	assert_float(_rt.snapshot()["ship"]["shields"]["strength"]).is_between(0.04, 0.08)


# ---- E: per-hull cruise rule and ladder impulse cap ----------------------------------------------------------

func test_losing_both_engineering_idf_generators_in_cruise_degrades_the_idf() -> void:
	_rt = H.make()
	H.run(_rt, 10)
	var kinds: Array = []
	_rt.send_debug({"type": "damage", "target": "idf_gen_e1", "amount": 100})
	_rt.send_debug({"type": "damage", "target": "idf_gen_e2", "amount": 100})
	for i in 10:
		_rt.step()
		for e: Dictionary in _rt.snapshot()["ship"]["events"]:
			if e["type"] == "field_degraded":
				kinds.append(e)
	assert_int(kinds.size()).is_equal(1)
	assert_str(kinds[0]["hull"]).is_equal("secondary")
	var sec: Dictionary = _rt.snapshot()["ship"]["sif_idf"]
	assert_array(sec["degraded_hulls"]["idf"]).is_equal(["secondary"])
	# two backups-worth: 3 backup units cover both at 65% -> (2 + 1.3) / 4
	assert_float(sec["idf_strength"]).is_equal_approx(3.3 / 4.0, 0.01)
	assert_float(H.comp(_rt, "idf_grid")["demand"]).is_equal_approx(3.3 * 6.0, 0.01)


func test_backup_service_timer_only_ticks_for_backups_in_use() -> void:
	_rt = H.make()
	H.run(_rt, 50)
	assert_int(_rt.sif_idf._svc["idf_secondary"]).is_equal(432000)  # nothing lost, nothing aged
	_rt.send_debug({"type": "damage", "target": "idf_gen_e1", "amount": 100})
	_rt.send_debug({"type": "damage", "target": "idf_gen_e2", "amount": 100})
	H.run(_rt, 50)
	assert_int(_rt.sif_idf._svc["idf_secondary"]).is_less(432000)
	assert_int(_rt.sif_idf._svc["idf_primary"]).is_equal(432000)
	assert_int(_rt.sif_idf._svc["sif_primary"]).is_equal(432000)


func test_ladder_level_two_caps_impulse_to_a_safe_speed() -> void:
	_rt = H.make()
	H.run(_rt, 5)
	assert_bool(H.accepted(_rt, {"type": "set_impulse", "value": 0.8})).is_true()
	H.run(_rt, 80)
	assert_float(_rt.snapshot()["ship"]["propulsion"]["impulse"]).is_greater(0.7)
	for id in ["sif_gen_p1", "sif_gen_p2", "sif_gen_s1"]:
		_rt.send_debug({"type": "damage", "target": id, "amount": 100})
	H.run(_rt, 5)
	var s := _rt.snapshot()
	assert_int(s["ship"]["sif_idf"]["ladder"]).is_equal(2)
	assert_float(s["ship"]["sif_idf"]["speed_limit"]).is_equal_approx(0.2, 0.0001)
	assert_float(s["ship"]["propulsion"]["impulse"]).is_greater(0.5)  # it decelerates at the normal rate, it is not clamped at once (D-SIF-017)
	H.run(_rt, 40)
	assert_float(_rt.snapshot()["ship"]["propulsion"]["impulse"]).is_less(0.21)
	assert_bool(H.accepted(_rt, {"type": "set_impulse", "value": 0.5})).is_false()
	assert_bool(H.accepted(_rt, {"type": "set_impulse", "value": 0.1})).is_true()


# ---- F: reduced power exception ------------------------------------------------------------------------------

func test_reduced_power_keeps_a_core_that_is_the_only_power_source() -> void:
	_rt = H.make()
	H.run(_rt, 3)
	_rt.send_debug({"type": "damage", "target": "impulse_main", "amount": 100})
	H.run(_rt, 2)
	_rt.send({"type": "set_mode", "value": "reduced_power"})
	var kinds: Array = []
	for i in 10:
		_rt.step()
		for e: Dictionary in _rt.snapshot()["ship"]["events"]:
			kinds.append(e["type"])
	assert_str(H.comp(_rt, "warp_core")["state"]).is_equal("online")
	assert_array(kinds).contains(["core_kept"])


func test_yellow_and_red_never_cold_start_a_core() -> void:
	_rt = H.make(1, func(raw: Dictionary) -> void: H.set_state(raw, "warp_core", "cold"))
	H.run(_rt, 3)
	_rt.send({"type": "set_alert", "value": "red"})
	H.run(_rt, 50)
	assert_str(H.comp(_rt, "warp_core")["state"]).is_equal("cold")
	assert_str(_rt.snapshot()["ship"]["warp"]["stage"]).is_equal("cold")
