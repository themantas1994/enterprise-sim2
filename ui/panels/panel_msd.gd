extends PanelBase
## Master Systems Display: one tile per group (numbered siblings collapse into one summary tile), alert
## buttons and the situation monitor, which lists every off-nominal id of the whole map.

var _sit: VBoxContainer
var _ok: Label


func _collapse_numbered() -> bool:
	return true


func _build_controls() -> void:
	for spec in [["GREEN", "green", UiStatus.OK], ["YELLOW", "yellow", UiStatus.CAUTION], ["RED", "red", UiStatus.ALARM]]:
		add_cmd_button("alert_" + spec[1], spec[0] + " ALERT", {"type": "set_alert", "value": spec[1]}, spec[2])


func _update_controls(snap: Dictionary) -> void:
	var current := str(snap.get("ship", {}).get("alert", snap.get("alert", "")))
	for spec in [["GREEN", "green", UiStatus.OK], ["YELLOW", "yellow", UiStatus.CAUTION], ["RED", "red", UiStatus.ALARM]]:
		set_button("alert_" + spec[1], spec[0] + " ALERT", "ACTIVE" if current == spec[1] else "", spec[2])


func _build_extra(c: VBoxContainer) -> void:
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
