extends PanelBase
## Damage control: the teams of the map entry as tiles, and the repair queue, which lists every damaged id of
## the whole map. Pressing a queue row sends a repair command for that id.

var _queue: VBoxContainer
var _empty: Label


func _group_defs() -> Array:
	return [["TEAMS", ["dc_team"]]]


func _build_extra(c: VBoxContainer) -> void:
	c.add_child(kit.caption("Repair queue"))
	_empty = kit.caption("Nothing damaged")
	c.add_child(_empty)
	_queue = VBoxContainer.new()
	c.add_child(_queue)


func _update_extra(_snap_data: Dictionary) -> void:
	var rows: Array = []
	for id in wide_ids:
		var c := comp(id)
		var integ := float(c.get("integrity", 100.0))
		if integ < 100.0 or str(c.get("state", "")) in ["destroyed", "cut"]:
			rows.append({"id": id, "caption": "REPAIR " + UiStatus.pretty(id), "sub": "%d%%" % int(integ), "level": UiStatus.level_of(c)})
	_empty.visible = rows.is_empty()
	sync_rows(_queue, rows, func(id: String) -> void: _send({"type": "repair", "target": id}))
