extends PanelBase
## Panel `eps`. Reads only the ids in its map entry; layout hints below match parts of id names.


var _loop := ""
var _supply: Readout
var _demand: Readout


func _build_controls() -> void:
	_loop = id_with("coolant")
	if _loop == "":
		return
	var loop := _loop
	add_button("isolate", "ISOLATE LOOP", func() -> void: send_ctl("isolate", {"type": "coolant_isolate", "target": loop, "value": not ship("coolant").get(loop, {}).get("isolated", false)}))
	add_button("refill", "REFILL LOOP", func() -> void: send_ctl("refill", {"type": "coolant_refill", "target": loop, "value": not ship("coolant").get(loop, {}).get("refilling", false)}))


func _update_controls(_snap_data: Dictionary) -> void:
	if _loop == "":
		return
	var cl: Dictionary = ship("coolant").get(_loop, {})
	set_button("isolate", "ISOLATE LOOP", "ON" if cl.get("isolated", false) else "OFF", UiStatus.CAUTION if cl.get("isolated", false) else UiStatus.OK)
	set_button("refill", "REFILL LOOP", "ON" if cl.get("refilling", false) else "OFF", UiStatus.INFO if cl.get("refilling", false) else UiStatus.OK)


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
