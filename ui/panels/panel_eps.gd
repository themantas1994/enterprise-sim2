extends PanelBase
## Panel `eps`. Reads only the ids in its map entry; layout hints below match parts of id names.


var _supply: Readout
var _demand: Readout


func _build_extra(c: VBoxContainer) -> void:
	_supply = kit.readout("Supply")
	_demand = kit.readout("Demand served")
	c.add_child(_supply)
	c.add_child(_demand)


func _update_extra(_snap_data: Dictionary) -> void:
	var supply := 0.0
	var used := 0.0
	for id in ids:
		var c := comp(id)
		if c.get("kind", "") == "producer":
			supply += float(c.get("power", 0.0))
		elif c.get("kind", "") == "consumer":
			used += float(c.get("power", 0.0))
	_supply.set_pair("Supply", (fmt(supply) + " " + unit()).strip_edges(), UiStatus.INFO)
	_demand.set_pair("Demand served", (fmt(used) + " " + unit()).strip_edges(), UiStatus.OK if used <= supply + 0.001 else UiStatus.CAUTION)
