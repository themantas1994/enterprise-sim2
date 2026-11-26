class_name TmpKitGallery
extends Control
## Gallery of the film-era kit for tests and screenshots: every widget in several states, with the CRT overlay
## on two separate regions (the line-art column). Placeholder labels only. It reads no ship data, does not use the simulation host
## and is not part of the main scene.

var kit := TmpKit.new()
var reduced_motion := false
var banners: Array[AlertBanner] = []
var _crts: Array[ColorRect] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = TmpTheme.build()
	var back := ColorRect.new()
	back.color = TmpTokens.BODY_DARK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(UiScale.dp(8.0)))
	add_child(margin)
	var root := VBoxContainer.new()
	margin.add_child(root)
	root.add_child(_banner_row())
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	for col: Control in [_buttons_column(), _meters_column(), _trace_column()]:
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cols.add_child(col)
	_crts = TmpCrt.find_overlays(self)
	set_reduced_motion(reduced_motion)


## The first CRT overlay (the gallery has two regions: see crt_overlays()).
func crt_overlay() -> ColorRect:
	return _crts[0] if not _crts.is_empty() else null


func crt_overlays() -> Array[ColorRect]:
	return _crts


## Reduced motion: the CRT flicker and the banner blinking stop.
func set_reduced_motion(on: bool) -> void:
	reduced_motion = on
	for o in _crts:
		TmpCrt.set_reduced_motion(o, on)
	for b in banners:
		b.reduced_motion = on


func _banner_row() -> Control:
	var row := HBoxContainer.new()
	for level in ["green", "yellow", "red"]:
		var b := kit.banner()
		b.set_alert(level)
		b.reduced_motion = reduced_motion
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
		banners.append(b)
	return row


func _flow() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", int(UiScale.dp(8.0)))
	f.add_theme_constant_override("v_separation", int(UiScale.dp(8.0)))
	return f


func _button(caption_text: String, sub: String, lamp_name: String, level: String, pressed: bool, off: bool, fill: float = -1.0) -> TmpButton:
	var b := kit.button() as TmpButton
	b.set_caption(caption_text, sub)
	b.lamp = lamp_name
	b.set_level(level)
	b.set_fill(fill)
	b.toggle_mode = pressed
	b.button_pressed = pressed
	b.disabled = off
	return b


func _buttons_column() -> Control:
	var f := kit.frame("Push buttons")
	var flow := _flow()
	for name_text: String in TmpTokens.LAMP_NAMES:
		flow.add_child(_button(name_text, "", name_text, UiStatus.OK, false, false))
	flow.add_child(_button("Pressed", "", "amber", UiStatus.OK, true, false))
	flow.add_child(_button("Pressed", "", "blue", UiStatus.OK, true, false))
	flow.add_child(_button("Off", "", "white", UiStatus.OK, false, true))
	flow.add_child(_button("Level", "62 PCT", "", UiStatus.CAUTION, false, false, 0.62))
	flow.add_child(_button("Level", "OUT", "", UiStatus.ALARM, true, false, 0.1))
	f.body.add_child(flow)
	var lamps := HBoxContainer.new()
	for name_text: String in TmpTokens.LAMP_NAMES:
		lamps.add_child(kit.lamp(name_text, true))
	lamps.add_child(kit.lamp("green", false))
	f.body.add_child(lamps)
	return f


func _meters_column() -> Control:
	var f := kit.frame("Meters")
	var g1 := kit.gauge("Level A")
	g1.set_reading(0.72, 1.0, UiStatus.OK, "72")
	var g2 := kit.gauge("Level B")
	g2.set_reading(0.4, 1.0, UiStatus.CAUTION, "40")
	var g3 := kit.gauge("Level C")
	g3.set_reading(0.12, 1.0, UiStatus.ALARM, "12")
	for g in [g1, g2, g3]:
		f.body.add_child(g)
	var r1 := kit.readout("Channel", "12.5")
	r1.level = UiStatus.OK
	var r2 := kit.readout("Mode", "Standby")
	r2.set_pair("Mode", "Standby", UiStatus.INFO)
	var r3 := kit.readout("Limit", "Over")
	r3.set_pair("Limit", "Over", UiStatus.ALARM)
	for r in [r1, r2, r3]:
		f.body.add_child(r)
	var s1 := kit.slider()
	s1.setup_display("Gain", 100.0, 0, " PCT")
	s1.value = 0.65
	f.body.add_child(s1)
	return f


func _trace_column() -> Control:
	var f := kit.frame("Line art")
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var green := kit.schematic() as TmpSchematic
	green.set_groups([{"title": "Group one", "ids": ["a1", "a2"]}])
	green.set_node("a1", "Node 1", "OK", UiStatus.OK, 0.8, false)
	green.set_node("a2", "Node 2", "WARN", UiStatus.CAUTION, 0.35, true)
	var blue := kit.schematic() as TmpSchematic
	blue.trace = "blue"
	blue.set_groups([{"title": "Group two", "ids": ["b1"]}])
	blue.set_node("b1", "Node 3", "IDLE", UiStatus.INFO, -1.0, false)
	# Two separate CRT regions: each has its own BackBufferCopy, so both read a fresh screen copy.
	var region_a := TmpCrt.wrap(green, reduced_motion)
	var region_b := TmpCrt.wrap(blue, reduced_motion)
	region_b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(region_a)
	box.add_child(region_b)
	f.body.add_child(box)
	var s2 := kit.slider()
	s2.setup_display("Trim", 100.0, 0, " PCT")
	s2.value = 0.2
	f.body.add_child(s2)
	return f
