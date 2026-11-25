extends PanelBase
## Impulse panel: impulse setting, reactors and fuel. Reads the ids of its map entry and `ship.propulsion`.

var _thrust: BarGauge


func _group_defs() -> Array:
	return [
		["REACTORS", ["impulse_main", "impulse_saucer"]],
		["AUXILIARY", ["aux_fusion"]],
		["DRIVE", ["impulse_drive"]],
		["FUEL", ["deuterium"]],
	]


func _build_controls() -> void:
	add_slider("impulse", "Impulse", 0.0, 1.0, 0.05, func(v: float) -> Dictionary: return {"type": "set_impulse", "value": v}, 100.0, 0, "%", _controls)


func _build_extra(c: VBoxContainer) -> void:
	_thrust = kit.gauge("Impulse")
	c.add_child(_thrust)


func _update_controls(_snap_data: Dictionary) -> void:
	sync_slider("impulse", float(ship("propulsion").get("impulse_target", 0.0)))


func _update_extra(_snap_data: Dictionary) -> void:
	var p := ship("propulsion")
	var v := float(p.get("impulse", 0.0))
	_thrust.set_reading(v, 1.0, UiStatus.OK, "%d%%" % int(round(v * 100.0)))
