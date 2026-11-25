extends GdUnitTestSuite
## Headless smoke tests of the panel scenes against a fake runtime and a fixture panel map.
## Touch-target rule: every interactive node (buttons, sliders, anything in the group "touch_target") is at
## least 48 dp in both directions at 1280x720 and at the 6 inch phone landscape (864x432 dp).

const F := preload("res://tests/ui/ui_fixtures.gd")
const FakeRuntime := preload("res://tests/ui/fake_runtime.gd")
const HostScript := preload("res://ui/sim_host.gd")
const PANELS := ["msd", "warp_core", "fuel", "eps", "shields", "impulse", "sif_idf", "damage_control"]
const HOST_API := ["snapshot", "prev", "snapshot_ready", "scenario_changed", "panel_ids", "panel_title", "panel_components", "all_ids", "power_unit", "send", "scenario_ids", "start_scenario", "load_errors", "has_runtime"]


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
				if n is PanelButton and not panel._schematic.nodes.values().has(n) and n.is_visible_in_tree():
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


func test_damage_control_assigns_a_team_and_never_repairs_directly() -> void:
	var m := await _mount("damage_control", "desktop")
	var panel: PanelBase = m[0]
	var rt = m[1]
	rt.ship_extra = {"damage_control": {"teams": {"dc_team_1": {"state": "idle", "target": "", "left": 0, "done": 0}, "dc_team_2": {"state": "idle", "target": "", "left": 0, "done": 0}},
		"queue": [{"id": "eps_trunk_b", "integrity": 40.0, "state": "ok", "repairable": true, "team": "", "eta": 120}, {"id": "decoy_zz", "integrity": 0.0, "state": "destroyed", "repairable": true, "team": "", "eta": 10}]}}
	m[2].step_once()
	var all: Array = []
	_walk(panel, all)
	var rows: Array = all.filter(func(n: Node) -> bool: return n is PanelButton and str(n.name).begins_with("row_"))
	var row_names := rows.map(func(n: Node) -> String: return str(n.name))
	assert_array(row_names).contains(["row_eps_trunk_b"])
	assert_array(row_names).not_contains(["row_decoy_zz"])
	panel.tile("dc_team_2").pressed.emit()
	for r: PanelButton in rows:
		if r.name == "row_eps_trunk_b":
			r.pressed.emit()
	assert_dict(rt.commands[0]).is_equal({"type": "assign_team", "team": "dc_team_2", "target": "eps_trunk_b"})
	(panel.find_child("ctl_recall", true, false) as PanelButton).pressed.emit()
	assert_dict(rt.commands[1]).is_equal({"type": "recall_team", "team": "dc_team_2"})


func test_panels_ignore_ids_outside_the_map() -> void:
	var m := await _mount("shields", "desktop")
	var panel: PanelBase = m[0]
	assert_dict(panel.comp("decoy_zz")).is_empty()
	assert_dict(panel.comp("eps_trunk_a")).is_empty()
	panel.select("decoy_zz")
	assert_str(panel.selected).is_not_equal("decoy_zz")


func test_reactor_eject_needs_a_second_press() -> void:
	var m := await _mount("warp_core", "desktop")
	var panel: PanelBase = m[0]
	var rt = m[1]
	var eject := panel.find_child("ctl_eject", true, false) as PanelButton
	assert_object(eject).is_not_null()
	eject.pressed.emit()
	assert_int(rt.commands.size()).is_equal(0)
	assert_str(eject.caption).contains("CONFIRM")
	eject.pressed.emit()
	assert_dict(rt.commands[0]).is_equal({"type": "reactor_eject", "target": "warp_core"})


func test_a_rejection_is_shown_on_the_control_that_sent_it() -> void:
	var m := await _mount("shields", "desktop")
	var panel: PanelBase = m[0]
	var rt = m[1]
	var rotate := panel.find_child("ctl_rotate", true, false) as PanelButton
	# queued command, rejected by the next tick's event
	rt.queue_reject["shield_set"] = "frequency out of range"
	rotate.pressed.emit()
	assert_str(rotate.sub_caption).not_contains("OUT OF RANGE")
	m[2].step_once()
	m[2].step_once()
	assert_str(rotate.sub_caption).contains("FREQUENCY OUT OF RANGE")
	# rejected at once
	rt.queue_reject.clear()
	rt.reject_types["shield_set"] = "shields offline"
	rotate.pressed.emit()
	assert_str(rotate.sub_caption).contains("SHIELDS OFFLINE")
	# a later accepted press clears it
	rt.reject_types.clear()
	rotate.pressed.emit()
	assert_str(rotate.sub_caption).not_contains("NO:")


func test_every_panel_preselects_its_first_component() -> void:
	for pid: String in PANELS:
		var m := await _mount(pid, "desktop")
		var panel: PanelBase = m[0]
		assert_str(panel.selected).override_failure_message(pid + " has nothing selected").is_not_empty()
		assert_object(panel.find_child("*", true, false)).is_not_null()
		assert_bool(panel._ins.has("name")).override_failure_message(pid + " inspector is empty").is_true()


func test_panel_controls_send_the_ship_commands() -> void:
	var expect := {
		"shields": {"ctl_rotate": "shield_set"},
		"msd": {"ctl_alert_red": "set_alert"},
		"fuel": {"ctl_generator": "antimatter_generator_set"},
		"warp_core": {"ctl_field": "containment_field", "ctl_mode": "core_set_mode", "ctl_shutdown": "reactor_shutdown", "ctl_inject": "core_inject", "ctl_pressurize": "core_pressurize", "ctl_align": "core_align"},
	}
	for pid: String in expect:
		var m := await _mount(pid, "desktop")
		var panel: PanelBase = m[0]
		for ctl: String in expect[pid]:
			var before: int = m[1].commands.size()
			(panel.find_child(ctl, true, false) as PanelButton).pressed.emit()
			assert_int(m[1].commands.size()).override_failure_message(pid + "/" + ctl).is_equal(before + 1)
			assert_str(str(m[1].commands[-1]["type"])).is_equal(expect[pid][ctl])
	# sliders: impulse, warp and shield weights/level go out after the pause, or at once when flushed
	var im := await _mount("impulse", "desktop")
	(im[0].find_child("ctl_impulse", true, false) as PanelSlider).value = 0.5
	im[0].flush_controls()
	assert_dict(im[1].commands[-1]).is_equal({"type": "set_impulse", "value": 0.5})
	var wm := await _mount("warp_core", "desktop")
	(wm[0].find_child("ctl_warp", true, false) as PanelSlider).value = 4.0
	wm[0].flush_controls()
	assert_dict(wm[1].commands[-1]).is_equal({"type": "set_warp", "value": 4.0})
	var sm := await _mount("shields", "desktop")
	(sm[0].find_child("ctl_w_fore", true, false) as PanelSlider).value = 0.5
	sm[0].flush_controls()
	assert_str(str(sm[1].commands[-1]["type"])).is_equal("shield_set_weights")
	(sm[0].find_child("ctl_level", true, false) as PanelSlider).value = 0.9
	sm[0].flush_controls()
	assert_dict(sm[1].commands[-1]).is_equal({"type": "shield_set_level", "value": 0.9})


func test_no_ui_script_sends_raw_repair_damage_or_heat() -> void:
	var banned := ["\"repair\"", "\"damage\"", "\"add_heat\""]
	var stack := ["res://ui"]
	var checked := 0
	while not stack.is_empty():
		var d: String = stack.pop_back()
		var dir := DirAccess.open(d)
		for sub in dir.get_directories():
			stack.append(d + "/" + sub)
		for f in dir.get_files():
			if f.ends_with(".gd"):
				checked += 1
				var src := FileAccess.get_file_as_string(d + "/" + f)
				for b: String in banned:
					assert_bool(src.contains(b)).override_failure_message("%s/%s contains %s" % [d, f, b]).is_false()
	assert_int(checked).is_greater(20)


# --- sizes ----------------------------------------------------------------------------

func _undersized(root: Node) -> Array:
	var min_px := UiScale.dp(48.0) - 0.5
	return _touch_targets(root).filter(func(n: Control) -> bool: return n.size.x < min_px or n.size.y < min_px)


func _one_per_kind(panel: PanelBase) -> Array:
	var seen := {}
	var out: Array = []
	for id: String in panel.wide_ids:
		var c := panel.comp(id)
		var sig := "%s|%s" % [c.get("kind", ""), c.has("countdown")]
		if not seen.has(sig):
			seen[sig] = true
			out.append(id)
	return out


func test_touch_targets_are_at_least_48_dp_at_both_test_sizes() -> void:
	for size_key: String in F.SIZES:
		for pid: String in PANELS:
			var m := await _mount(pid, size_key)
			var panel: PanelBase = m[0]
			var vp: SubViewport = m[3]
			assert_vector(panel.size).is_equal(Vector2(vp.size))
			var count := 0
			# the inspector of one component of every kind (consumer, conduit, reactor, ...) of the panel
			for pass_id: String in _one_per_kind(panel):
				panel.select(pass_id)
				await get_tree().process_frame
				await get_tree().process_frame
				count += _touch_targets(panel).size()
				var small := _undersized(panel)
				assert_array(small.map(func(n: Control) -> String: return "%s %s" % [n.get_path(), n.size])).override_failure_message("%s @ %s select %s" % [pid, size_key, pass_id]).is_empty()
			assert_bool(count > 0).is_true()


func test_the_touch_target_check_fails_for_a_button_made_smaller() -> void:
	var m := await _mount("eps", "desktop")
	var panel: PanelBase = m[0]
	panel.select("eps_trunk_a")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_array(_undersized(panel)).is_empty()
	var small := PanelButton.new()
	small.custom_minimum_size = Vector2(20, 20)
	small.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	small.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel._ins_body.add_child(small)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_array(_undersized(panel)).is_not_empty()


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
	# the real panel map: a panel script may only name ids of its own entry
	var real: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ships/1701d.json"))["panels"]
	for pid: String in real:
		var own_real: Array = real[pid]["components"]
		for mt in re.search_all(sources["panel_%s.gd" % pid]):
			var lit := mt.get_string(1)
			for other: String in real:
				if other != pid and real[other]["components"].has(lit) and not own_real.has(lit):
					assert_str(lit).override_failure_message("panel_%s.gd names %s, not in its real map entry" % [pid, lit]).is_empty()
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
		for banned in ["._runtime", "ShipRuntime", "Sim.new", "/root/SimHost\").call"]:
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


func test_host_without_a_valid_ship_reports_an_error_and_lists_no_scenarios() -> void:
	var host: Node = auto_free(HostScript.new())
	host.auto_start = false
	assert_bool(host.start("res://ships/does_not_exist.json", 1)).is_false()
	assert_bool(host.has_runtime()).is_false()
	assert_array(host.load_errors).is_not_empty()
	assert_array(host.scenario_ids()).is_empty()
	assert_array(host.panel_ids()).is_empty()
	var vp := _viewport("desktop")
	var menu := StationMenu.new()
	menu.host = host
	vp.add_child(menu)
	await get_tree().process_frame
	assert_bool(menu._error.visible).is_true()
	assert_str(menu._error.text).contains("NO SHIP LOADED")
	assert_object(menu.find_child("scenario_core_breach", true, false)).is_null()


func test_host_disposes_the_runtime_it_replaces_and_on_exit() -> void:
	var a := FakeRuntime.new(F.components())
	var b := FakeRuntime.new(F.components())
	var host: Node = HostScript.new()
	host.auto_start = false
	host.use_runtime(a, F.MAP)
	host.use_runtime(b, F.MAP)
	assert_bool(a.disposed).is_true()
	assert_bool(b.disposed).is_false()
	add_child(host)
	remove_child(host)
	host.free()
	assert_bool(b.disposed).is_true()


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
