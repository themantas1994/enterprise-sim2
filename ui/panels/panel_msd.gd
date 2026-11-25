extends PanelBase
## Master Systems Display: one tile per group (numbered siblings collapse into one summary tile), alert
## buttons and the situation monitor, which lists every off-nominal id of the whole map.

var _sit: VBoxContainer
var _ok: Label


func _collapse_numbered() -> bool:
	return true


func _build_extra(c: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	c.add_child(row)
	for spec in [["GREEN", "green"], ["YELLOW", "yellow"], ["RED", "red"]]:
		var b := kit.button()
		b.set_caption(spec[0] + " ALERT")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_level(UiStatus.ALARM if spec[1] == "red" else (UiStatus.CAUTION if spec[1] == "yellow" else UiStatus.OK))
		var value: String = spec[1]
		b.pressed.connect(func() -> void: _send({"type": "set_alert", "value": value}))
		row.add_child(b)
	c.add_child(kit.caption("Situation monitor"))
	_ok = kit.caption("All systems nominal")
	c.add_child(_ok)
	_sit = VBoxContainer.new()
	c.add_child(_sit)


func _update_extra(snap: Dictionary) -> void:
	var rows: Array = []
	for id: String in off_nominal(snap):
		rows.append({"id": id, "caption": UiStatus.pretty(id), "sub": str(comp(id).get("state", "")), "level": level_of(id)})
	_ok.visible = rows.is_empty()
	sync_rows(_sit, rows, select)
