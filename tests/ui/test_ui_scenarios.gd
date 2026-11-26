extends GdUnitTestSuite
## UI-driven scenario runs against the real ship runtime and ships/1701d.json. The scripted player only
## presses buttons of the screens (station menu, quick tabs, panel controls); it never calls SimHost.send.

const HostScript := preload("res://ui/sim_host.gd")
const SHIP := "res://ships/1701d.json"

var _host: Node
var _main: Control


func before_test() -> void:
	UiScale.set_override(1.0, 1.0)
	_host = HostScript.new()
	_host.auto_start = false
	_host.paused = true            # the test steps the host itself
	assert_bool(_host.start(SHIP, 1)).is_true()
	add_child(_host)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	add_child(vp)
	_main = (load("res://ui/main.tscn") as PackedScene).instantiate()
	_main.host = _host
	vp.add_child(_main)


func after_test() -> void:
	UiScale.clear_override()
	if is_instance_valid(_main):
		_main.get_parent().queue_free()
	if is_instance_valid(_host):
		remove_child(_host)
		_host.free()
	await get_tree().process_frame
	await get_tree().process_frame


func _press(name: String) -> void:
	var b := _main.find_child(name, true, false)
	assert_object(b).override_failure_message("no control named " + name).is_not_null()
	b.pressed.emit()


func _run(ticks: int) -> void:
	for i in ticks:
		_host.step_once()


func _sc() -> Dictionary:
	return _host.snapshot["ship"]["scenario"]


func _run_until_over(limit: int) -> void:
	for i in limit:
		if _sc().get("status", "running") != "running":
			return
		_host.step_once()


func _readout_texts() -> Array:
	var out: Array = []
	var stack: Array = [_main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Readout:
			out.append(n.value_text)
		stack.append_array(n.get_children())
	return out


func test_core_breach_is_won_by_shutting_the_core_down_from_the_warp_core_panel() -> void:
	_press("scenario_core_breach")
	_press("tab_warp_core")
	_run(50)
	assert_str(_sc()["status"]).is_equal("running")
	_press("ctl_shutdown")
	_run(5)
	assert_str(_sc()["status"]).is_equal("won")
	assert_array(_readout_texts()).contains(["WON"])


func test_core_breach_is_won_by_ejecting_the_core() -> void:
	_press("scenario_core_breach")
	_press("tab_warp_core")
	for i in 600:
		if _host.snapshot["components"]["warp_core"]["state"] == "containment_failing":
			break
		_host.step_once()
	_press("ctl_eject")      # arms
	_press("ctl_eject")      # confirms
	_run(4)
	assert_str(_sc()["status"]).is_equal("won")


func test_borg_drain_is_won_by_rotating_frequency_and_modulation_on_the_shields_panel() -> void:
	_press("scenario_borg_drain")
	_press("tab_shields")
	for t in 1700:
		if t % 20 == 1:
			_press("ctl_rotate")
		_host.step_once()
		if _sc()["status"] != "running":
			break
	assert_str(_sc()["status"]).is_equal("won")
	assert_array(_readout_texts()).contains(["WON"])


func test_coolant_leak_is_won_with_alert_team_and_refill_from_three_panels() -> void:
	_press("scenario_coolant_leak")
	_press("tab_msd")
	_run(2)
	_press("ctl_alert_green")
	_press("tab_damage_control")
	_run(1)
	var panel := _main._body.get_child(0) as PanelBase
	panel.tile("dc_team_1").pressed.emit()
	_press("row_coolant_core")
	for i in 600:
		if _host.snapshot["components"]["coolant_core"]["integrity"] >= 100.0:
			break
		_host.step_once()
	assert_float(_host.snapshot["components"]["coolant_core"]["integrity"]).is_equal(100.0)
	assert_str(_sc()["status"]).is_equal("running")
	_press("tab_warp_core")
	_press("ctl_refill")
	_run_until_over(900)
	assert_str(_sc()["status"]).is_equal("won")


func test_ignoring_a_scenario_loses_and_the_menu_shows_why() -> void:
	_press("scenario_core_breach")
	_run_until_over(3000)
	assert_str(_sc()["status"]).is_equal("lost")
	assert_str(_sc()["reason"]).is_not_empty()
	assert_array(_readout_texts()).contains(["LOST", _sc()["reason"].to_upper()])


func test_the_ship_panels_have_a_rejecting_control_that_shows_the_reason() -> void:
	_press("tab_shields")
	_run(3)
	# no Borg attack is running and nothing is wrong with shield_set itself: use warp, which is not valid at rest
	_press("tab_warp_core")
	var warp := _main.find_child("ctl_warp", true, false) as PanelSlider
	warp.value = 5.0
	(_main._body.get_child(0) as PanelBase).flush_controls()
	assert_str(warp.label).contains("NO:")


func test_real_ship_panels_keep_every_touch_target_at_48_dp_at_both_sizes() -> void:
	var sizes := {"desktop": [Vector2i(1280, 720), 1.0, 1.0], "phone": [Vector2i(1440, 720), 2.5, 1.5]}
	for key: String in sizes:
		var cfg: Array = sizes[key]
		UiScale.set_override(cfg[1], cfg[2])
		for pid: String in _host.panel_ids():
			var vp := SubViewport.new()
			vp.size = cfg[0]
			add_child(vp)
			var panel: PanelBase = (load("res://ui/panels/panel_%s.tscn" % pid) as PackedScene).instantiate()
			panel.host = _host
			vp.add_child(panel)
			var seen := {}
			var picks: Array = []
			for id: String in panel.wide_ids:
				var c := panel.comp(id)
				var sig := "%s|%s" % [c.get("kind", ""), c.has("countdown")]
				if not seen.has(sig):
					seen[sig] = true
					picks.append(id)
			for id: String in picks:
				panel.select(id)
				await get_tree().process_frame
				await get_tree().process_frame
				var stack: Array = [panel]
				var checked := 0
				while not stack.is_empty():
					var n: Node = stack.pop_back()
					stack.append_array(n.get_children())
					if n is Control and (n is BaseButton or n is Range or n.is_in_group("touch_target")) and n.is_visible_in_tree():
						checked += 1
						var min_px := UiScale.dp(48.0) - 0.5
						assert_bool(n.size.x >= min_px and n.size.y >= min_px).override_failure_message("%s @ %s select %s: %s is %s" % [pid, key, id, n.get_path(), n.size]).is_true()
				assert_bool(checked > 0).is_true()
			vp.queue_free()
		await get_tree().process_frame


func _all_nodes(root: Node) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		stack.append_array(n.get_children())
	return out


## Truncated captions and text sizes below the floor, over the station menu and every panel's inspector.
func test_no_caption_is_cut_and_no_text_is_below_the_floor_at_both_sizes() -> void:
	var sizes := {"desktop": [Vector2i(1280, 720), 1.0, 1.0], "phone": [Vector2i(1440, 720), 2.5, 1.5]}
	for key: String in sizes:
		var cfg: Array = sizes[key]
		UiScale.set_override(cfg[1], cfg[2])
		var floor_size := UiScale.dp(12.0)
		var screens: Array = ["menu"] + _host.panel_ids()
		for screen: String in screens:
			var vp := SubViewport.new()
			vp.size = cfg[0]
			add_child(vp)
			var root: Control
			if screen == "menu":
				var menu := StationMenu.new()
				menu.host = _host
				root = menu
			else:
				var panel: PanelBase = (load("res://ui/panels/panel_%s.tscn" % screen) as PackedScene).instantiate()
				panel.host = _host
				root = panel
			vp.add_child(root)
			var picks: Array = [""]
			if root is PanelBase:
				picks = []
				var seen := {}
				for id: String in root.wide_ids:
					var c: Dictionary = root.comp(id)
					var sig := "%s|%s" % [c.get("kind", ""), c.has("countdown")]
					if not seen.has(sig):
						seen[sig] = true
						picks.append(id)
			for id: String in picks:
				if id != "":
					root.select(id)
				await get_tree().process_frame
				await get_tree().process_frame
				for n: Node in _all_nodes(root):
					var where := "%s @ %s %s: %s" % [screen, key, id, n.get_path()]
					if n is PanelButton and n.is_visible_in_tree():
						assert_bool(n.is_truncated() and not n.sub_caption.begins_with("NO:")).override_failure_message("truncated caption %s '%s' '%s'" % [where, n.caption, n.sub_caption]).is_false()
						for fs: int in n.drawn_font_sizes():
							assert_bool(float(fs) >= floor_size).override_failure_message("small text %s: %d" % [where, fs]).is_true()
					elif (n is Label or n is Readout or n is BarGauge) and n.is_visible_in_tree():
						var fsz := float(n.get_theme_font_size("font_size", "Label"))
						assert_bool(fsz >= floor_size).override_failure_message("small text %s: %s" % [where, fsz]).is_true()
			vp.queue_free()
	await get_tree().process_frame
