extends Control
## Main shell: alert banner and scenario status on top, quick tabs, and the body, which opens on the station
## menu and swaps in the panel scenes. Panels are loaded from res://ui/panels/panel_<id>.tscn.

const PANEL_DIR := "res://ui/panels/"

var host: Node
var kit: WidgetKit

var _banner: AlertBanner
var _tabs: HBoxContainer
var _body: Control
var _tab_sig := ""
var _current := ""


func _ready() -> void:
	if host == null:
		host = get_node_or_null("/root/SimHost")
	if kit == null:
		kit = TngKit.new()
	theme = TngTheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = TngTokens.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", int(UiScale.dp(4.0)))
	add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	_banner = kit.banner()
	_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_banner.size_flags_stretch_ratio = 1.0
	head.add_child(_banner)
	var strip := StatusStrip.new()
	strip.host = host
	strip.kit = kit
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.size_flags_stretch_ratio = 2.5
	head.add_child(strip)
	var tab_scroll := ScrollContainer.new()
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.custom_minimum_size = Vector2(0, UiScale.dp(60.0))
	col.add_child(tab_scroll)
	_tabs = HBoxContainer.new()
	tab_scroll.add_child(_tabs)
	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_body)
	if host != null:
		host.snapshot_ready.connect(_on_snapshot)
		host.scenario_changed.connect(_refresh_tabs)
	_refresh_tabs()
	_on_snapshot(host.snapshot if host != null else {}, {})
	show_menu()


func _on_snapshot(snap: Dictionary, _prev: Dictionary) -> void:
	var ship: Dictionary = snap.get("ship", {})
	_banner.set_alert(str(ship.get("alert", snap.get("alert", "green"))))


func _refresh_tabs() -> void:
	var pids: Array[String] = host.panel_ids() if host != null else []
	var sig := str(pids)
	if sig == _tab_sig:
		return
	_tab_sig = sig
	for child in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	var menu := kit.button()
	menu.name = "tab_menu"
	menu.custom_minimum_size = Vector2(UiScale.dp(110.0), UiScale.touch_min())
	menu.set_caption("Stations")
	menu.pressed.connect(show_menu)
	_tabs.add_child(menu)
	for pid in pids:
		var b := kit.button()
		b.name = "tab_" + pid
		b.custom_minimum_size = Vector2(maxf(UiScale.dp(130.0), TngTokens.font().get_string_size(host.panel_title(pid).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, int(UiScale.dp(20.0))).x + UiScale.dp(40.0)), UiScale.touch_min())
		b.set_caption(host.panel_title(pid))
		b.pressed.connect(func() -> void: show_panel(pid))
		_tabs.add_child(b)


func show_menu() -> void:
	_swap(StationMenu.new(), "")


func show_panel(panel_id: String) -> void:
	var path := PANEL_DIR + "panel_%s.tscn" % panel_id
	if not ResourceLoader.exists(path):
		return
	var scene: PackedScene = load(path)
	var panel: Control = scene.instantiate()
	panel.set("host", host)
	panel.set("kit", kit)
	_swap(panel, panel_id)


func current() -> String:
	return _current


func _swap(node: Control, id: String) -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_current = id
	if node is StationMenu:
		node.host = host
		node.kit = kit
		node.panel_requested.connect(show_panel)
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.add_child(node)
