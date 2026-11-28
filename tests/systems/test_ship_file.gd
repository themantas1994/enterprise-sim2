extends GdUnitTestSuite
## The ship file: loads, carries every id of ADR 0002, panel map, source rules.

const H := preload("res://tests/systems/ship_helpers.gd")

var _rt: ShipRuntime


func after_test() -> void:
	if _rt != null:
		_rt.dispose()
		_rt = null


func _expected_ids() -> Array:
	var ids: Array = ["warp_core", "coolant_core", "coolant_eps", "deuterium_tank_main", "deuterium_aux_saucer", "antimatter_generator"]
	for i in range(1, 7):
		ids.append("warp_injector_matter_%d" % i)
	for i in range(1, 4):
		ids.append("warp_injector_antimatter_%d" % i)
	ids.append_array(["warp_constrictor_upper", "warp_constrictor_lower", "warp_dilithium_frame", "warp_nacelle_port", "warp_nacelle_stbd"])
	for i in range(1, 31):
		ids.append("antimatter_pod_%02d" % i)
	ids.append_array(["impulse_main", "impulse_saucer_1", "impulse_saucer_2", "aux_fusion_1", "aux_fusion_2", "impulse_drive"])
	ids.append_array(["eps_trunk_a", "eps_trunk_b", "eps_cross_link", "eps_sub_saucer", "eps_sub_engineering", "eps_sub_nacelle", "eps_sub_weapons"])
	ids.append_array(["shield_grid", "shield_backup_primary", "shield_backup_secondary", "sif_grid", "sif_backup_primary", "sif_backup_secondary"])
	ids.append_array(["idf_grid", "idf_backup_primary", "idf_backup_secondary"])
	for g in ["p1", "p2", "p3", "p4", "p5", "s1", "s2", "s3", "np1", "np2", "ns1", "ns2"]:
		ids.append("shield_gen_" + g)
	for g in ["p1", "p2", "p3", "s1", "s2"]:
		ids.append("sif_gen_" + g)
	for g in ["p1", "p2", "p3", "p4", "e1", "e2"]:
		ids.append("idf_gen_" + g)
	ids.append_array(["nav_deflector", "phaser_array", "life_support", "computer_core_p1", "computer_core_p2", "computer_core_e1"])
	for i in range(1, 5):
		ids.append("dc_team_%d" % i)
	return ids


func test_ship_file_loads_and_is_valid() -> void:
	_rt = H.make()
	assert_bool(_rt.valid).is_true()
	assert_array(_rt.errors).is_empty()
	assert_str(str(_rt.raw["power_unit"])).is_equal("MW")


func test_every_contract_id_exists_and_ids_are_snake_case() -> void:
	_rt = H.make()
	var comps: Dictionary = _rt.snapshot()["components"]
	for id: String in _expected_ids():
		assert_bool(comps.has(id)).override_failure_message("missing id " + id).is_true()
	var re := RegEx.new()
	re.compile("^[a-z0-9_]+$")
	for id: String in comps:
		assert_bool(re.search(id) != null).override_failure_message("bad id " + id).is_true()


func test_counts_follow_the_ledger() -> void:
	_rt = H.make()
	var comps: Dictionary = _rt.snapshot()["components"]
	var n := {"antimatter_pod_": 0, "shield_gen_": 0, "sif_gen_": 0, "idf_gen_": 0, "warp_injector_matter_": 0, "warp_injector_antimatter_": 0, "dc_team_": 0}
	for id: String in comps:
		for prefix: String in n:
			if id.begins_with(prefix):
				n[prefix] += 1
	assert_int(n["antimatter_pod_"]).is_equal(30)  # D-FUEL-001
	assert_int(n["shield_gen_"]).is_equal(12)  # D-SHLD-001..003
	assert_int(n["sif_gen_"]).is_equal(5)  # D-SIF-001, D-SIF-002
	assert_int(n["idf_gen_"]).is_equal(6)  # D-IDF-001, D-IDF-002
	assert_int(n["warp_injector_matter_"]).is_equal(6)  # D-WARP-001
	assert_int(n["warp_injector_antimatter_"]).is_equal(3)  # D-WARP-004
	assert_int(n["dc_team_"]).is_equal(4)  # D-DMG-001


func test_impulse_engine_counts_and_eps_sources_follow_the_manual() -> void:
	_rt = H.make()
	var comps: Dictionary = _rt.snapshot()["components"]
	var by_id := {}
	for p: Dictionary in _rt.raw["producers"]:
		by_id[p["id"]] = p
	assert_int(int(by_id["impulse_main"]["engines"]["value"])).is_equal(4)  # D-IMP-009
	assert_int(int(by_id["impulse_saucer_1"]["engines"]["value"]) + int(by_id["impulse_saucer_2"]["engines"]["value"])).is_equal(4)  # D-IMP-009: 2 groups of 2
	for id: String in ["impulse_main", "impulse_saucer_1", "impulse_saucer_2"]:
		assert_int(int(by_id[id]["chambers_per_engine"]["value"])).is_equal(3)  # D-IMP-009
	# D-EPS-001: no emergency battery feeds the EPS grid
	assert_bool(comps.has("battery_emergency")).is_false()
	assert_bool(comps.has("feed_battery")).is_false()
	for s: Dictionary in _rt.raw.get("stores", []):
		assert_bool(str(s["id"]).contains("battery")).is_false()


func test_panel_map_ids_all_exist_and_follow_the_adr_order() -> void:
	_rt = H.make()
	var panels: Dictionary = _rt.data["panels"]
	assert_array(panels.keys()).is_equal(["msd", "warp_core", "fuel", "eps", "shields", "impulse", "sif_idf", "damage_control"])
	var comps: Dictionary = _rt.snapshot()["components"]
	for pid: String in panels:
		assert_str(str(panels[pid]["title"])).is_not_empty()
		assert_array(panels[pid]["components"]).is_not_empty()
		for id: String in panels[pid]["components"]:
			assert_bool(comps.has(id)).override_failure_message("panel %s lists unknown id %s" % [pid, id]).is_true()
	assert_array(_rt.panel_components("warp_core")).contains(["warp_core", "warp_injector_matter_6", "warp_nacelle_stbd", "coolant_core"])
	assert_array(_rt.panel_components("fuel")).contains(["antimatter_pod_30", "deuterium_aux_saucer", "antimatter_generator"])


func test_every_value_has_a_source_and_estimates_have_a_reason() -> void:
	var raw := ShipData.read_file(H.SHIP)
	var wrappers := ShipData.wrappers(raw)
	assert_int(wrappers.size()).is_greater(100)
	var re := RegEx.new()
	re.compile("^(estimate|D-[A-Z]+-[0-9]{3}(, D-[A-Z]+-[0-9]{3})*)$")
	for w: Dictionary in wrappers:
		assert_bool(re.search(str(w["source"])) != null).override_failure_message("bad source at %s: %s" % [w["path"], w["source"]]).is_true()
		if w["source"] == "estimate":
			assert_str(str(w["reason"])).override_failure_message("estimate without reason at " + w["path"]).is_not_empty()


func test_unverified_impulse_row_is_not_used() -> void:
	var text := FileAccess.get_file_as_string(H.SHIP)
	assert_bool(text.contains("D-IMP-004")).is_false()


func test_ledger_ids_cited_in_the_ship_file_exist_in_the_ledger() -> void:
	var ledger := FileAccess.get_file_as_string("res://docs/sources.md")
	var re := RegEx.new()
	re.compile("D-[A-Z]+-[0-9]{3}")
	var seen := {}
	for m in re.search_all(FileAccess.get_file_as_string(H.SHIP)):
		seen[m.get_string()] = true
	assert_int(seen.size()).is_greater(50)
	for id: String in seen:
		assert_bool(ledger.contains("| %s |" % id)).override_failure_message("not in the ledger: " + id).is_true()


func _ledger_status() -> Dictionary:
	var out := {}
	for line in FileAccess.get_file_as_string("res://docs/sources.md").split("\n"):
		if not line.begins_with("| D-"):
			continue
		var cells := line.split("|")
		out[cells[1].strip_edges()] = cells[cells.size() - 2].strip_edges()
	return out


func test_every_non_estimate_source_is_a_verified_ledger_row_and_estimates_use_the_word() -> void:
	var status := _ledger_status()
	assert_int(status.size()).is_greater(100)
	for w: Dictionary in ShipData.wrappers(ShipData.read_file(H.SHIP)):
		var src := str(w["source"])
		if src == "estimate":
			continue
		for id in src.split(","):
			var key := id.strip_edges()
			assert_bool(status.has(key)).override_failure_message("%s: %s not in the ledger" % [w["path"], key]).is_true()
			assert_str(str(status.get(key, ""))).override_failure_message("%s cites %s which is %s, not verified" % [w["path"], key, status.get(key, "")]).is_equal("verified")


func test_breach_countdown_is_an_estimate_citing_d_core_005() -> void:
	var raw := ShipData.read_file(H.SHIP)
	var def: Dictionary = H.producer_def(raw, "warp_core")
	assert_str(str(def["breach_ticks"]["source"])).is_equal("estimate")
	assert_str(str(def["breach_ticks"]["reason"])).contains("D-CORE-005")
	assert_str(str(def["critical_integrity"]["source"])).is_equal("estimate")
