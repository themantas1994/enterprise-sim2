extends GdUnitTestSuite
## SIF and IDF: backups, the failure ladder D-SIF-016..018, forced downwarp and impulse limit.

const H := preload("res://tests/systems/ship_helpers.gd")

var _rt: ShipRuntime


func after_test() -> void:
	if _rt != null:
		_rt.dispose()
		_rt = null


func _kill(id: String) -> void:
	_rt.send({"type": "damage", "target": id, "amount": 100})


func _go_to_warp(w: float) -> void:
	H.run(_rt, 5)
	assert_bool(H.accepted(_rt, {"type": "core_set_mode", "value": "warp"})).is_true()
	assert_bool(H.accepted(_rt, {"type": "set_warp", "value": w})).is_true()
	H.run(_rt, 200)
	assert_float(_rt.propulsion.warp).is_equal_approx(w, 0.001)


func test_healthy_fields_have_no_ladder_and_cruise_uses_the_minimum_generators() -> void:
	_rt = H.make()
	H.run(_rt, 20)
	var s: Dictionary = _rt.snapshot()
	assert_int(s["ship"]["sif_idf"]["ladder"]).is_equal(0)
	assert_float(s["components"]["sif_grid"]["demand"]).is_equal_approx(480.0, 0.01)  # 2 x 20 x 12 MW (D-SIF-013)
	assert_float(s["components"]["idf_grid"]["demand"]).is_equal_approx(24.0, 0.01)  # 4 x 12 x 0.5 MW (D-IDF-014)
	_rt.send({"type": "set_alert", "value": "yellow"})
	H.run(_rt, 10)
	assert_float(H.comp(_rt, "sif_grid")["demand"]).is_equal_approx(1200.0, 0.01)  # all 5 generators
	assert_float(H.comp(_rt, "idf_grid")["demand"]).is_equal_approx(36.0, 0.01)


func test_one_lost_generator_is_covered_by_a_backup_at_55_percent() -> void:
	_rt = H.make()
	H.run(_rt, 10)
	_rt.send({"type": "set_alert", "value": "yellow"})
	H.run(_rt, 5)
	_kill("sif_gen_p1")
	H.run(_rt, 10)
	var s: Dictionary = _rt.snapshot()
	assert_int(s["ship"]["sif_idf"]["ladder"]).is_equal(0)
	assert_int(s["ship"]["sif_idf"]["sif_lost"]).is_equal(1)
	assert_float(s["components"]["sif_grid"]["demand"]).is_equal_approx((4.0 + 0.55) * 240.0, 0.01)
	assert_str(s["ship"]["alert"]).is_equal("yellow")


func test_two_lost_generators_force_yellow_alert() -> void:
	_rt = H.make()
	H.run(_rt, 10)
	assert_str(_rt.snapshot()["ship"]["alert"]).is_equal("green")
	_kill("sif_gen_p1")
	_kill("sif_gen_s1")
	var kinds: Array = []
	for i in 5:
		_rt.step()
		for e: Dictionary in _rt.snapshot()["ship"]["events"]:
			kinds.append(e["type"])
	var s: Dictionary = _rt.snapshot()
	assert_int(s["ship"]["sif_idf"]["ladder"]).is_equal(1)
	assert_str(s["ship"]["alert"]).is_equal("yellow")
	assert_str(s["ship"]["mode"]).is_equal("yellow_alert")
	assert_array(kinds).contains(["sif_ladder", "alert_forced"])


func test_three_lost_generators_drop_the_ship_out_of_warp_and_forbid_warp() -> void:
	_rt = H.make()
	_go_to_warp(6.0)
	_kill("sif_gen_p1")
	_kill("sif_gen_p2")
	_kill("sif_gen_s1")
	H.run(_rt, 5)
	var s: Dictionary = _rt.snapshot()
	assert_int(s["ship"]["sif_idf"]["ladder"]).is_equal(2)
	assert_float(s["ship"]["propulsion"]["warp"]).is_equal(0.0)
	assert_str(s["ship"]["alert"]).is_equal("yellow")
	var r := _rt.send({"type": "set_warp", "value": 3.0})
	assert_bool(r["accepted"]).is_false()
	assert_str(r["reason"]).contains("SIF")


func test_all_five_lost_is_red_alert_with_immediate_downwarp() -> void:
	_rt = H.make()
	_go_to_warp(6.0)
	for id in ["sif_gen_p1", "sif_gen_p2", "sif_gen_p3", "sif_gen_s1", "sif_gen_s2"]:
		_kill(id)
	H.run(_rt, 3)
	var s: Dictionary = _rt.snapshot()
	assert_int(s["ship"]["sif_idf"]["ladder"]).is_equal(3)
	assert_str(s["ship"]["alert"]).is_equal("red")
	assert_float(s["ship"]["propulsion"]["warp"]).is_equal(0.0)
	assert_float(s["ship"]["sif_idf"]["sif_strength"]).is_less(0.6)  # only backups left
	# without the fields impulse is held to a survivable acceleration (D-SIF-014, D-SIF-015)
	_kill("sif_backup_primary")
	_kill("sif_backup_secondary")
	H.run(_rt, 10)
	assert_float(_rt.snapshot()["ship"]["sif_idf"]["impulse_cap"]).is_equal_approx(0.003, 0.0001)
	assert_bool(H.accepted(_rt, {"type": "set_impulse", "value": 0.5})).is_false()
	assert_bool(H.accepted(_rt, {"type": "set_impulse", "value": 0.002})).is_true()


func test_a_lost_generator_without_a_backup_is_yellow_alert() -> void:
	_rt = H.make()
	H.run(_rt, 5)
	_kill("sif_backup_secondary")
	_kill("sif_gen_s1")
	H.run(_rt, 5)
	var s: Dictionary = _rt.snapshot()
	assert_int(s["ship"]["sif_idf"]["ladder"]).is_equal(1)  # D-SIF-016 "or no backup available"
	assert_str(s["ship"]["alert"]).is_equal("yellow")


func test_idf_follows_its_target_with_the_295_ms_lag() -> void:
	_rt = H.make()
	H.run(_rt, 10)
	for id in ["idf_gen_p1", "idf_gen_p2", "idf_gen_p3", "idf_gen_p4", "idf_gen_e1", "idf_gen_e2", "idf_backup_primary", "idf_backup_secondary"]:
		_kill(id)
	H.run(_rt, 2)
	var early: float = _rt.snapshot()["ship"]["sif_idf"]["idf_strength"]
	H.run(_rt, 40)
	var late: float = _rt.snapshot()["ship"]["sif_idf"]["idf_strength"]
	assert_float(early).is_between(0.05, 0.99)  # still falling after two ticks
	assert_float(late).is_less(0.01)
