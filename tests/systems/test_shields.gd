extends GdUnitTestSuite
## Shields: generators and backups, frequency and modulation, facing weights, Borg adaptation.

const H := preload("res://tests/systems/ship_helpers.gd")

var _rt: ShipRuntime


func after_test() -> void:
	if _rt != null:
		_rt.dispose()
		_rt = null


func _sh() -> Dictionary:
	return _rt.snapshot()["ship"]["shields"]


func test_cruise_runs_three_generators_at_five_percent_and_red_seven_at_85() -> void:
	_rt = H.make()
	H.run(_rt, 20)
	assert_int(_sh()["active_generators"].size()).is_equal(3)  # D-SHLD-011
	assert_float(H.comp(_rt, "shield_grid")["demand"]).is_equal_approx(3.0 * 384.0 * 0.05, 0.01)  # D-SHLD-012
	_rt.send({"type": "set_alert", "value": "red"})
	H.run(_rt, 20)
	assert_int(_sh()["active_generators"].size()).is_equal(7)  # D-SHLD-014
	assert_float(H.comp(_rt, "shield_grid")["demand"]).is_equal_approx(7.0 * 384.0 * 0.85, 0.01)  # D-SHLD-013, D-SHLD-015
	assert_float(_sh()["strength"]).is_greater(0.1)
	H.run(_rt, 300)
	assert_float(_sh()["strength"]).is_greater(0.95)  # the facings charge up to full


func test_lost_generators_are_covered_by_backups_at_65_percent() -> void:
	_rt = H.make()
	_rt.send({"type": "set_alert", "value": "red"})
	H.run(_rt, 10)
	_rt.send({"type": "damage", "target": "shield_gen_p1", "amount": 100})
	_rt.send({"type": "damage", "target": "shield_gen_p2", "amount": 100})
	H.run(_rt, 10)
	# the next intact generators take over from the 12; the backups only cover what is left over
	assert_int(_sh()["active_generators"].size()).is_equal(7)
	assert_int(_sh()["backup_units_used"]).is_equal(0)
	for id in ["shield_gen_p3", "shield_gen_p4", "shield_gen_p5", "shield_gen_s1", "shield_gen_s2", "shield_gen_s3", "shield_gen_np1", "shield_gen_np2", "shield_gen_ns1", "shield_gen_ns2"]:
		_rt.send({"type": "damage", "target": id, "amount": 100})
	H.run(_rt, 10)
	assert_int(_sh()["active_generators"].size()).is_equal(0)
	assert_int(_sh()["backup_units_used"]).is_equal(7)
	assert_float(H.comp(_rt, "shield_grid")["demand"]).is_equal_approx(7.0 * 0.65 * 384.0 * 0.85, 0.01)
	assert_float(_sh()["capacity"]).is_equal_approx(0.65, 0.001)
	_rt.send({"type": "damage", "target": "shield_backup_primary", "amount": 100})
	_rt.send({"type": "damage", "target": "shield_backup_secondary", "amount": 100})
	H.run(_rt, 400)
	assert_float(_sh()["strength"]).is_less(0.01)


func test_frequency_modulation_and_weights_commands() -> void:
	_rt = H.make()
	H.run(_rt, 3)
	assert_bool(H.accepted(_rt, {"type": "shield_set", "frequency": 321, "modulation": 654})).is_true()
	assert_bool(H.accepted(_rt, {"type": "shield_set", "frequency": 1000})).is_false()
	assert_bool(H.accepted(_rt, {"type": "shield_set", "frequency": -1})).is_false()
	assert_bool(H.accepted(_rt, {"type": "shield_set", "frequency": 1.5})).is_false()
	assert_int(_sh()["frequency"]).is_equal(321)
	assert_int(_sh()["modulation"]).is_equal(654)
	assert_bool(H.accepted(_rt, {"type": "shield_set_weights", "fore": 2, "aft": 1, "port": 1, "stbd": 0})).is_true()
	assert_float(_sh()["weights"]["fore"]).is_equal_approx(0.5, 0.001)
	assert_float(_sh()["weights"]["stbd"]).is_equal(0.0)
	assert_bool(H.accepted(_rt, {"type": "shield_set_weights", "fore": 0, "aft": 0, "port": 0, "stbd": 0})).is_false()
	assert_bool(H.accepted(_rt, {"type": "shield_set_level", "value": 2.0})).is_false()
	assert_bool(H.accepted(_rt, {"type": "shield_set_level", "value": 1.0})).is_true()


func test_weights_move_strength_between_facings() -> void:
	_rt = H.make()
	_rt.send({"type": "set_alert", "value": "red"})
	_rt.send({"type": "shield_set_weights", "fore": 3, "aft": 1, "port": 1, "stbd": 1})
	H.run(_rt, 400)
	var lv: Dictionary = _sh()["levels"]
	assert_float(lv["fore"]).is_greater(0.99)
	assert_float(lv["aft"]).is_less(lv["fore"])
	assert_float(lv["aft"]).is_equal_approx(4.0 / 6.0, 0.02)


func test_borg_adapts_to_a_constant_setting_in_a_few_shots_and_loses_it_when_it_changes() -> void:
	_rt = H.make(3)
	_rt.send({"type": "set_alert", "value": "red"})
	H.run(_rt, 400)
	_rt.shields.start_borg()
	assert_bool(_sh()["borg"]["active"]).is_true()
	H.run(_rt, 15 * 4)  # a few shots (D-BORG-001)
	assert_float(_sh()["borg"]["match"]).is_equal_approx(1.0, 0.001)
	var strength_before: float = _sh()["strength"]
	_rt.send({"type": "shield_set", "frequency": (_sh()["frequency"] + 500) % 1000, "modulation": (_sh()["modulation"] + 500) % 1000})
	H.run(_rt, 1)
	assert_float(_sh()["borg"]["match"]).is_equal(0.0)  # the old adaptation is useless against a new setting
	H.run(_rt, 15 * 3)
	assert_float(_sh()["borg"]["match"]).is_equal_approx(1.0, 0.001)  # and it catches up again
	assert_float(strength_before).is_less(1.0)  # shots drain every facing in steps (D-BORG-003)


func test_borg_drain_depends_on_the_match() -> void:
	var drained: Array = []
	for rotate in [false, true]:
		var rt := H.make(3)
		rt.send({"type": "set_alert", "value": "red"})
		H.run(rt, 400)
		rt.shields.start_borg()
		for t in 300:
			if rotate and t % 20 == 1:
				rt.send({"type": "shield_set", "frequency": (t * 377) % 1000, "modulation": (t * 613) % 1000})
			rt.step()
		drained.append(rt.snapshot()["ship"]["shields"]["strength"])
		rt.dispose()
	assert_float(drained[0]).is_less(0.2)  # constant setting: the shields fall
	assert_float(drained[1]).is_greater(0.6)  # rotating setting: they hold


func test_shield_power_cuts_warp_coupling() -> void:
	_rt = H.make()
	H.run(_rt, 3)
	_rt.send({"type": "core_set_mode", "value": "warp"})
	_rt.send({"type": "set_warp", "value": 6.0})
	H.run(_rt, 150)
	var nac_cruise: float = H.comp(_rt, "warp_nacelle_port")["demand"]
	_rt.send({"type": "set_alert", "value": "red"})
	H.run(_rt, 30)
	var nac_red: float = H.comp(_rt, "warp_nacelle_port")["demand"]
	assert_float(nac_red).is_greater(nac_cruise)  # D-SHLD-020: shields cost up to 32% of the coupling
