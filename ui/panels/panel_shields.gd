extends PanelBase
## Shields panel: frequency and modulation, rotation, facing weights and the red-alert level.
## Reads only the ids of its map entry and the `ship.shields` section.

const FACINGS := ["fore", "aft", "port", "stbd"]
const ROTATE_FREQ := 397      # UI step for ROTATE, a game control, not a source value
const ROTATE_MOD := 613
const LEVEL_MIN := 0.85      # shield_set_level accepts 0.85..1
const FREQ_RANGE := 999       # shield_set accepts 0..999


func _group_defs() -> Array:
	return [
		["GRID", ["shield_grid"]],
		["GENERATORS", ["shield_gen"]],
		["BACKUP", ["shield_backup"]],
	]

var _grid: BarGauge


func _freq_mod_cmd(_v: float) -> Dictionary:
	return {"type": "shield_set", "frequency": int((_ctl["freq"] as PanelSlider).value), "modulation": int((_ctl["mod"] as PanelSlider).value)}


func _weights_cmd(_v: float) -> Dictionary:
	var cmd := {"type": "shield_set_weights"}
	for f: String in FACINGS:
		cmd[f] = (_ctl["w_" + f] as PanelSlider).value
	return cmd


func rotate_now() -> void:
	var f := (_ctl["freq"] as PanelSlider)
	var m := (_ctl["mod"] as PanelSlider)
	_updating = true
	f.set_value_no_signal(float(int(f.value + ROTATE_FREQ) % (FREQ_RANGE + 1)))
	m.set_value_no_signal(float(int(m.value + ROTATE_MOD) % (FREQ_RANGE + 1)))
	_updating = false
	_debounce.erase("freq")
	_debounce.erase("mod")
	send_ctl("rotate", _freq_mod_cmd(0.0))


func _build_controls() -> void:
	add_slider("freq", "Frequency", 0.0, FREQ_RANGE, 1.0, _freq_mod_cmd, 1.0, 0, "", _controls)
	add_slider("mod", "Modulation", 0.0, FREQ_RANGE, 1.0, _freq_mod_cmd, 1.0, 0, "", _controls)
	add_button("rotate", "ROTATE", rotate_now, UiStatus.OK, "FREQ + MOD")
	for f: String in FACINGS:
		add_slider("w_" + f, "Weight " + f, 0.0, 1.0, 0.05, _weights_cmd, 100.0, 0, "%", _controls)
	add_slider("level", "Alert level", LEVEL_MIN, 1.0, 0.01, func(v: float) -> Dictionary: return {"type": "shield_set_level", "value": v}, 100.0, 0, "%", _controls)


func _build_extra(c: VBoxContainer) -> void:
	_grid = kit.gauge("Shield strength")
	c.add_child(_grid)


func _update_controls(_snap_data: Dictionary) -> void:
	var s := ship("shields")
	sync_slider("freq", float(s.get("frequency", 0)))
	sync_slider("mod", float(s.get("modulation", 0)))
	var w: Dictionary = s.get("weights", {})
	for f: String in FACINGS:
		sync_slider("w_" + f, float(w.get(f, 0.25)))
	sync_slider("level", float(s.get("alert_level", 0.85)))


func _update_extra(_snap_data: Dictionary) -> void:
	var s := ship("shields")
	var strength := float(s.get("strength", 0.0))
	var borg: Dictionary = s.get("borg", {})
	var text := "%d%%" % int(round(strength * 100.0))
	if borg.get("active", false):
		text += " MATCH %d%%" % int(round(float(borg.get("match", 0.0)) * 100.0))
	_grid.set_reading(strength, 1.0, UiStatus.OK if strength >= 0.5 else (UiStatus.CAUTION if strength >= 0.15 else UiStatus.ALARM), text)
