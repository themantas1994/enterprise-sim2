extends RefCounted
## PLACEHOLDER ids and values for the UI tests; not ship data. A fixture panel map in the shape of the ship
## file's `panels` object, and a matching component table with a mix of kinds and states.

const MAP := {
	"msd": {"title": "Master Systems Display", "components": ["warp_core", "coolant_core", "antimatter_pod_01", "antimatter_pod_02", "antimatter_pod_03", "antimatter_pod_04", "eps_trunk_a", "shield_grid", "impulse_main"]},
	"warp_core": {"title": "Warp Core", "components": ["warp_core", "warp_injector_matter_1", "warp_injector_matter_2", "warp_injector_antimatter_1", "warp_constrictor_upper", "warp_dilithium_frame", "warp_nacelle_port", "coolant_core"]},
	"fuel": {"title": "Fuel", "components": ["antimatter_pod_01", "antimatter_pod_02", "antimatter_pod_03", "antimatter_pod_04", "deuterium_tank_main", "antimatter_generator"]},
	"eps": {"title": "Power Distribution", "components": ["warp_core", "impulse_main", "eps_trunk_a", "eps_trunk_b", "eps_cross_link", "shield_grid", "life_support"]},
	"shields": {"title": "Shields", "components": ["shield_grid", "shield_gen_p1", "shield_gen_p2", "shield_backup_primary"]},
	"impulse": {"title": "Impulse", "components": ["impulse_main", "aux_fusion_1", "impulse_drive", "deuterium_tank_main"]},
	"sif_idf": {"title": "SIF and IDF", "components": ["sif_grid", "sif_gen_p1", "idf_grid", "idf_gen_p1"]},
	"damage_control": {"title": "Damage Control", "components": ["dc_team_1", "dc_team_2"]},
}

const SIZES := {"desktop": [Vector2i(1280, 720), 1.0, 1.0], "phone": [Vector2i(1440, 720), 2.5, 1.5]}


static func comp(kind: String, state: String = "ok", extra: Dictionary = {}) -> Dictionary:
	var c := {"kind": kind, "state": state, "power": 120.0, "temp": 35.0, "integrity": 100.0, "efficiency": 1.0, "load": 0.6}
	c.merge(extra, true)
	return c


static func components() -> Dictionary:
	var c := {}
	c["warp_core"] = comp("producer", "online", {"countdown": 0, "load": 0.8})
	c["impulse_main"] = comp("producer", "ok")
	c["aux_fusion_1"] = comp("producer", "ok")
	for id in ["coolant_core", "deuterium_tank_main", "antimatter_generator"]:
		c[id] = comp("store", "ok", {"charge": 500.0})
	for i in range(1, 5):
		c["antimatter_pod_%02d" % i] = comp("store", "ok", {"charge": 90.0 + i})
	c["antimatter_pod_03"]["integrity"] = 60.0
	for id in ["warp_injector_matter_1", "warp_injector_matter_2", "warp_injector_antimatter_1", "warp_constrictor_upper", "warp_dilithium_frame", "warp_nacelle_port"]:
		c[id] = comp("consumer", "ok", {"demand": 50.0, "allocation": 1.0, "priority": 10})
	c["eps_trunk_a"] = comp("conduit", "ok", {"cut": false})
	c["eps_trunk_b"] = comp("conduit", "ok", {"cut": false, "integrity": 40.0})
	c["eps_cross_link"] = comp("conduit", "cut", {"cut": true})
	for id in ["shield_grid", "life_support", "impulse_drive", "sif_grid", "idf_grid"]:
		c[id] = comp("consumer", "ok", {"demand": 80.0, "allocation": 0.75, "priority": 5})
	c["shield_gen_p1"] = comp("producer", "ok")
	c["shield_gen_p2"] = comp("producer", "partial", {"integrity": 70.0})
	c["shield_backup_primary"] = comp("store", "ok", {"charge": 40.0})
	c["sif_gen_p1"] = comp("producer", "ok")
	c["idf_gen_p1"] = comp("producer", "unpowered", {"integrity": 20.0})
	c["dc_team_1"] = comp("consumer", "ok", {"demand": 1.0, "allocation": 1.0, "priority": 50})
	c["dc_team_2"] = comp("consumer", "shed", {"demand": 1.0, "allocation": 1.0, "priority": 50})
	# Not in any panel map: must never show up anywhere.
	c["decoy_zz"] = comp("consumer", "destroyed", {"integrity": 0.0, "demand": 1.0, "allocation": 1.0, "priority": 1})
	return c
