extends PanelBase
## Panel `fuel`. Reads only the ids in its map entry; layout hints below match parts of id names.


func _group_defs() -> Array:
	return [
		["ANTIMATTER PODS", ["antimatter_pod"]],
		["TANKS", ["deuterium"]],
		["GENERATOR", ["antimatter_generator"]],
	]

var _pods: BarGauge


func _build_extra(c: VBoxContainer) -> void:
	_pods = kit.gauge("Pods nominal")
	c.add_child(_pods)


func _update_extra(snap: Dictionary) -> void:
	var total := 0
	var good := 0
	for id in ids:
		if id.contains("antimatter_pod"):
			total += 1
			if UiStatus.is_nominal(comp(id)):
				good += 1
	_pods.set_reading(float(good), maxf(1.0, float(total)), UiStatus.OK if good == total else UiStatus.CAUTION, "%d/%d" % [good, total])
