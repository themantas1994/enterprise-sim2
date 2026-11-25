extends PanelBase
## Panel `shields`. Reads only the ids in its map entry; layout hints below match parts of id names.


func _group_defs() -> Array:
	return [
		["GRID", ["shield_grid"]],
		["GENERATORS", ["shield_gen"]],
		["BACKUP", ["shield_backup"]],
	]

var _grid: BarGauge


func _build_extra(c: VBoxContainer) -> void:
	_grid = kit.gauge("Shield grid")
	c.add_child(_grid)


func _update_extra(_snap_data: Dictionary) -> void:
	var total := 0.0
	var n := 0
	for id in ids:
		if id.contains("shield_gen"):
			total += float(comp(id).get("integrity", 0.0)) * float(comp(id).get("efficiency", 1.0))
			n += 1
	var avg := total / maxf(1.0, float(n))
	_grid.set_reading(avg, 100.0, UiStatus.OK if avg >= 75.0 else (UiStatus.CAUTION if avg >= 25.0 else UiStatus.ALARM), "%d%%" % int(avg))
