extends GdUnitTestSuite
## Headless smoke tests of the panel scenes against a fake runtime and a fixture panel map.
## Touch-target rule: every interactive node (buttons, sliders, anything in the group "touch_target") is at
## least 48 dp in both directions at 1280x720 and at the 6 inch phone landscape (864x432 dp).

const F := preload("res://tests/ui/ui_fixtures.gd")
const FakeRuntime := preload("res://tests/ui/fake_runtime.gd")
const HostScript := preload("res://ui/sim_host.gd")
const PANELS := ["msd", "warp_core", "fuel", "eps", "shields", "impulse", "sif_idf", "damage_control"]
const HOST_API := ["snapshot", "prev", "snapshot_ready", "scenario_changed", "panel_ids", "panel_title", "panel_components", "all_ids", "power_unit", "send", "scenario_ids", "start_scenario"]


func after_test() -> void:
	UiScale.clear_override()


func _host() -> Array:
	var rt := FakeRuntime.new(F.components())
	var host: Node = auto_free(HostScript.new())
	host.auto_start = false
	host.use_runtime(rt, F.MAP, "MW")
	return [host, rt]


func _viewport(size_key: String) -> SubViewport:
	var cfg: Array = F.SIZES[size_key]
	UiScale.set_override(cfg[1], cfg[2])
	var vp := SubViewport.new()
	vp.size = cfg[0]
	vp.disable_3d = true
	add_child(vp)
	return auto_free(vp)


func _mount(panel_id: String, size_key: String) -> Array:
	var vp := _viewport(size_key)
	var hr := _host()
	var scene: PackedScene = load("res://ui/panels/panel_%s.tscn" % panel_id)
	var panel: PanelBase = scene.instantiate()
	panel.host = hr[0]
	vp.add_child(panel)
	for i in 3:
		await get_tree().process_frame
	return [panel, hr[1], hr[0], vp]


func _walk(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children():
		_walk(c, out)


func _touch_targets(root: Node) -> Array:
	var all: Array = []
	_walk(root, all)
	return all.filter(func(n: Node) -> bool: return n is Control and (n is BaseButton or n is Range or n.is_in_group("touch_target")) and (n as Control).is_visible_in_tree())


# --- panels ----------------------------------------------------------------------

func test_every_panel_shows_a_tile_for_each_id_of_its_map() -> void:
	for pid: String in PANELS:
		var m := await _mount(pid, "desktop")
		var panel: PanelBase = m[0]
		var shown: Array = panel.tile_keys()
		assert_bool(shown.size() > 0).override_failure_message(pid + " has no tiles").is_true()
		for id: String in F.MAP[pid]["components"]:
			var covered := shown.has(id)
			if not covered:
				for k: String in shown:
					if k.ends_with("_*") and id.begins_with(k.trim_suffix("*")):
						covered = true
			assert_bool(covered).override_failure_message("%s: no tile for %s" % [pid, id]).is_true()
		for k: String in shown:
			assert_str(panel.tile(k).caption).is_not_empty()


func test_a_button_press_sends_a_command_through_the_host() -> void:
	for pid: String in PANELS:
		var m := await _mount(pid, "desktop")
		var panel: PanelBase = m[0]
		var rt = m[1]
		var map_ids: Array = F.MAP[pid]["components"]
		var sent := false
		for id: String in map_ids:
			panel.select(id)
			await get_tree().process_frame
			var all: Array = []
			_walk(panel, all)
			for n in all:
				if n is PanelButton and not (panel.tile_keys().has(n.name) or n.get_parent() is HFlowContainer) and n.is_visible_in_tree():
					n.pressed.emit()
					if rt.commands.size() > 0:
						sent = true
						break
			if sent:
				break
		assert_bool(sent).override_failure_message(pid + " sent no command").is_true()
		for cmd: Dictionary in rt.commands:
			assert_str(str(cmd["type"])).is_not_empty()
			if cmd.has("target") and pid != "msd" and pid != "damage_control":
				assert_array(map_ids).contains([cmd["target"]])


func test_msd_alert_buttons_and_situation_monitor() -> void:
	var m := await _mount("msd", "desktop")
	var rt = m[1]
	var all: Array = []
	_walk(m[0], all)
	var red: PanelButton
	for n in all:
		if n is PanelButton and n.caption == "RED ALERT":
			red = n
	assert_object(red).is_not_null()
	red.pressed.emit()
	assert_dict(rt.commands[0]).is_equal({"type": "set_alert", "value": "red"})
	# The situation monitor lists off-nominal ids of the whole map (eps_trunk_b is only in the eps entry).
	var names: Array = []
	for n in all:
		if n is PanelButton and str(n.name).begins_with("row_"):
			names.append(str(n.name))
	assert_array(names).contains(["row_eps_trunk_b", "row_idf_gen_p1"])
	assert_array(names).not_contains(["row_decoy_zz"])


func test_damage_control_queue_repairs_through_the_host_and_hides_foreign_ids() -> void:
	var m := await _mount("damage_control", "desktop")
	var rt = m[1]
	var all: Array = []
	_walk(m[0], all)
	var rows: Array = all.filter(func(n: Node) -> bool: return n is PanelButton and str(n.name).begins_with("row_"))
	var row_names := rows.map(func(n: Node) -> String: return str(n.name))
	assert_array(row_names).contains(["row_eps_trunk_b"])
	assert_array(row_names).not_contains(["row_decoy_zz"])
	for r: PanelButton in rows:
		if r.name == "row_eps_trunk_b":
			r.pressed.emit()
	assert_dict(rt.commands[0]).is_equal({"type": "repair", "target": "eps_trunk_b"})


func test_panels_ignore_ids_outside_the_map() -> void:
	var m := await _mount("shields", "desktop")
	var panel: PanelBase = m[0]
	assert_dict(panel.comp("decoy_zz")).is_empty()
	assert_dict(panel.comp("eps_trunk_a")).is_empty()
	panel.select("decoy_zz")
	assert_str(panel.selected).is_empty()


func test_reactor_eject_needs_a_second_press() -> void:
	var m := await _mount("warp_core", "desktop")
	var panel: PanelBase = m[0]
	var rt = m[1]
	panel.select("warp_core")
	await get_tree().process_frame
	var all: Array = []
	_walk(panel, all)
	var eject: PanelButton
	for n in all:
		if n is PanelButton and str(n.caption).contains("EJECT"):
			eject = n
	assert_object(eject).is_not_null()
	eject.pressed.emit()
	assert_int(rt.commands.size()).is_equal(0)
	eject.pressed.emit()
	assert_dict(rt.commands[0]).is_equal({"type": "reactor_eject", "target": "warp_core"})


func test_rejected_command_is_shown() -> void:
	var m := await _mount("eps", "desktop")
	var panel: PanelBase = m[0]
	m[1].comps["reject_me"] = F.comp("conduit", "ok", {"cut": false})
	panel.ids.append("reject_me")
	panel.wide_ids.append("reject_me")
	panel.selected = "reject_me"
	panel._on_snapshot(panel.host.snapshot, {})
	panel._send({"type": "cut_conduit", "target": "reject_me"})
	assert_str(panel._feedback.value_text).contains("REJECTED")


# --- sizes ----------------------------------------------------------------------------

func test_touch_targets_are_at_least_48_dp_at_both_test_sizes() -> void:
	for size_key: String in F.SIZES:
		for pid: String in PANELS:
			var m := await _mount(pid, size_key)
			var panel: PanelBase = m[0]
			var vp: SubViewport = m[3]
			assert_vector(panel.size).is_equal(Vector2(vp.size))
			var min_px := UiScale.dp(48.0)
			var count := 0
			for pass_id: String in [panel.ids[0], panel.ids[-1]]:
				panel.select(pass_id)
				await get_tree().process_frame
				await get_tree().process_frame
				for n: Control in _touch_targets(panel):
					count += 1
					assert_bool(n.size.x >= min_px - 0.5 and n.size.y >= min_px - 0.5).override_failure_message("%s @ %s: %s is %s, needs %s" % [pid, size_key, n.get_path(), n.size, min_px]).is_true()
			assert_bool(count > 0).is_true()


func test_dp_scale_matches_the_phone_numbers() -> void:
	UiScale.set_override(2.5, 1.5)
	# 48 dp = 120 px at density 2.5 = 80 layout units at 1.5 px per unit.
	assert_float(UiScale.touch_min()).is_equal_approx(80.0, 0.01)
	assert_float(1440.0 / UiScale.dp(1.0)).is_equal_approx(864.0, 0.01)
	UiScale.set_override(1.0, 1.0)
	assert_float(UiScale.touch_min()).is_equal_approx(48.0, 0.01)


# --- static rules -------------------------------------------------------------------------

func _panel_sources() -> Dictionary:
	var out := {}
	var dir := DirAccess.open("res://ui/panels")
	for f in dir.get_files():
		if f.begins_with("panel_") and f.ends_with(".gd"):
			out[f] = FileAccess.get_file_as_string("res://ui/panels/" + f)
	return out


func test_panel_scripts_use_no_id_outside_their_map() -> void:
	var re := RegEx.new()
	re.compile("\"([a-z0-9_]+)\"")
	var sources := _panel_sources()
	for pid: String in PANELS:
		var own: Array = F.MAP[pid]["components"]
		var src: String = sources["panel_%s.gd" % pid]
		for mt in re.search_all(src):
			var lit := mt.get_string(1)
			for other: String in PANELS:
				if other != pid and F.MAP[other]["components"].has(lit):
					assert_array(own).override_failure_message("panel_%s.gd names %s, which is not in its map" % [pid, lit]).contains([lit])
	var base: String = sources["panel_base.gd"]
	for mt in re.search_all(base):
		for pid: String in PANELS:
			assert_bool(F.MAP[pid]["components"].has(mt.get_string(1))).override_failure_message("panel_base.gd names the id " + mt.get_string(1)).is_false()


func test_ui_scripts_use_only_the_public_host_interface() -> void:
	var re := RegEx.new()
	re.compile("host\\.([A-Za-z_][A-Za-z0-9_]*)")
	var files: Array = []
	for d in ["res://ui/panels", "res://ui"]:
		var dir := DirAccess.open(d)
		for f in dir.get_files():
			if f.ends_with(".gd") and f != "sim_host.gd":
				files.append(d + "/" + f)
	for path: String in files:
		var src := FileAccess.get_file_as_string(path)
		for mt in re.search_all(src):
			assert_array(HOST_API).override_failure_message("%s uses host.%s" % [path, mt.get_string(1)]).contains([mt.get_string(1)])
		for banned in ["_runtime", "ShipRuntime", "Sim.new", "/root/SimHost\").call"]:
			assert_bool(src.contains(banned)).override_failure_message("%s mentions %s" % [path, banned]).is_false()


# --- host, menu, banner, shell ---------------------------------------------------------------

func test_host_steps_at_10_hz_and_orders_panels() -> void:
	var hr := _host()
	var host: Node = hr[0]
	assert_int(host.advance(0.05)).is_equal(0)
	assert_int(host.advance(0.06)).is_equal(1)
	assert_int(host.advance(0.2)).is_equal(2)
	assert_int(hr[1].tick).is_equal(3)
	assert_array(host.panel_ids()).is_equal(PANELS)
	assert_array(host.panel_components("shields")).is_equal(F.MAP["shields"]["components"])
	assert_dict(host.send({"type": "set_alert", "value": "red"})).is_equal({"accepted": true})


func test_alert_levels_differ_by_shape_and_blink() -> void:
	var shapes := {}
	var periods := {}
	for level in ["green", "yellow", "red"]:
		var b := TngAlertBanner.new()
		auto_free(b)
		b.set_alert(level)
		shapes[b.shape()] = true
		periods[b.blink_period()] = true
		assert_str(b.text).is_not_empty()
		b.reduced_motion = true
		assert_float(b.blink_period()).is_equal(0.0)
	assert_int(shapes.size()).is_equal(3)
	assert_int(periods.size()).is_equal(3)


func test_station_menu_lists_panels_and_scenarios_and_shows_status() -> void:
	var vp := _viewport("desktop")
	var hr := _host()
	var menu := StationMenu.new()
	menu.host = hr[0]
	var requested: Array = []
	menu.panel_requested.connect(func(id: String) -> void: requested.append(id))
	vp.add_child(menu)
	for i in 3:
		await get_tree().process_frame
	for pid: String in PANELS:
		assert_object(menu.find_child("station_" + pid, true, false)).is_not_null()
	for sid in ["core_breach", "borg_drain", "coolant_leak"]:
		assert_object(menu.find_child("scenario_" + sid, true, false)).is_not_null()
	(menu.find_child("station_fuel", true, false) as PanelButton).pressed.emit()
	assert_array(requested).is_equal(["fuel"])
	(menu.find_child("scenario_borg_drain", true, false) as PanelButton).pressed.emit()
	assert_array(hr[1].started).is_equal(["borg_drain"])
	hr[1].scenario["status"] = "lost"
	hr[1].scenario["reason"] = "shields collapsed"
	hr[1].scenario["time_left"] = 125
	hr[0].step_once()
	await get_tree().process_frame
	var all: Array = []
	_walk(menu, all)
	var texts := all.filter(func(n: Node) -> bool: return n is Readout).map(func(n: Readout) -> String: return n.value_text)
	assert_array(texts).contains(["LOST", "SHIELDS COLLAPSED", "00:12"])


func test_main_scene_opens_the_station_menu_and_quick_tabs_switch_panels() -> void:
	var vp := _viewport("phone")
	var hr := _host()
	var main: Control = (load("res://ui/main.tscn") as PackedScene).instantiate()
	main.host = hr[0]
	vp.add_child(main)
	for i in 3:
		await get_tree().process_frame
	assert_str(main.current()).is_empty()
	assert_object(main.find_child("station_msd", true, false)).is_not_null()
	(main.find_child("tab_shields", true, false) as PanelButton).pressed.emit()
	await get_tree().process_frame
	assert_str(main.current()).is_equal("shields")
	(main.find_child("tab_menu", true, false) as PanelButton).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame   # queued frees of the replaced panel run at the end of a frame
	assert_str(main.current()).is_empty()
	for n: Control in _touch_targets(main):
		assert_bool(n.size.x >= UiScale.touch_min() - 0.5 and n.size.y >= UiScale.touch_min() - 0.5).override_failure_message("%s is %s" % [n.get_path(), n.size]).is_true()
