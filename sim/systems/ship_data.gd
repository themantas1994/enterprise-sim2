class_name ShipData
extends RefCounted
## Ship file helpers. A ship file marks every sourced number as {"value": v, "source": "<ledger id or estimate>",
## "reason"?: "..."} (checked by scripts/check_ship_sources.py). `flatten` strips those wrappers so the generic
## loader (sim/core/ship_loader.gd) and the systems see plain values.


static func flatten(node: Variant) -> Variant:
	if typeof(node) == TYPE_DICTIONARY:
		if node.has("value"):
			return flatten(node["value"])
		var out := {}
		for k: Variant in node:
			out[k] = flatten(node[k])
		return out
	if typeof(node) == TYPE_ARRAY:
		var arr: Array = []
		for v: Variant in node:
			arr.append(flatten(v))
		return arr
	return node


## Parses a JSON ship file. Returns {} when it cannot be read or is not an object.
static func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


## Every value wrapper in the raw (unflattened) data: [{path, source, reason}].
static func wrappers(node: Variant, path: String = "") -> Array:
	var out: Array = []
	if typeof(node) == TYPE_DICTIONARY:
		if node.has("value"):
			out.append({"path": path, "source": node.get("source", ""), "reason": node.get("reason", "")})
		else:
			for k: Variant in node:
				out.append_array(wrappers(node[k], path + "." + str(k)))
	elif typeof(node) == TYPE_ARRAY:
		for i in node.size():
			out.append_array(wrappers(node[i], "%s[%d]" % [path, i]))
	return out
