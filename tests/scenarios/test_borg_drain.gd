extends GdUnitTestSuite
## borg_drain: rotating frequency and modulation holds the shields; doing nothing collapses shields and power.

const H := preload("res://tests/systems/ship_helpers.gd")
const ROTATION := [[100, 900], [700, 200], [300, 600], [900, 50], [500, 950], [50, 400], [800, 800], [250, 100]]

var _rt: ShipRuntime


func before_test() -> void:
	_rt = H.make(7)
	assert_bool(_rt.start_scenario("borg_drain")).is_true()


func after_test() -> void:
	_rt.dispose()


func _sc() -> Dictionary:
	return _rt.snapshot()["ship"]["scenario"]


func _rotate_and_run(rt: ShipRuntime, period: int, ticks: int) -> void:
	var k := 0
	for t in ticks:
		if period > 0 and t % period == 1:
			var p: Array = ROTATION[k % ROTATION.size()]
			k += 1
			rt.send({"type": "shield_set", "frequency": p[0], "modulation": p[1]})
		rt.step()
		if rt.snapshot()["ship"]["scenario"]["status"] != "running":
			return


func test_starts_at_red_alert_with_shields_up_and_a_timer() -> void:
	H.run(_rt, 10)
	var s: Dictionary = _rt.snapshot()
	assert_str(s["ship"]["alert"]).is_equal("red")
	assert_float(s["ship"]["shields"]["strength"]).is_greater(0.8)
	assert_bool(s["ship"]["shields"]["borg"]["active"]).is_false()
	assert_int(_sc()["time_left"]).is_between(1400, 1500)
	H.run(_rt, 40)
	assert_bool(_rt.snapshot()["ship"]["shields"]["borg"]["active"]).is_true()


func test_win_by_rotating_frequency_and_modulation() -> void:
	_rotate_and_run(_rt, 20, 1600)
	assert_str(_sc()["status"]).is_equal("won")
	assert_float(_rt.snapshot()["ship"]["shields"]["strength"]).is_greater(0.3)
	assert_str(_sc()["reason"]).contains("shields held")
	assert_int(_sc()["time_left"]).is_equal(0)


func test_lose_by_keeping_one_setting() -> void:
	var n := H.run_until(_rt, func() -> bool: return _sc()["status"] != "running", 1600)
	assert_int(n).is_less(1600)
	assert_str(_sc()["status"]).is_equal("lost")
	assert_str(_sc()["reason"]).contains("collapsed")
	assert_float(_rt.snapshot()["ship"]["shields"]["strength"]).is_less(0.05)


func test_rotating_too_slowly_is_not_enough() -> void:
	_rotate_and_run(_rt, 90, 1600)
	assert_str(_sc()["status"]).is_equal("lost")


func test_power_is_drained_while_the_shields_are_down_and_the_backup_sources_are_out_of_reach() -> void:
	H.run(_rt, 20)
	var before: float = H.comp(_rt, "warp_core")["power"]
	assert_float(before).is_greater(3000.0)
	H.run_until(_rt, func() -> bool: return _rt.shields.strength < 0.1, 800)
	H.run(_rt, 400)
	var s: Dictionary = _rt.snapshot()
	assert_float(s["components"]["warp_core"]["power"]).is_less(before * 0.5)
	# bringing the saucer reactors online (reroute) puts supply beyond the cube's reach
	_rt.send({"type": "reactor_online", "target": "impulse_saucer_1"})
	_rt.send({"type": "reactor_online", "target": "impulse_saucer_2"})
	H.run(_rt, 5)
	assert_float(H.comp(_rt, "impulse_saucer_1")["power"]).is_greater(100.0)


func test_status_stays_final_and_same_seed_same_run() -> void:
	var other := H.make(7)
	other.start_scenario("borg_drain")
	_rotate_and_run(_rt, 20, 300)
	_rotate_and_run(other, 20, 300)
	assert_str(H.fingerprint(_rt)).is_equal(H.fingerprint(other))
	other.dispose()
	var third := H.make(8)
	third.start_scenario("borg_drain")
	_rotate_and_run(third, 20, 300)
	assert_str(H.fingerprint(third)).is_not_equal(H.fingerprint(_rt))
	third.dispose()
	assert_array(_rt.missing_tunes).is_empty()
