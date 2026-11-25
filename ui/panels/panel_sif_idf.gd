extends PanelBase
## Structural integrity and inertial damping panel. Reads the ids of its map entry and `ship.sif_idf`.

var _sif: BarGauge
var _idf: BarGauge
var _hulls: Readout


func _group_defs() -> Array:
	return [
		["SIF GRID", ["sif_grid"]],
		["SIF GENERATORS", ["sif_gen"]],
		["SIF BACKUP", ["sif_backup"]],
		["IDF GRID", ["idf_grid"]],
		["IDF GENERATORS", ["idf_gen"]],
		["IDF BACKUP", ["idf_backup"]],
	]


func _build_extra(c: VBoxContainer) -> void:
	_sif = kit.gauge("SIF strength")
	_idf = kit.gauge("IDF strength")
	c.add_child(_sif)
	c.add_child(_idf)
	_hulls = kit.readout("Degraded hulls")
	c.add_child(_hulls)


func _update_extra(_snap_data: Dictionary) -> void:
	var s := ship("sif_idf")
	for pair in [[_sif, "sif_strength"], [_idf, "idf_strength"]]:
		var v := float(s.get(pair[1], 0.0))
		(pair[0] as BarGauge).set_reading(v, 1.0, UiStatus.OK if v >= 0.75 else (UiStatus.CAUTION if v >= 0.25 else UiStatus.ALARM), "%d%%" % int(round(v * 100.0)))

	var d: Dictionary = s.get("degraded_hulls", {})
	var parts: Array = []
	for system: String in ["sif", "idf"]:
		for hull: Variant in d.get(system, []):
			parts.append("%s %s" % [system, str(hull)])
	_hulls.set_pair("Degraded hulls", ", ".join(PackedStringArray(parts)) if not parts.is_empty() else "none", UiStatus.CAUTION if not parts.is_empty() else UiStatus.OK)
