extends PanelBase
## Panel `warp_core`. Reads only the ids in its map entry; layout hints below match parts of id names.


func _group_defs() -> Array:
	return [
		["CORE", ["warp_core"]],
		["MATTER INJECTORS", ["injector_matter"]],
		["ANTIMATTER INJECTORS", ["injector_antimatter"]],
		["CONSTRICTORS", ["constrictor"]],
		["DILITHIUM FRAME", ["dilithium"]],
		["NACELLES", ["nacelle"]],
		["COOLANT", ["coolant"]],
	]

var _core: Readout


func _build_extra(c: VBoxContainer) -> void:
	_core = kit.readout("Core")
	c.add_child(_core)


func _update_extra(_snap_data: Dictionary) -> void:
	for id in ids:
		var c := comp(id)
		if c.has("countdown"):
			var cd := float(c["countdown"])
			_core.set_pair("Core " + str(c.get("state", "")), UiStatus.clock(cd) if cd > 0.0 else fmt(float(c.get("temp", 0.0))), UiStatus.level_of(c))
			return
