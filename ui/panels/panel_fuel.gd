extends PanelBase
## Fuel panel: antimatter generator switch, pods and tanks. Reads the ids of its map entry and `ship.fuel`.

var _pods: BarGauge


func _group_defs() -> Array:
	return [
		["ANTIMATTER PODS", ["antimatter_pod"]],
		["TANKS", ["deuterium"]],
		["GENERATOR", ["antimatter_generator"]],
	]


func _build_controls() -> void:
	add_button("generator", "GENERATOR", func() -> void: send_ctl("generator", {"type": "antimatter_generator_set", "value": not ship("fuel").get("generator_on", false)}))


func _build_extra(c: VBoxContainer) -> void:
	_pods = kit.gauge("Pods nominal")
	c.add_child(_pods)


func _update_controls(_snap_data: Dictionary) -> void:
	var on: bool = ship("fuel").get("generator_on", false)
	set_button("generator", "GENERATOR", "ON" if on else "OFF", UiStatus.OK if on else UiStatus.OFF)


func _update_extra(_snap_data: Dictionary) -> void:
	var total := 0
	var good := 0
	for id in ids:
		if id.contains("antimatter_pod"):
			total += 1
			if UiStatus.is_nominal(comp(id)):
				good += 1
	_pods.set_reading(float(good), maxf(1.0, float(total)), UiStatus.OK if good == total else UiStatus.CAUTION, "%d/%d" % [good, total])
