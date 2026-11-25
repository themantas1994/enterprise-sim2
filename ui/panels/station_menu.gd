class_name StationMenu
extends Control
## Station menu: one big button per panel id of the panel map (in ADR order), the scenario select and the
## scenario status readout. Emits panel_requested(panel_id).

signal panel_requested(panel_id: String)

var host: Node
var kit: WidgetKit

var _stations: HFlowContainer
var _scenarios: HFlowContainer
var _sig := ""
var _buttons := {}


func _ready() -> void:
	if host == null:
		host = get_node_or_null("/root/SimHost")
	if kit == null:
		kit = TngKit.new()
	if theme == null:
		theme = TngTheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := int(UiScale.dp(8.0))
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, m)
	add_child(margin)
	var frame := kit.frame("STATIONS")
	margin.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.body.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)
	_stations = HFlowContainer.new()
	_stations.add_theme_constant_override("h_separation", int(UiScale.dp(8.0)))
	_stations.add_theme_constant_override("v_separation", int(UiScale.dp(8.0)))
	col.add_child(_stations)
	col.add_child(kit.caption("Scenario"))
	_scenarios = HFlowContainer.new()
	_scenarios.add_theme_constant_override("h_separation", int(UiScale.dp(8.0)))
	_scenarios.add_theme_constant_override("v_separation", int(UiScale.dp(8.0)))
	col.add_child(_scenarios)
	var strip := StatusStrip.new()
	strip.host = host
	strip.kit = kit
	strip.show_reason = true
	col.add_child(strip)
	if host != null:
		host.snapshot_ready.connect(func(_s: Dictionary, _p: Dictionary) -> void: _refresh())
		host.scenario_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if host == null:
		return
	var pids: Array[String] = host.panel_ids()
	var sids: Array = host.scenario_ids()
	var sig := str(pids) + str(sids)
	if sig != _sig:
		_sig = sig
		_buttons.clear()
		for child in _stations.get_children():
			_stations.remove_child(child)
			child.queue_free()
		for child in _scenarios.get_children():
			_scenarios.remove_child(child)
			child.queue_free()
		for pid in pids:
			var b := kit.button()
			b.name = "station_" + pid
			b.custom_minimum_size = Vector2(UiScale.dp(250.0), UiScale.dp(64.0))
			b.pressed.connect(func() -> void: panel_requested.emit(pid))
			_stations.add_child(b)
			_buttons[pid] = b
		for sid in sids:
			var b := kit.button()
			b.name = "scenario_" + str(sid)
			b.custom_minimum_size = Vector2(UiScale.dp(190.0), UiScale.dp(56.0))
			b.set_caption(UiStatus.pretty(str(sid)), "start")
			var scenario_id := str(sid)
			b.pressed.connect(func() -> void: host.start_scenario(scenario_id))
			_scenarios.add_child(b)
	var comps: Dictionary = host.snapshot.get("components", {})
	for pid in pids:
		var level := UiStatus.OK
		for id in host.panel_components(pid):
			level = UiStatus.worse(level, UiStatus.level_of(comps.get(id, {})))
		var b: PanelButton = _buttons[pid]
		b.set_caption(host.panel_title(pid), "nominal" if level == UiStatus.OK else ("alarm" if level == UiStatus.ALARM else "check"))
		b.set_level(level)
	if pids.is_empty() and _buttons.is_empty():
		pass
