extends PanelBase
## Panel `impulse`. Reads only the ids in its map entry; layout hints below match parts of id names.


func _group_defs() -> Array:
	return [
		["REACTORS", ["impulse_main", "impulse_saucer"]],
		["AUXILIARY", ["aux_fusion"]],
		["DRIVE", ["impulse_drive"]],
		["FUEL", ["deuterium"]],
	]

var _thrust: BarGauge


func _build_extra(c: VBoxContainer) -> void:
	_thrust = kit.gauge("Thrust")
	c.add_child(_thrust)


func _update_extra(_snap_data: Dictionary) -> void:
	for id in ids:
		var c := comp(id)
		if c.get("kind", "") == "consumer":
			_thrust.set_reading(float(c.get("allocation", 0.0)) * float(c.get("efficiency", 1.0)), 1.0, UiStatus.level_of(c), "%d%%" % int(round(float(c.get("allocation", 0.0)) * float(c.get("efficiency", 1.0)) * 100.0)))
			return
