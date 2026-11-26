class_name PanelBase
extends Control
## Base of every panel scene. A panel reads only the component ids the panel map assigns to it, from
## `host.snapshot`, through `comp()` (plus the `ship` sections of the snapshot), and writes only through
## `host.send()` (see SimHost). It never touches the runtime or any underscore member of the host.
## Layout: left, a frame with the panel's controls first, then extras and grouped selectable tiles; right, an
## inspector with the generic commands of the selected component. The first component is preselected.
## Every control that sends a command shows the rejection reason (at once, or from the `rejected` event of
## the next tick) on itself.

const DEBOUNCE := 0.3
const EVENT_AGE := 3

@export var panel_id := ""
## Panels that show the whole map (master display, damage control) read every id the map lists.
@export var scope_all := false

var host: Node
var kit: WidgetKit
var ids: Array[String] = []        # the ids of this panel's map entry
var wide_ids: Array[String] = []   # ids a panel may read: its own, or the whole map when scope_all
var selected := ""

var _schematic: SchematicView
var _controls: HFlowContainer
var _rows: VBoxContainer
var _extra: VBoxContainer
var _result: Readout
var _ins_body: VBoxContainer
var _ins := {}                      # widgets of the inspector, by name
var _ins_sig := ""
var _feedback: Readout
var _keys := {}                     # tile key -> Array of ids
var _arm_tick := -1000
var _updating := false
var _level_max := {}
var _row_sig := {}
var _ctl := {}                      # control key -> widget
var _ctl_base := {}                 # control key -> {caption, sub, level} or {label}
var _ctl_err := {}                  # control key -> true while a rejection is shown
var _pending := {}                  # command signature -> {key, tick}
var _debounce := {}                 # control key -> {left, make}
var _dragging := {}


func _ready() -> void:
	if host == null:
		host = get_node_or_null("/root/SimHost")
	if kit == null:
		kit = TngKit.new()
	if theme == null:
		theme = TngTheme.build()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_refresh_ids()
	_build()
	if host != null:
		host.snapshot_ready.connect(_on_snapshot)
		host.scenario_changed.connect(_refresh_ids)
		_on_snapshot(host.snapshot, host.prev)


func _process(delta: float) -> void:
	for key: String in _debounce.keys():
		_debounce[key]["left"] -= delta
		if _debounce[key]["left"] <= 0.0:
			_flush_one(key)


# --- reading -----------------------------------------------------------------

func _refresh_ids() -> void:
	ids.clear()
	wide_ids.clear()
	if host == null:
		return
	ids.assign(host.panel_components(panel_id))
	wide_ids.assign(host.all_ids() if scope_all else ids)


func _snap() -> Dictionary:
	return host.snapshot if host != null else {}


func tick_now() -> int:
	return int(_snap().get("tick", 0))


## One section of the snapshot's `ship` entry (warp, shields, fuel, coolant, propulsion, damage_control, ...).
func ship(section: String) -> Dictionary:
	var s: Variant = _snap().get("ship", {}).get(section, {})
	return s if typeof(s) == TYPE_DICTIONARY else {}


## Extra fields of one of this panel's ids (levels of tanks and pods, ...).
func detail(id: String) -> Dictionary:
	if not wide_ids.has(id):
		return {}
	return _snap().get("ship", {}).get("detail", {}).get(id, {})


## The snapshot entry of one id, or {} when the id is not in this panel's scope.
func comp(id: String) -> Dictionary:
	if not wide_ids.has(id):
		return {}
	var comps: Dictionary = _snap().get("components", {})
	return comps.get(id, {})


## Keys of the tiles on screen (an id, or "name_*" for a collapsed group) and one tile by key.
func tile_keys() -> Array:
	return _schematic.nodes.keys() if _schematic != null else []


func tile(key: String) -> PanelButton:
	return _schematic.nodes.get(key) if _schematic != null else null


func level_of(id: String) -> String:
	return UiStatus.level_of(comp(id))


func fmt(v: float) -> String:
	return "%.0f" % v if absf(v) >= 100.0 else "%.1f" % v


func unit() -> String:
	return host.power_unit() if host != null else ""


## First id of this panel whose name contains `part` (layout hint, never an invented id).
func id_with(part: String) -> String:
	for id in ids:
		if id.contains(part):
			return id
	return ""


## The reactor of this panel: the id whose snapshot entry has a countdown.
func reactor_id() -> String:
	for id in ids:
		if comp(id).has("countdown"):
			return id
	return ""


# --- hooks for specific panels -------------------------------------------------

## Array of [title, [substrings]]; empty means grouping by component kind.
func _group_defs() -> Array:
	return []


## True when numbered siblings (name_01 .. name_30) collapse into one summary tile.
func _collapse_numbered() -> bool:
	return false


## Buttons go into `_controls` (add_button, add_cmd_button), full-width rows (sliders) into `_rows`.
func _build_controls() -> void:
	pass


func _update_controls(_snap_data: Dictionary) -> void:
	pass


func _build_extra(_container: VBoxContainer) -> void:
	pass


func _update_extra(_snap_data: Dictionary) -> void:
	pass


## Reactor start/online/shutdown buttons in the inspector (the warp core panel has its own).
func _inspector_reactor() -> bool:
	return true


## Extra line of text for the inspector about one id ("" for none).
func _detail_text(_id: String) -> String:
	return ""


# --- building ------------------------------------------------------------------

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := int(UiScale.dp(6.0))
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, m)
	add_child(margin)
	var split := HBoxContainer.new()
	margin.add_child(split)
	var title: String = host.panel_title(panel_id) if host != null else panel_id
	var left := kit.frame(title)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.2
	split.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.body.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", int(UiScale.dp(4.0)))
	var cm := MarginContainer.new()      # keeps text clear of the scrollbar
	cm.add_theme_constant_override("margin_right", int(UiScale.dp(12.0)))
	cm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cm.add_child(content)
	scroll.add_child(cm)
	_controls = HFlowContainer.new()
	_controls.add_theme_constant_override("h_separation", int(UiScale.dp(6.0)))
	_controls.add_theme_constant_override("v_separation", int(UiScale.dp(6.0)))
	_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_extra = VBoxContainer.new()
	_extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_schematic = kit.schematic()
	_schematic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_schematic.node_pressed.connect(_on_key)
	content.add_child(_controls)
	content.add_child(_rows)
	_result = kit.readout("Result", "")
	content.add_child(_result)
	content.add_child(_extra)
	content.add_child(_schematic)
	_build_controls()
	_build_extra(_extra)
	var right := kit.frame("INSPECTOR")
	right.custom_minimum_size = Vector2(UiScale.dp(250.0), 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	split.add_child(right)
	var rscroll := ScrollContainer.new()
	rscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.body.add_child(rscroll)
	_ins_body = VBoxContainer.new()
	_ins_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ins_body.add_theme_constant_override("separation", int(UiScale.dp(4.0)))
	var im := MarginContainer.new()
	im.add_theme_constant_override("margin_right", int(UiScale.dp(12.0)))
	im.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	im.add_child(_ins_body)
	rscroll.add_child(im)


# --- controls ---------------------------------------------------------------------

## A command button in the controls row. `on_press` runs on every press.
func add_button(key: String, caption: String, on_press: Callable, level: String = UiStatus.OK, sub: String = "", min_w: float = 132.0) -> PanelButton:
	var b := kit.button()
	b.name = "ctl_" + key
	b.custom_minimum_size = Vector2(UiScale.dp(min_w), UiScale.dp(52.0))
	b.set_caption(caption, sub)
	b.set_level(level)
	b.pressed.connect(on_press)
	_controls.add_child(b)
	_ctl[key] = b
	_ctl_base[key] = {"caption": caption, "sub": sub, "level": level}
	return b


## A button that sends one fixed command through send_ctl.
func add_cmd_button(key: String, caption: String, cmd: Dictionary, level: String = UiStatus.OK, sub: String = "") -> PanelButton:
	return add_button(key, caption, func() -> void: send_ctl(key, cmd), level, sub)


## Changes the look of a control (state shown on it). Ignored while a rejection is displayed on it.
func set_button(key: String, caption: String, sub: String, level: String) -> void:
	_ctl_base[key] = {"caption": caption, "sub": sub, "level": level}
	if _ctl_err.get(key, false):
		return
	var b: PanelButton = _ctl.get(key)
	if b != null:
		b.set_caption(caption, sub)
		b.set_level(level)


## A labelled slider in a full-width row. `make` builds the command from the slider value; it is sent
## after a short pause when the value stops changing (or at once through flush_controls).
func add_slider(key: String, label: String, lo: float, hi: float, step_size: float, make: Callable, scale_factor: float = 1.0, decimals: int = 0, suffix: String = "", parent: Container = null) -> PanelSlider:
	var s := kit.slider()
	s.name = "ctl_" + key
	s.min_value = lo
	s.max_value = hi
	s.step = step_size
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.setup_display(label, scale_factor, decimals, suffix)
	s.value_changed.connect(func(_v: float) -> void:
		if not _updating:
			_debounce[key] = {"left": DEBOUNCE, "make": make})
	s.drag_started.connect(func() -> void: _dragging[key] = true)
	s.drag_ended.connect(func(_c: bool) -> void: _dragging[key] = false)
	(parent if parent != null else _rows).add_child(s)
	_ctl[key] = s
	_ctl_base[key] = {"label": label}
	return s


## Keeps a slider at the value the sim reports unless the player is moving it.
func sync_slider(key: String, value: float) -> void:
	var s: PanelSlider = _ctl.get(key)
	if s == null or _debounce.has(key) or _dragging.get(key, false):
		return
	_updating = true
	s.set_value_no_signal(value)
	_updating = false
	s.queue_redraw()


func _flush_one(key: String) -> void:
	var entry: Dictionary = _debounce.get(key, {})
	_debounce.erase(key)
	if entry.is_empty():
		return
	var s: PanelSlider = _ctl.get(key)
	if s != null:
		send_ctl(key, entry["make"].call(s.value))


## Sends every pending slider change now.
func flush_controls() -> void:
	for key: String in _debounce.keys():
		_flush_one(key)


func _sig(cmd: Dictionary) -> String:
	return "%s|%s" % [cmd.get("type", ""), cmd.get("target", cmd.get("team", ""))]


## Sends a command on behalf of control `key` and shows a rejection on that control.
func send_ctl(key: String, cmd: Dictionary) -> Dictionary:
	_ctl_clear(key)
	_pending[_sig(cmd)] = {"key": key, "tick": tick_now()}
	var res := _send(cmd)
	if res.get("accepted", true) == false:
		_ctl_error(key, str(res.get("reason", "")))
	return res


func _ctl_clear(key: String) -> void:
	if not _ctl_err.get(key, false):
		return
	_ctl_err[key] = false
	var base: Dictionary = _ctl_base.get(key, {})
	var w: Variant = _ctl.get(key)
	if w is PanelButton:
		w.set_caption(base.get("caption", ""), base.get("sub", ""))
		w.set_level(base.get("level", UiStatus.OK))
	elif w is PanelSlider:
		w.setup_display(str(base.get("label", "")), w.value_scale, w.value_decimals, w.value_suffix)


func _ctl_error(key: String, reason: String) -> void:
	_ctl_err[key] = true
	var base: Dictionary = _ctl_base.get(key, {})
	var w: Variant = _ctl.get(key)
	if w is PanelButton:
		w.set_caption(base.get("caption", ""), "no: " + reason)
		w.set_level(UiStatus.CAUTION)
	elif w is PanelSlider:
		w.setup_display(str(base.get("label", "")) + " - NO: " + reason, w.value_scale, w.value_decimals, w.value_suffix)
	if _result != null:
		_result.set_pair("Result", "Rejected: " + reason, UiStatus.CAUTION)


func _read_rejections(snap: Dictionary) -> void:
	for ev: Dictionary in snap.get("events", []):
		if str(ev.get("type", "")) != "rejected":
			continue
		var reason := str(ev.get("reason", ""))
		var cmd: Dictionary = ev.get("cmd", {})
		var entry: Dictionary = _pending.get(_sig(cmd), {})
		if not entry.is_empty() and int(snap.get("tick", 0)) - int(entry["tick"]) <= EVENT_AGE:
			_ctl_error(entry["key"], reason)
			_pending.erase(_sig(cmd))
			if entry["key"] == "inspector" and _feedback != null:
				_feedback.set_pair("Result", "Rejected: " + reason, UiStatus.CAUTION)


# --- snapshot updates -------------------------------------------------------------

func _on_snapshot(snap: Dictionary, _prev: Dictionary) -> void:
	if _schematic == null:
		return
	var groups := _build_groups(snap)
	var layout: Array = []
	for g: Dictionary in groups:
		var keys: Array = []
		for e: Dictionary in g["entries"]:
			keys.append(e["key"])
			_keys[e["key"]] = e["ids"]
		layout.append({"title": g["title"], "ids": keys})
	_schematic.set_groups(layout)
	if selected == "" and not groups.is_empty():
		selected = _rep(groups[0]["entries"][0]["key"])
	for g: Dictionary in groups:
		var prefix := _common_prefix(g["entries"])
		for e: Dictionary in g["entries"]:
			_update_tile(e, prefix)
	_rebuild_inspector_if_needed(snap)
	_update_inspector(snap)
	_read_rejections(snap)
	_update_controls(snap)
	_update_extra(snap)


func _build_groups(snap: Dictionary) -> Array:
	var comps: Dictionary = snap.get("components", {})
	var defs := _group_defs()
	var buckets: Array = []
	if defs.is_empty():
		var by_kind := {"producer": "SOURCES", "store": "STORES", "conduit": "CONDUITS", "consumer": "CONSUMERS", "junction": "OTHER"}
		var order := ["producer", "store", "conduit", "consumer", "junction", ""]
		for k in order:
			buckets.append({"title": by_kind.get(k, "OTHER"), "ids": [], "kind": k})
		for id in ids:
			var kind := str(comps.get(id, {}).get("kind", ""))
			var idx := order.find(kind)
			buckets[idx if idx >= 0 else order.size() - 1]["ids"].append(id)
	else:
		for d: Array in defs:
			buckets.append({"title": d[0], "ids": [], "parts": d[1]})
		buckets.append({"title": "OTHER", "ids": [], "parts": []})
		for id in ids:
			var placed := false
			for b: Dictionary in buckets:
				for part: String in b.get("parts", []):
					if id.contains(part):
						b["ids"].append(id)
						placed = true
						break
				if placed:
					break
			if not placed:
				buckets[buckets.size() - 1]["ids"].append(id)
	var out: Array = []
	for b: Dictionary in buckets:
		if b["ids"].is_empty():
			continue
		out.append({"title": b["title"], "entries": _entries(b["ids"])})
	return out


func _entries(id_list: Array) -> Array:
	var entries: Array = []
	if not _collapse_numbered():
		for id: String in id_list:
			entries.append({"key": id, "ids": [id]})
		return entries
	var re := RegEx.new()
	re.compile("^(.*)_\\d+$")
	var groups := {}
	var order: Array = []
	for id: String in id_list:
		var mt := re.search(id)
		var k := id if mt == null else mt.get_string(1) + "_*"
		if not groups.has(k):
			groups[k] = []
			order.append(k)
		groups[k].append(id)
	for k: String in order:
		if groups[k].size() < 3:
			for id: String in groups[k]:
				entries.append({"key": id, "ids": [id]})
		else:
			entries.append({"key": k, "ids": groups[k]})
	return entries


func _common_prefix(entries: Array) -> String:
	if entries.size() < 2:
		return ""
	var first: PackedStringArray = str(entries[0]["key"]).split("_")
	var n := first.size() - 1
	for e: Dictionary in entries:
		var parts: PackedStringArray = str(e["key"]).split("_")
		var i := 0
		while i < n and i < parts.size() - 1 and parts[i] == first[i]:
			i += 1
		n = mini(n, i)
	if n <= 0:
		return ""
	return "_".join(first.slice(0, n)) + "_"


func _update_tile(e: Dictionary, prefix: String) -> void:
	var key: String = e["key"]
	var members: Array = e["ids"]
	var level := UiStatus.OK
	var worst := ""
	for id: String in members:
		var lv := level_of(id)
		if worst == "" or UiStatus.SEVERITY.get(lv, 1) > UiStatus.SEVERITY.get(level_of(worst), 1):
			worst = id
		level = UiStatus.worse(level, lv)
	var c := comp(members[0])
	var name_text := key
	if members.size() > 1:
		name_text = key.trim_suffix("_*").replace("_", " ") + " x%d" % members.size()
	elif prefix != "" and key.begins_with(prefix):
		name_text = key.substr(prefix.length())
	name_text = name_text.replace("_", " ")
	var sub := str(c.get("state", "")) if members.size() == 1 else ("ALL OK" if level == UiStatus.OK else str(comp(worst).get("state", "")))
	var fill_value := -1.0
	if members.size() == 1 and not c.is_empty():
		fill_value = _fill_of(members[0], c)
		var lvl: Variant = detail(members[0]).get("level", null)
		if lvl != null:
			sub += " " + fmt(float(lvl))
	_schematic.set_node(key, name_text, sub, level, fill_value, selected != "" and members.has(selected))


func _fill_of(id: String, c: Dictionary) -> float:
	var lvl: Variant = detail(id).get("level", null)
	if lvl != null:
		var v := float(lvl)
		if v <= 100.0 and not _level_max.has(id):
			return v / 100.0
		_level_max[id] = maxf(float(_level_max.get(id, 0.0)), v)
		return v / maxf(1.0, float(_level_max[id]))
	if c.has("charge"):
		_level_max[id] = maxf(float(_level_max.get(id, 0.0)), float(c["charge"]))
		var m: float = _level_max[id]
		return float(c["charge"]) / m if m > 0.0 else 0.0
	if c.get("kind", "") in ["producer", "consumer", "conduit"] and c.has("load"):
		return clampf(float(c["load"]), 0.0, 1.0)
	return clampf(float(c.get("integrity", 100.0)) / 100.0, 0.0, 1.0)


func _rep(key: String) -> String:
	var members: Array = _keys.get(key, [key])
	var pick: String = members[0]
	for id: String in members:
		if UiStatus.SEVERITY.get(level_of(id), 1) > UiStatus.SEVERITY.get(level_of(pick), 1):
			pick = id
	return pick


func _on_key(key: String) -> void:
	select(_rep(key))


func select(id: String) -> void:
	if not wide_ids.has(id):
		return
	selected = id
	_arm_tick = -1000
	_on_snapshot(_snap(), {})


# --- inspector ------------------------------------------------------------------------

func _inspector_sig(c: Dictionary) -> String:
	return "%s|%s|%s|%s" % [selected, c.get("kind", ""), c.has("countdown"), c.get("cut", "")]


func _row2(a: Control, b: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(a)
	row.add_child(b)
	return row


func _rebuild_inspector_if_needed(_snap_data: Dictionary) -> void:
	var c := comp(selected) if selected != "" else {}
	var sig := _inspector_sig(c)
	if sig == _ins_sig and not _ins.is_empty():
		return
	_ins_sig = sig
	for child in _ins_body.get_children():
		_ins_body.remove_child(child)
		child.queue_free()
	_ins.clear()
	if selected == "" or c.is_empty():
		_ins_body.add_child(kit.caption("Select a component"))
		_feedback = kit.readout("Result", "")
		_ins_body.add_child(_feedback)
		return
	var kind := str(c.get("kind", ""))
	_ins["name"] = kit.readout("Part", UiStatus.pretty(selected))
	_ins["state"] = kit.readout("State", "")
	_ins["power"] = kit.readout("Pwr / temp", "")
	_ins["integrity"] = kit.gauge("Integrity")
	_ins_body.add_child(_ins["name"])
	_ins_body.add_child(_ins["state"])
	_ins_body.add_child(_ins["power"])
	_ins_body.add_child(_ins["integrity"])
	_ins["extra"] = kit.readout("", "")
	_ins_body.add_child(_ins["extra"])
	if c.has("countdown"):
		_ins["countdown"] = kit.readout("Countdown", "")
		_ins_body.add_child(_ins["countdown"])
	if c.has("countdown") and _inspector_reactor():
		var row := HFlowContainer.new()
		_ins_body.add_child(row)
		for spec in [["START", "reactor_start"], ["ONLINE", "reactor_online"], ["SHUTDOWN", "reactor_shutdown"]]:
			var b := kit.button()
			b.set_caption(spec[0])
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var cmd := {"type": spec[1], "target": selected}
			b.pressed.connect(func() -> void: _send_inspector(cmd))
			row.add_child(b)
	elif kind == "conduit":
		var b2 := kit.button()
		b2.set_caption("RESTORE" if c.get("cut", false) else "CUT")
		var cmd2 := {"type": "restore_conduit" if c.get("cut", false) else "cut_conduit", "target": selected}
		b2.pressed.connect(func() -> void: _send_inspector(cmd2))
		_ins_body.add_child(b2)
	elif kind == "consumer":
		var s := kit.slider()
		s.setup_display("Allocation", 100.0, 0, "%")
		s.value_changed.connect(_on_alloc_changed)
		_ins["alloc"] = s
		_ins_body.add_child(s)
		var prow := HFlowContainer.new()
		_ins_body.add_child(prow)
		for spec in [["PRIORITY -", -1], ["PRIORITY +", 1]]:
			var pb := kit.button()
			pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var step: int = spec[1]
			pb.pressed.connect(func() -> void: _send_inspector({"type": "set_priority", "target": selected, "value": int(comp(selected).get("priority", 100)) + step}))
			prow.add_child(pb)
			_ins["prio" + ("m" if step < 0 else "p")] = pb
			pb.set_caption(spec[0])
	_feedback = kit.readout("Result", "")
	_ins_body.add_child(_feedback)


func _send_inspector(cmd: Dictionary) -> void:
	_pending[_sig(cmd)] = {"key": "inspector", "tick": tick_now()}
	var res := _send(cmd)
	if _feedback != null:
		if res.get("accepted", true) == false:
			_feedback.set_pair("Result", "Rejected: " + str(res.get("reason", "")), UiStatus.CAUTION)
		else:
			_feedback.set_pair("Result", "Sent " + str(cmd.get("type", "")), UiStatus.OK)


func _on_alloc_changed(v: float) -> void:
	if _updating or selected == "":
		return
	_send_inspector({"type": "set_allocation", "target": selected, "value": v})


func _update_inspector(_snap_data: Dictionary) -> void:
	if _ins.is_empty() or selected == "":
		return
	var c := comp(selected)
	if c.is_empty():
		return
	var u := unit()
	var level := UiStatus.level_of(c)
	(_ins["state"] as Readout).set_pair("State", str(c.get("state", "")), level)
	(_ins["power"] as Readout).set_pair("Pwr / temp", (fmt(float(c.get("power", 0.0))) + " " + u + " / " + fmt(float(c.get("temp", 0.0)))).strip_edges(), UiStatus.INFO)
	var integ := float(c.get("integrity", 100.0))
	(_ins["integrity"] as BarGauge).set_reading(integ, 100.0, level, fmt(integ) + "%")
	var lvl: Variant = detail(selected).get("level", null)
	var text := _detail_text(selected)
	if lvl != null:
		text = ("level " + fmt(float(lvl)) + " " + text).strip_edges()
	(_ins["extra"] as Readout).set_pair("Detail", text, UiStatus.INFO)
	(_ins["extra"] as Readout).visible = text != ""
	if _ins.has("countdown"):
		(_ins["countdown"] as Readout).set_pair("Countdown", UiStatus.clock(float(c.get("countdown", 0.0))), UiStatus.CAUTION if float(c.get("countdown", 0.0)) > 0.0 else UiStatus.INFO)
	if _ins.has("alloc"):
		_updating = true
		(_ins["alloc"] as PanelSlider).set_value_no_signal(float(c.get("allocation", 1.0)))
		_updating = false
		(_ins["alloc"] as PanelSlider).queue_redraw()
		var pr := str(int(c.get("priority", 0)))
		(_ins["priom"] as PanelButton).set_caption("PRIORITY -", pr)
		(_ins["priop"] as PanelButton).set_caption("PRIORITY +", pr)


func _send(cmd: Dictionary) -> Dictionary:
	if host == null:
		return {"accepted": false, "reason": "no host"}
	var result: Dictionary = host.send(cmd)
	if _result != null and result.get("accepted", true) != false:
		_result.set_pair("Result", "Sent " + str(cmd.get("type", "")), UiStatus.OK)
	return result


# --- helpers for panel extras ---------------------------------------------------------------

## Makes `container` hold one button per row dict {id, caption, sub, level}; rebuilt only when the id list
## changes. `on_press` gets the row id.
func sync_rows(container: Container, rows: Array, on_press: Callable) -> void:
	var sig := ""
	for r: Dictionary in rows:
		sig += str(r["id"]) + ","
	var cache_key := str(container.get_instance_id())
	if _row_sig.get(cache_key, "") != sig:
		_row_sig[cache_key] = sig
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
		for r: Dictionary in rows:
			var b := kit.button()
			b.name = "row_" + str(r["id"])
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var rid: String = r["id"]
			b.pressed.connect(func() -> void: on_press.call(rid))
			container.add_child(b)
	for r: Dictionary in rows:
		var b: PanelButton = container.get_node_or_null("row_" + str(r["id"]))
		if b != null:
			b.set_caption(str(r["caption"]), str(r["sub"]))
			b.set_level(str(r["level"]))


## Ids of the readable scope that are caution or alarm, worst first.
func off_nominal(snap: Dictionary) -> Array:
	var out: Array = []
	var comps: Dictionary = snap.get("components", {})
	for id in wide_ids:
		var c: Dictionary = comps.get(id, {})
		if not UiStatus.is_nominal(c):
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool: return UiStatus.SEVERITY.get(level_of(a), 1) > UiStatus.SEVERITY.get(level_of(b), 1))
	return out
