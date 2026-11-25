class_name PanelBase
extends Control
## Base of every panel scene. A panel reads only the component ids the panel map assigns to it, from
## `host.snapshot`, through `comp()`; it writes only through `host.send()` (see SimHost). Panels never touch the
## runtime or any underscore member of the host. Layout: a frame with grouped selectable tiles (SchematicView)
## and panel-specific extras on the left, an inspector with the commands for the selected component on the
## right. Everything scrolls, so the panel works at 864x432 dp.

@export var panel_id := ""
## Panels that show the whole map (master display, damage control) read every id the map lists.
@export var scope_all := false

var host: Node
var kit: WidgetKit
var ids: Array[String] = []        # the ids of this panel's map entry
var wide_ids: Array[String] = []   # ids a panel may read: its own, or the whole map when scope_all
var selected := ""

var _schematic: SchematicView
var _extra: VBoxContainer
var _ins_body: VBoxContainer
var _ins := {}                      # readouts and widgets of the inspector, by name
var _ins_sig := ""
var _feedback: Readout
var _keys := {}                     # tile key -> Array of ids
var _arm_tick := -1000
var _updating := false
var _charge_max := {}
var _row_sig := {}


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


# --- hooks for specific panels -------------------------------------------------

## Array of [title, [substrings]]; empty means grouping by component kind.
func _group_defs() -> Array:
	return []


## True when numbered siblings (name_01 .. name_30) collapse into one summary tile.
func _collapse_numbered() -> bool:
	return false


func _build_extra(_container: VBoxContainer) -> void:
	pass


func _update_extra(_snap_data: Dictionary) -> void:
	pass


# --- building ------------------------------------------------------------------

func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := int(UiScale.dp(8.0))
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, m)
	add_child(margin)
	var split := HBoxContainer.new()
	margin.add_child(split)
	var title: String = host.panel_title(panel_id) if host != null else panel_id
	var left := kit.frame(title)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.0
	split.add_child(left)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.body.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_extra = VBoxContainer.new()
	_extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_schematic = kit.schematic()
	_schematic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_schematic.node_pressed.connect(_on_key)
	content.add_child(_extra)
	content.add_child(_schematic)
	_build_extra(_extra)
	var right := kit.frame("INSPECTOR")
	right.custom_minimum_size = Vector2(UiScale.dp(280.0), 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	split.add_child(right)
	var rscroll := ScrollContainer.new()
	rscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.body.add_child(rscroll)
	_ins_body = VBoxContainer.new()
	_ins_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rscroll.add_child(_ins_body)


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
		layout.append({"title": g["title"], "ids": keys})
	_schematic.set_groups(layout)
	for g: Dictionary in groups:
		var prefix := _common_prefix(g["entries"])
		for e: Dictionary in g["entries"]:
			_update_tile(e, prefix)
	_rebuild_inspector_if_needed(snap)
	_update_inspector(snap)
	_read_rejections(snap)
	_update_extra(snap)


func _build_groups(snap: Dictionary) -> Array:
	var comps: Dictionary = snap.get("components", {})
	var defs := _group_defs()
	var buckets: Array = []
	if defs.is_empty():
		var by_kind := {"producer": "SOURCES", "store": "STORES", "conduit": "CONDUITS", "consumer": "CONSUMERS", "junction": "JUNCTIONS"}
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
	_keys[key] = e["ids"]
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
	_schematic.set_node(key, name_text, sub, level, fill_value, selected != "" and members.has(selected))


func _fill_of(id: String, c: Dictionary) -> float:
	if c.has("charge"):
		_charge_max[id] = maxf(float(_charge_max.get(id, 0.0)), float(c["charge"]))
		var m: float = _charge_max[id]
		return float(c["charge"]) / m if m > 0.0 else 0.0
	if c.has("load"):
		return clampf(float(c["load"]), 0.0, 1.0)
	return clampf(float(c.get("integrity", 100.0)) / 100.0, 0.0, 1.0)


func _on_key(key: String) -> void:
	var members: Array = _keys.get(key, [key])
	var pick: String = members[0]
	for id: String in members:
		if UiStatus.SEVERITY.get(level_of(id), 1) > UiStatus.SEVERITY.get(level_of(pick), 1):
			pick = id
	select(pick)


func select(id: String) -> void:
	if not wide_ids.has(id):
		return
	selected = id
	_arm_tick = -1000
	_on_snapshot(_snap(), {})


# --- inspector ------------------------------------------------------------------------

func _inspector_sig(c: Dictionary) -> String:
	return "%s|%s|%s|%s|%s" % [selected, c.get("kind", ""), c.has("countdown"), c.get("cut", ""), float(c.get("integrity", 100.0)) < 100.0 or str(c.get("state", "")) == "destroyed"]


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
	_ins["name"] = kit.readout("Component", UiStatus.pretty(selected))
	_ins["state"] = kit.readout("State", "")
	_ins["power"] = kit.readout("Power", "")
	_ins["temp"] = kit.readout("Temp", "")
	_ins["integrity"] = kit.gauge("Integrity")
	for k in ["name", "state", "power", "temp", "integrity"]:
		_ins_body.add_child(_ins[k])
	if c.has("charge"):
		_ins["charge"] = kit.readout("Charge", "")
		_ins_body.add_child(_ins["charge"])
	if c.has("countdown"):
		_ins["countdown"] = kit.readout("Countdown", "")
		_ins_body.add_child(_ins["countdown"])
	var kind := str(c.get("kind", ""))
	if c.has("countdown"):
		for spec in [["START", "reactor_start"], ["ONLINE", "reactor_online"], ["SHUTDOWN", "reactor_shutdown"]]:
			_add_cmd_button(spec[0], {"type": spec[1], "target": selected})
		_ins["eject"] = _add_cmd_button("EJECT", {}, true)
	elif kind == "conduit":
		if c.get("cut", false):
			_add_cmd_button("RESTORE", {"type": "restore_conduit", "target": selected})
		else:
			_add_cmd_button("CUT", {"type": "cut_conduit", "target": selected})
	elif kind == "consumer":
		_ins["alloc_label"] = kit.readout("Allocation", "")
		_ins_body.add_child(_ins["alloc_label"])
		var s := kit.slider()
		s.value_changed.connect(_on_alloc_changed)
		_ins["alloc"] = s
		_ins_body.add_child(s)
		var row := HBoxContainer.new()
		_ins_body.add_child(row)
		for spec in [["PRIORITY -", -1], ["PRIORITY +", 1]]:
			var b := kit.button()
			b.set_caption(spec[0])
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var step: int = spec[1]
			b.pressed.connect(func() -> void: _send({"type": "set_priority", "target": selected, "value": int(comp(selected).get("priority", 100)) + step}))
			row.add_child(b)
		_ins["prio"] = kit.readout("Priority", "")
		_ins_body.add_child(_ins["prio"])
	if float(c.get("integrity", 100.0)) < 100.0 or str(c.get("state", "")) == "destroyed":
		_add_cmd_button("REPAIR", {"type": "repair", "target": selected})
	_feedback = kit.readout("Result", "")
	_ins_body.add_child(_feedback)


func _add_cmd_button(text: String, cmd: Dictionary, is_eject := false) -> PanelButton:
	var b := kit.button()
	b.set_caption(text)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_eject:
		b.pressed.connect(_on_eject)
	else:
		b.pressed.connect(func() -> void: _send(cmd))
	_ins_body.add_child(b)
	return b


func _on_eject() -> void:
	if tick_now() - _arm_tick <= 30:
		_arm_tick = -1000
		_send({"type": "reactor_eject", "target": selected})
	else:
		_arm_tick = tick_now()
	_update_inspector(_snap())


func _on_alloc_changed(v: float) -> void:
	if _updating or selected == "":
		return
	_send({"type": "set_allocation", "target": selected, "value": v})


func _update_inspector(snap: Dictionary) -> void:
	if _ins.is_empty() or selected == "":
		return
	var c := comp(selected)
	if c.is_empty():
		return
	var u := unit()
	var level := UiStatus.level_of(c)
	(_ins["state"] as Readout).set_pair("State", str(c.get("state", "")), level)
	(_ins["power"] as Readout).set_pair("Power", (fmt(float(c.get("power", 0.0))) + " " + u).strip_edges(), UiStatus.INFO)
	(_ins["temp"] as Readout).set_pair("Temp", fmt(float(c.get("temp", 0.0))), UiStatus.INFO)
	var integ := float(c.get("integrity", 100.0))
	(_ins["integrity"] as BarGauge).set_reading(integ, 100.0, level, fmt(integ) + "%")
	if _ins.has("charge"):
		(_ins["charge"] as Readout).set_pair("Charge", fmt(float(c.get("charge", 0.0))), UiStatus.INFO)
	if _ins.has("countdown"):
		(_ins["countdown"] as Readout).set_pair("Countdown", UiStatus.clock(float(c.get("countdown", 0.0))), UiStatus.CAUTION if float(c.get("countdown", 0.0)) > 0.0 else UiStatus.INFO)
	if _ins.has("eject"):
		var armed := tick_now() - _arm_tick <= 30
		(_ins["eject"] as PanelButton).set_caption("CONFIRM EJECT" if armed else "EJECT")
		(_ins["eject"] as PanelButton).set_level(UiStatus.ALARM if armed else UiStatus.CAUTION)
	if _ins.has("alloc"):
		_updating = true
		(_ins["alloc"] as PanelSlider).set_value_no_signal(float(c.get("allocation", 1.0)))
		_updating = false
		(_ins["alloc_label"] as Readout).set_pair("Allocation", "%d%%" % int(round(float(c.get("allocation", 1.0)) * 100.0)), UiStatus.INFO)
		(_ins["prio"] as Readout).set_pair("Priority", str(int(c.get("priority", 0))), UiStatus.INFO)


func _read_rejections(snap: Dictionary) -> void:
	if _feedback == null:
		return
	for ev: Dictionary in snap.get("events", []):
		if str(ev.get("type", "")) == "rejected":
			_feedback.set_pair("Result", "Rejected: " + str(ev.get("reason", "")), UiStatus.CAUTION)


func _send(cmd: Dictionary) -> void:
	if host == null:
		return
	var result: Dictionary = host.send(cmd)
	if _feedback != null:
		if result.get("accepted", true) == false:
			_feedback.set_pair("Result", "Rejected: " + str(result.get("reason", "")), UiStatus.CAUTION)
		else:
			_feedback.set_pair("Result", "Sent " + str(cmd.get("type", "")), UiStatus.OK)


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
