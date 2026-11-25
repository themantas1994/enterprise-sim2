class_name ScenarioRegistry
extends RefCounted
## Scenario ids and factory (ADR 0002).


static func ids() -> Array:
	return ["core_breach", "borg_drain", "coolant_leak"]


## A fresh scenario object, or null for an unknown id.
static func create(id: String) -> ScenarioBase:
	match id:
		"core_breach":
			return ScenarioCoreBreach.new()
		"borg_drain":
			return ScenarioBorgDrain.new()
		"coolant_leak":
			return ScenarioCoolantLeak.new()
	return null
