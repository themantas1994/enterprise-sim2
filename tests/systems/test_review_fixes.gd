extends GdUnitTestSuite
## Review fixes of step 7: Cruise preset sized for Warp 6, ratio curve, acceleration-based inertial cap, Reduced Power counts
## and integral warp, one shield generator per major section, saucer fuel, ledger ids in the ship file.

const H := preload("res://tests/systems/ship_helpers.gd")

var _rt: ShipRuntime


func after_test() -> void:
	if _rt != null:
		_rt.dispose()
		_rt = null


func _prop() -> Dictionary:
	return _rt.snapshot()["ship"]["propulsion"]


func _setpoint() -> float:
	return _rt.snapshot()["ship"]["warp"]["setpoint"]


func _go_to_warp(w: float) -> void:
	H.run(_rt, 5)
	assert_bool(H.accepted(_rt, {"type": "core_set_mode", "value": "warp"})).is_true()
	assert_bool(H.accepted(_rt, {"type": "set_warp", "value": w})).is_true()
	H.run(_rt, 200)
	assert_float(_prop()["warp"]).is_equal_approx(w, 0.001)


# ---- A: Cruise preset ---------------------------------------------------------------------------------------

func test_default_cruise_holds_warp_6_without_any_set_output() -> void:
	_rt = H.make()
	_go_to_warp(6.0)  # D-DESIGN-001: Warp 6 is the normal cruising speed
	H.run(_rt, 200)
	assert_float(_prop()["warp"]).is_equal_approx(6.0, 0.001)
	assert_float(_prop()["nacelle_power"]).is_greater(0.9)
	assert_float(_setpoint()).is_equal_approx(3250.0, 0.01)  # 0.65 x 5000 MW (core_frac_warp)


func test_yellow_and_red_to_green_at_warp_6_keep_warp() -> void:
	_rt = H.make()
	_go_to_warp(6.0)
	for level in ["yellow", "red"]:
		_rt.send({"type": "set_alert", "value": level})
		H.run(_rt, 40)
		assert_float(_prop()["warp"]).is_equal_approx(6.0, 0.001)
		_rt.send({"type": "set_alert", "value": "green"})
		H.run(_rt, 40)
		assert_float(_prop()["warp"]).is_equal_approx(6.0, 0.001)  # the return to Cruise does not reset the core to the sublight share
		assert_float(_setpoint()).is_equal_approx(3250.0, 0.01)


func test_sublight_cruise_shares_the_load_with_the_main_impulse_engines() -> void:
	_rt = H.make()
	H.run(_rt, 50)
	assert_float(_setpoint()).is_equal_approx(1500.0, 0.01)  # 0.3 x 5000 MW below warp
	assert_float(H.comp(_rt, "warp_core")["power"]).is_greater(1000.0)
	assert_float(H.comp(_rt, "impulse_main")["power"]).is_greater(100.0)
	# back to sublight after warp: the preset returns to the small core share
	_go_to_warp(6.0)
	_rt.send({"type": "set_warp", "value": 0.0})
	H.run(_rt, 300)
	assert_float(_setpoint()).is_equal_approx(1500.0, 0.01)
	assert_float(H.comp(_rt, "impulse_main")["power"]).is_greater(100.0)


func test_a_player_core_setting_replaces_the_cruise_preset_until_the_next_mode_change() -> void:
	_rt = H.make()
	H.run(_rt, 5)
	_rt.send({"type": "set_output", "target": "warp_core", "value": 2000})
	_rt.send({"type": "set_warp", "value": 0.0})
	H.run(_rt, 30)
	assert_float(_setpoint()).is_equal_approx(2000.0, 0.01)


# ---- B: ratio curve -----------------------------------------------------------------------------------------

func test_a_core_that_runs_at_start_generates_power_at_ten_to_one_with_full_output() -> void:
	_rt = H.make()
	H.run(_rt, 10)
	var w: Dictionary = _rt.snapshot()["ship"]["warp"]
	assert_float(w["ratio"]).is_equal_approx(10.0, 0.001)  # D-WARP-030
	assert_float(w["cap"]).is_equal_approx(1.0, 0.001)  # no output penalty at default settings


# ---- C: inertial cap acts on the acceleration ---------------------------------------------------------------

func _kill_idf() -> void:
	for id in ["idf_gen_p1", "idf_gen_p2", "idf_gen_p3", "idf_gen_p4", "idf_gen_e1", "idf_gen_e2", "idf_backup_primary", "idf_backup_secondary"]:
		_rt.send_debug({"type": "damage", "target": id, "amount": 100})


func _impulse_at(frac: float) -> void:
	assert_bool(H.accepted(_rt, {"type": "set_impulse", "value": frac})).is_true()
	H.run(_rt, int(frac / 0.02) + 5)
	assert_float(_prop()["impulse"]).is_equal_approx(frac, 0.0005)


func test_losing_the_fields_does_not_change_the_current_speed() -> void:
	_rt = H.make()
	H.run(_rt, 5)
	_impulse_at(0.2)
	_kill_idf()
	H.run(_rt, 10)
	assert_float(_rt.snapshot()["ship"]["sif_idf"]["accel_ratio"]).is_equal_approx(0.003, 0.0001)
	assert_float(_prop()["impulse"]).is_equal_approx(0.2, 0.0005)  # not clamped down to the inertial cap
	# asked to stop, the ship can shed only a sliver of speed
	assert_bool(H.accepted(_rt, {"type": "set_impulse", "value": 0.0})).is_true()
	H.run(_rt, 100)
	assert_float(_prop()["impulse"]).is_greater(0.19)


func test_the_slew_rate_scales_with_the_cap() -> void:
	var drop := {}
	for cap in [0.1, 0.4]:
		_rt = H.make(1, func(raw: Dictionary) -> void: raw["systems"]["sif"]["inertial_cap"]["value"] = cap)
		H.run(_rt, 5)
		_impulse_at(0.3)
		_kill_idf()
		H.run(_rt, 10)
		var before: float = _prop()["impulse"]
		_rt.send({"type": "set_impulse", "value": 0.0})
		H.run(_rt, 10)
		drop[cap] = before - _prop()["impulse"]
		_rt.dispose()
		_rt = null
	assert_float(drop[0.4] / drop[0.1]).is_equal_approx(4.0, 0.05)


func test_at_cap_zero_the_speed_holds() -> void:
	_rt = H.make(1, func(raw: Dictionary) -> void: raw["systems"]["sif"]["inertial_cap"]["value"] = 0.0)
	H.run(_rt, 5)
	_impulse_at(0.2)
	_kill_idf()
	H.run(_rt, 10)
	_rt.send({"type": "set_impulse", "value": 0.0})
	H.run(_rt, 300)
	assert_float(_prop()["impulse"]).is_equal_approx(0.2, 0.0001)  # D-SIF-026: no change for a long time


# ---- D, E: Reduced Power ------------------------------------------------------------------------------------

func test_reduced_power_runs_one_sif_and_one_idf_generator_and_alerts_run_all() -> void:
	_rt = H.make()
	H.run(_rt, 20)
	assert_float(H.comp(_rt, "sif_grid")["demand"]).is_equal_approx(2.0 * 240.0, 0.01)  # cruise: 1 per hull (D-SIF-013)
	assert_float(H.comp(_rt, "idf_grid")["demand"]).is_equal_approx(4.0 * 6.0, 0.01)  # cruise: 2 per hull (D-IDF-014)
	_rt.send({"type": "set_mode", "value": "reduced_power"})
	H.run(_rt, 20)
	assert_float(H.comp(_rt, "sif_grid")["demand"]).is_equal_approx(240.0, 0.01)  # one generator for the spaceframe (D-SIF-022)
	assert_float(H.comp(_rt, "idf_grid")["demand"]).is_equal_approx(6.0, 0.01)  # D-IDF-019
	_rt.send({"type": "set_mode", "value": "yellow_alert"})
	H.run(_rt, 20)
	assert_float(H.comp(_rt, "sif_grid")["demand"]).is_equal_approx(5.0 * 240.0, 0.01)
	assert_float(H.comp(_rt, "idf_grid")["demand"]).is_equal_approx(6.0 * 6.0, 0.01)


func test_reduced_power_keeps_one_field_generator_when_a_generator_is_lost() -> void:
	_rt = H.make()
	H.run(_rt, 5)
	_rt.send({"type": "set_mode", "value": "reduced_power"})
	_rt.send_debug({"type": "damage", "target": "sif_gen_p1", "amount": 100})
	H.run(_rt, 20)
	assert_str(_rt.snapshot()["ship"]["mode"]).is_equal("reduced_power")
	assert_float(H.comp(_rt, "sif_grid")["demand"]).is_equal_approx(240.0, 0.01)  # another generator carries the spaceframe
	assert_float(_rt.snapshot()["ship"]["sif_idf"]["sif_strength"]).is_greater(0.9)


func test_reduced_power_refuses_fractional_warp() -> void:
	_rt = H.make()
	H.run(_rt, 5)
	assert_bool(H.accepted(_rt, {"type": "core_set_mode", "value": "warp"})).is_true()
	assert_bool(H.accepted(_rt, {"type": "set_warp", "value": 3.0})).is_true()
	H.run(_rt, 100)
	assert_bool(H.accepted(_rt, {"type": "set_alert", "value": "green"})).is_true()
	_rt.send({"type": "set_mode", "value": "reduced_power"})
	H.run(_rt, 5)
	assert_bool(H.accepted(_rt, {"type": "set_warp", "value": 2.5})).is_false()  # D-MODE-026
	assert_bool(H.accepted(_rt, {"type": "set_warp", "value": 4.0})).is_true()


# ---- F: shield generators, one per major section ------------------------------------------------------------

func test_cruise_shields_run_one_generator_per_major_section() -> void:
	_rt = H.make()
	H.run(_rt, 20)
	var act: Array = _rt.snapshot()["ship"]["shields"]["active_generators"]
	assert_array(act).has_size(3)
	assert_array(act).contains_exactly_in_any_order(["shield_gen_p1", "shield_gen_s1", "shield_gen_np1"])  # primary hull, secondary hull, nacelles (D-SHLD-025)
	_rt.send_debug({"type": "damage", "target": "shield_gen_p1", "amount": 100})
	H.run(_rt, 5)
	act = _rt.snapshot()["ship"]["shields"]["active_generators"]
	assert_array(act).contains_exactly_in_any_order(["shield_gen_p2", "shield_gen_s1", "shield_gen_np1"])  # the next one of the same section


# ---- G: saucer fuel -----------------------------------------------------------------------------------------

func test_the_saucer_holds_32_tanks_of_113_m3() -> void:
	_rt = H.make()
	H.run(_rt, 5)
	assert_float(_rt.snapshot()["ship"]["fuel"]["deuterium_aux_m3"]).is_equal_approx(3616.0, 0.5)  # D-IMP-017, D-IMP-005
	var tank: Dictionary = {}
	for d: Dictionary in _rt.raw["junctions"]:
		if d["id"] == "deuterium_aux_saucer":
			tank = d
	assert_int(int(tank["tanks"]["value"])).is_equal(32)
	assert_float(float(tank["volume_m3"]["value"])).is_equal_approx(32.0 * 113.0, 0.5)


# ---- H: ledger ids and counts -------------------------------------------------------------------------------

func test_items_carry_their_own_count_not_the_ledger_total() -> void:
	_rt = H.make()
	var n := 0
	for d: Dictionary in _rt.raw["junctions"]:
		if str(d["id"]).begins_with("warp_injector_") or str(d["id"]).begins_with("dc_team_"):
			assert_int(int(d["count"]["value"])).is_equal(1)
			n += 1
	assert_int(n).is_equal(13)  # 6 matter + 3 antimatter injectors and 4 teams
	assert_dict(_rt.raw["notes"]["documented_simplifications"]).has_size(8)
